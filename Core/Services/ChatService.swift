import Foundation

// MARK: - Message model

struct ChatMessage: Identifiable, Codable, Equatable {
    enum Sender: String, Codable {
        case user
        case assistant
    }

    let id: UUID
    let text: String
    let sender: Sender
    let date: Date

    init(id: UUID = UUID(), text: String, sender: Sender, date: Date = Date()) {
        self.id = id
        self.text = text
        self.sender = sender
        self.date = date
    }
}

// MARK: - Chat Service

final class ChatService {
    static let shared = ChatService()
    private init() {}

    private var storageKey: String {
        let userId = UserDefaults.standard.string(forKey: "userToken") ?? "guest"
        return "chat_history_\(userId)"
    }

    private var activeChatKey: String {
        let userId = UserDefaults.standard.value(forKey: "userId").map { "\($0)" } ?? "guest"
        return "active_chat_id_\(userId)"
    }

    // MARK: - Local Chat History

    func loadMessages() -> [ChatMessage] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([ChatMessage].self, from: data)) ?? []
    }

    func saveMessages(_ messages: [ChatMessage]) {
        let data = try? JSONEncoder().encode(messages)
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func clearMessages() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: activeChatKey)
    }

    // MARK: - Main Send

    func sendMessageToAI(userText: String, completion: @escaping (ChatMessage) -> Void) {
        guard let token = KeychainHelper.read("auth_token"), !token.isEmpty else {
            completion(ChatMessage(
                text: authTokenMissingMessage(),
                sender: .assistant
            ))
            return
        }

        if token.hasPrefix("offline-") {
            completion(ChatMessage(
                text: offlineReply(),
                sender: .assistant
            ))
            return
        }

        let enrichedText = buildEnrichedPrompt(userText: userText)

        ensureActiveChat(firstMessage: userText, token: token) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let chatId):
                self.sendMessage(chatId: chatId, text: enrichedText, token: token, completion: completion)

            case .failure:
                completion(ChatMessage(
                    text: self.localizedNetworkError(),
                    sender: .assistant
                ))
            }
        }
    }

    // MARK: - API

    private func ensureActiveChat(
        firstMessage: String,
        token: String,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        if let existing = UserDefaults.standard.value(forKey: activeChatKey) as? Int {
            completion(.success(existing))
            return
        }

        let title = String(firstMessage.prefix(50))
        var request = URLRequest(url: APIConfig.url("chats"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["title": title])

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let raw = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""

            print("📡 CREATE CHAT status:", status)
            print("📦 CREATE CHAT raw:", raw)

            guard (200...299).contains(status) else {
                DispatchQueue.main.async {
                    completion(.failure(Self.makeError(code: status, message: raw.isEmpty ? "Chat create failed" : raw)))
                }
                return
            }

            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = Self.extractId(from: json) else {
                DispatchQueue.main.async {
                    completion(.failure(Self.makeError(code: -2, message: "Could not parse chat id")))
                }
                return
            }

            UserDefaults.standard.set(id, forKey: self.activeChatKey)

            DispatchQueue.main.async {
                completion(.success(id))
            }
        }.resume()
    }

    private func sendMessage(
        chatId: Int,
        text: String,
        token: String,
        completion: @escaping (ChatMessage) -> Void
    ) {
        var request = URLRequest(url: APIConfig.url("chats/\(chatId)/messages"))
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "message": text,
            "locale": currentLocale()
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("📤 SEND CHAT:", request.url?.absoluteString ?? "")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                DispatchQueue.main.async {
                    completion(ChatMessage(text: self.localizedNetworkError(), sender: .assistant))
                }
                return
            }

            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let raw = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""

            print("📡 SEND CHAT status:", status)
            print("📦 SEND CHAT raw:", raw)

            if status == 404 {
                UserDefaults.standard.removeObject(forKey: self.activeChatKey)
            }

            guard (200...299).contains(status) else {
                DispatchQueue.main.async {
                    completion(ChatMessage(text: self.serverUnavailableMessage(raw: raw), sender: .assistant))
                }
                return
            }

            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async {
                    completion(ChatMessage(text: self.parseErrorMessage(), sender: .assistant))
                }
                return
            }

            let reply = Self.extractReply(from: json) ?? self.missingReplyMessage()

            DispatchQueue.main.async {
                completion(ChatMessage(text: reply, sender: .assistant))
            }
        }.resume()
    }

    private static func extractId(from json: [String: Any]) -> Int? {
        if let id = json["id"] as? Int { return id }

        if let data = json["data"] as? [String: Any],
           let id = data["id"] as? Int {
            return id
        }

        if let chat = json["chat"] as? [String: Any],
           let id = chat["id"] as? Int {
            return id
        }

        return nil
    }

    private static func extractReply(from json: [String: Any]) -> String? {
        if let reply = json["reply"] as? String { return reply }
        if let message = json["message"] as? String { return message }
        if let answer = json["answer"] as? String { return answer }

        if let assistant = json["assistant_message"] as? [String: Any] {
            return assistant["message"] as? String ??
                   assistant["content"] as? String ??
                   assistant["text"] as? String
        }

        if let assistant = json["assistantMessage"] as? [String: Any] {
            return assistant["message"] as? String ??
                   assistant["content"] as? String ??
                   assistant["text"] as? String
        }

        if let data = json["data"] as? [String: Any] {
            return extractReply(from: data)
        }

        return nil
    }

    private static func makeError(code: Int, message: String) -> NSError {
        NSError(
            domain: "ChatService",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    // MARK: - Hidden Context

    private func buildEnrichedPrompt(userText: String) -> String {
        let language = preferredResponseLanguage()
        let health = buildHealthContext()
        let journal = buildJournalContext()
        let mood = buildMoodContext()
        let medicalProfile = buildMedicalProfileContext()
        let aiAnamnesis = buildAIAnamnesisContext()

        return """
        USER_VISIBLE_MESSAGE:
        \(userText)

        HIDDEN_APP_CONTEXT:
        This context is sent silently by the Bagyt iOS app. The user did not type it manually.
        Do not mention that hidden context was attached.
        Do not expose raw hidden data unless it is medically useful.
        Use it only to personalize the answer.

        APP_LANGUAGE_RULE:
        \(language.instruction)
        The language rule is based on the selected app language in the user's profile, not on the language of the last message.
        Even if the user writes in another language, answer in the selected app language unless the user explicitly asks for translation or language learning.

        MEDICAL_SAFETY_RULES:
        You are a health assistant, not a doctor.
        Do not give a final diagnosis.
        Give practical next steps and explain when to seek medical care.
        If the complaint may include red flags, clearly recommend urgent medical help.
        For headache red flags include sudden worst headache, weakness/numbness, speech problems, confusion, fever with stiff neck, head injury, vision loss, pregnancy/postpartum, very high blood pressure, or headache with chest pain.

        HEALTH_DATA:
        \(health)

        MEDICAL_PROFILE_MEMORY:
        \(medicalProfile)

        JOURNAL_DATA:
        \(journal)

        MOOD_DATA:
        \(mood)

        AI_ANAMNESIS_MEMORY:
        \(aiAnamnesis)
        END_HIDDEN_APP_CONTEXT
        """
    }

    private func buildHealthContext() -> String {
        let health = HealthKitManager.shared

        let stepsGoal = UserDefaults.standard.integer(forKey: "stepsGoal")
        let sleepGoal = UserDefaults.standard.double(forKey: "sleepGoal")
        let waterGoal = UserDefaults.standard.double(forKey: "waterGoal")
        let caloriesGoal = UserDefaults.standard.integer(forKey: "caloriesGoal")

        return """
        Current HealthKit snapshot:
        - Steps today: \(health.steps)
        - Latest heart rate: \(health.heartRate) bpm
        - Sleep: \(String(format: "%.1f", health.sleep)) hours
        - HealthKit authorized: \(health.isAuthorized)

        User goals:
        - Steps goal: \(stepsGoal > 0 ? stepsGoal : 8000)
        - Sleep goal: \(sleepGoal > 0 ? String(format: "%.1f", sleepGoal) : "8.0") hours
        - Water goal: \(waterGoal > 0 ? String(format: "%.1f", waterGoal) : "2.0") L
        - Calories goal: \(caloriesGoal > 0 ? caloriesGoal : 2000)
        """
    }

    private func buildJournalContext() -> String {
        let records = loadJournalEntries()
            .sorted { $0.date > $1.date }
            .prefix(12)

        guard !records.isEmpty else {
            return "No journal entries saved."
        }

        return records.map { entry in
            let date = Self.shortDateFormatter.string(from: entry.date)
            let severity = entry.severity.map { ", severity: \($0)/10" } ?? ""
            let mood = entry.mood.map { ", mood: \($0)/5" } ?? ""

            return """
            - \(date): [\(entry.category)] \(entry.title)\(severity)\(mood)
              \(entry.body)
            """
        }
        .joined(separator: "\n")
    }

    private func buildMoodContext() -> String {
        let records = loadMoodRecords()
            .sorted { $0.date > $1.date }
            .prefix(10)

        guard !records.isEmpty else {
            return "No mood records saved."
        }

        return records.map { record in
            let date = Self.shortDateFormatter.string(from: record.date)
            let stress = record.stress.map { ", stress: \($0)/5" } ?? ""
            let sleep = record.sleepQuality.map { ", sleep quality: \($0)/5" } ?? ""
            let tags = record.tags.isEmpty ? "" : ", factors: \(record.tags.joined(separator: ", "))"

            return """
            - \(date): mood \(record.mood)/5, energy \(record.energy)/5\(stress)\(sleep)\(tags)
              \(record.note)
            """
        }
        .joined(separator: "\n")
    }

    private func buildMedicalProfileContext() -> String {
        let records = loadMedicalProfileItems()
        guard !records.isEmpty else {
            return "No saved medical profile items."
        }

        let grouped = Dictionary(grouping: records) { $0.category }

        func block(_ title: String, category: String) -> String {
            let items = grouped[category] ?? []
            guard !items.isEmpty else { return "\(title): none saved" }
            let lines = items.map { item in
                let detail = item.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                return "- \(item.title)\(detail.isEmpty ? "" : ": \(detail)") [importance: \(item.importance)]"
            }
            return "\(title):\n\(lines.joined(separator: "\n"))"
        }

        return [
            block("Allergies", category: "allergy"),
            block("Medications", category: "medication"),
            block("Conditions", category: "condition"),
            block("Important care notes", category: "careNote")
        ].joined(separator: "\n\n")
    }

    private func buildAIAnamnesisContext() -> String {
        let records = BagytMemoryStore.shared.loadFindings()
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(6)

        guard !records.isEmpty else {
            return "No saved AI anamnesis notes."
        }

        return records.map { finding in
            let hypotheses = finding.hypotheses.isEmpty ? "none extracted" : finding.hypotheses.joined(separator: "; ")
            let redFlags = finding.redFlags.isEmpty ? "none extracted" : finding.redFlags.joined(separator: "; ")
            return """
            - \(Self.shortDateFormatter.string(from: finding.createdAt)): \(finding.title)
              Summary: \(finding.summary)
              Possible explanations, not diagnoses: \(hypotheses)
              Red flags mentioned: \(redFlags)
            """
        }
        .joined(separator: "\n")
    }

    // MARK: - Local Storage Readers

    private func loadJournalEntries() -> [StoredJournalEntry] {
        let key = scopedKey(base: "bagyt_journal_entries")
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([StoredJournalEntry].self, from: data) {
            return decoded
        }

        if let data = defaults.data(forKey: "bagyt_journal_entries"),
           let decoded = try? JSONDecoder().decode([StoredJournalEntry].self, from: data) {
            return decoded
        }

        return []
    }

    private func loadMoodRecords() -> [StoredMoodRecord] {
        let key = scopedKey(base: "bagyt_mood_records")
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([StoredMoodRecord].self, from: data) {
            return decoded
        }

        if let data = defaults.data(forKey: "bagyt_mood_records"),
           let decoded = try? JSONDecoder().decode([StoredMoodRecord].self, from: data) {
            return decoded
        }

        return []
    }

    private func loadMedicalProfileItems() -> [StoredMedicalProfileItem] {
        let key = scopedKey(base: "bagyt_medical_profile_items")
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([StoredMedicalProfileItem].self, from: data) {
            return decoded
        }

        return []
    }

    private func scopedKey(base: String) -> String {
        let raw = UserDefaults.standard.string(forKey: "userToken") ?? "guest"
        let safe = Data(raw.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        return "\(base)_\(safe)"
    }

    // MARK: - Language

    private enum DetectedLanguage {
        case kk
        case ru
        case en

        var locale: String {
            switch self {
            case .kk:
                return "kk"
            case .ru:
                return "ru"
            case .en:
                return "en"
            }
        }

        var instruction: String {
            switch self {
            case .kk:
                return "The app language is Kazakh. Reply strictly in Kazakh."
            case .ru:
                return "The app language is Russian. Reply strictly in Russian."
            case .en:
                return "The app language is English. Reply strictly in English."
            }
        }
    }

    private func preferredResponseLanguage() -> DetectedLanguage {
        let savedLanguage = UserDefaults.standard.string(forKey: "language") ?? AppLanguage.kk.rawValue

        switch AppLanguage(rawValue: savedLanguage) ?? .kk {
        case .kk:
            return .kk
        case .ru:
            return .ru
        case .en:
            return .en
        }
    }

    private func currentLocale() -> String {
        preferredResponseLanguage().locale
    }

    private func authTokenMissingMessage() -> String {
        switch preferredResponseLanguage() {
        case .kk:
            return "Авторизация токені табылмады. Аккаунтқа қайта кіріңіз."
        case .ru:
            return "Не удалось найти токен авторизации. Пожалуйста, войдите в аккаунт заново."
        case .en:
            return "Authorization token was not found. Please sign in again."
        }
    }

    private func offlineReply() -> String {
        switch preferredResponseLanguage() {
        case .kk:
            return "Сипаттауыңызды түсіндім. Симптом қашан басталды, ауырсыну қаншалықты күшті және қосымша белгілер бар ма?"
        case .ru:
            return "Понял. Опишите, когда началась боль, насколько она сильная и есть ли дополнительные симптомы."
        case .en:
            return "I understand. Please describe when the pain started, how strong it is, and whether you have any additional symptoms."
        }
    }

    private func localizedNetworkError() -> String {
        switch preferredResponseLanguage() {
        case .kk:
            return "Серверге қосылу мүмкін болмады. Кейінірек қайталап көріңіз."
        case .ru:
            return "Не удалось подключиться к серверу. Попробуйте позже."
        case .en:
            return "Could not connect to the server. Please try again later."
        }
    }

    private func serverUnavailableMessage(raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return trimmed }

        switch preferredResponseLanguage() {
        case .kk:
            return "Сервер уақытша қолжетімсіз."
        case .ru:
            return "Сервер временно недоступен."
        case .en:
            return "The server is temporarily unavailable."
        }
    }

    private func parseErrorMessage() -> String {
        switch preferredResponseLanguage() {
        case .kk:
            return "Сервер жауабын оқу мүмкін болмады."
        case .ru:
            return "Не удалось разобрать ответ сервера."
        case .en:
            return "Could not parse the server response."
        }
    }

    private func missingReplyMessage() -> String {
        switch preferredResponseLanguage() {
        case .kk:
            return "AI жауабы табылмады."
        case .ru:
            return "Ответ от AI не найден."
        case .en:
            return "AI response was not found."
        }
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = BagytL10n.currentLocale
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter
    }()
}

// MARK: - Storage DTOs

private struct StoredJournalEntry: Codable {
    let title: String
    let body: String
    let category: String
    let date: Date
    let mood: Int?
    let severity: Int?

    enum CodingKeys: String, CodingKey {
        case title, body, category, date, mood, severity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "Запись"
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        mood = try c.decodeIfPresent(Int.self, forKey: .mood)
        severity = try c.decodeIfPresent(Int.self, forKey: .severity)
    }
}

private struct StoredMoodRecord: Codable {
    let mood: Int
    let note: String
    let date: Date
    let energy: Int
    let stress: Int?
    let sleepQuality: Int?
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case mood, note, date, energy, stress, sleepQuality, tags
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mood = try c.decodeIfPresent(Int.self, forKey: .mood) ?? 3
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        energy = try c.decodeIfPresent(Int.self, forKey: .energy) ?? 3
        stress = try c.decodeIfPresent(Int.self, forKey: .stress)
        sleepQuality = try c.decodeIfPresent(Int.self, forKey: .sleepQuality)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}

private struct StoredMedicalProfileItem: Codable {
    let category: String
    let title: String
    let detail: String
    let importance: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case category, title, detail, importance, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        detail = try c.decodeIfPresent(String.self, forKey: .detail) ?? ""
        importance = try c.decodeIfPresent(String.self, forKey: .importance) ?? "medium"
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

// MARK: - Bagyt AI Memory

struct BagytAIFinding: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var summary: String
    var userText: String
    var assistantText: String
    var hypotheses: [String]
    var redFlags: [String]
    var nextSteps: [String]
    var createdAt: Date = Date()
}

final class BagytMemoryStore {
    static let shared = BagytMemoryStore()

    private let baseKey = "bagyt_ai_anamnesis_findings"
    private let maxItems = 24

    private init() {}

    func loadFindings(token: String? = UserDefaults.standard.string(forKey: "userToken")) -> [BagytAIFinding] {
        guard let data = UserDefaults.standard.data(forKey: scopedKey(base: baseKey, token: token)),
              let decoded = try? JSONDecoder().decode([BagytAIFinding].self, from: data) else {
            return []
        }

        return decoded.sorted { $0.createdAt > $1.createdAt }
    }

    func deleteFinding(id: UUID, token: String? = UserDefaults.standard.string(forKey: "userToken")) {
        var items = loadFindings(token: token)
        items.removeAll { $0.id == id }
        persist(items, token: token)
    }

    func captureAIResponse(
        userText: String,
        assistantText: String,
        token: String? = UserDefaults.standard.string(forKey: "userToken")
    ) {
        let cleanUser = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAssistant = assistantText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard shouldCapture(userText: cleanUser, assistantText: cleanAssistant) else { return }

        let finding = BagytAIFinding(
            title: makeTitle(from: cleanUser),
            summary: makeSummary(from: cleanAssistant),
            userText: cleanUser,
            assistantText: cleanAssistant,
            hypotheses: extractLines(
                from: cleanAssistant,
                markers: [
                    "может", "возможно", "вероят", "похоже", "связано", "причин", "дифференц",
                    "may", "might", "could", "possible", "likely", "related"
                ],
                limit: 4
            ),
            redFlags: extractLines(
                from: cleanAssistant,
                markers: [
                    "сроч", "немедленно", "скор", "неотлож", "опас", "красн", "обратитесь",
                    "urgent", "emergency", "red flag", "seek medical"
                ],
                limit: 3
            ),
            nextSteps: extractLines(
                from: cleanAssistant,
                markers: [
                    "рекоменд", "след", "измер", "запиш", "наблюд", "обрат", "проверь",
                    "recommend", "measure", "monitor", "consult", "track"
                ],
                limit: 4
            )
        )

        var items = loadFindings(token: token)
        let duplicate = items.contains {
            normalize($0.userText) == normalize(finding.userText) &&
            normalize($0.summary) == normalize(finding.summary)
        }

        guard !duplicate else { return }

        items.insert(finding, at: 0)
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        persist(items, token: token)
    }

    private func persist(_ items: [BagytAIFinding], token: String?) {
        if let data = try? JSONEncoder().encode(items.sorted(by: { $0.createdAt > $1.createdAt })) {
            UserDefaults.standard.set(data, forKey: scopedKey(base: baseKey, token: token))
        }
    }

    private func shouldCapture(userText: String, assistantText: String) -> Bool {
        let combined = "\(userText) \(assistantText)".lowercased()
        let medicalMarkers = [
            "бол", "симптом", "температур", "тошн", "голов", "серд", "пульс", "давлен",
            "аллерг", "лекар", "диагноз", "врач", "кров", "каш", "одыш", "боль",
            "pain", "symptom", "fever", "heart", "pulse", "allergy", "medicine", "diagnosis"
        ]

        let weakTopics = ["вода", "шаг", "сон", "настроение", "water", "sleep", "steps", "mood"]
        let hasMedicalMarker = medicalMarkers.contains { combined.contains($0) }
        let onlyLifestyle = !hasMedicalMarker && weakTopics.contains { combined.contains($0) }

        return hasMedicalMarker && !onlyLifestyle
    }

    private func makeTitle(from userText: String) -> String {
        let singleLine = userText
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !singleLine.isEmpty else { return "AI-гипотеза из чата" }
        return String(singleLine.prefix(58))
    }

    private func makeSummary(from assistantText: String) -> String {
        let paragraphs = assistantText
            .components(separatedBy: CharacterSet.newlines)
            .map { cleanLine($0) }
            .filter { !$0.isEmpty }

        let first = paragraphs.first ?? "AI дал медицинский контекст по обращению пользователя."
        return String(first.prefix(260))
    }

    private func extractLines(from text: String, markers: [String], limit: Int) -> [String] {
        let rawLines = text
            .components(separatedBy: CharacterSet.newlines)
            .map { cleanLine($0) }
            .filter { !$0.isEmpty }

        var result: [String] = []

        for line in rawLines {
            let lower = line.lowercased()
            guard markers.contains(where: { lower.contains($0) }) else { continue }
            let shortened = String(line.prefix(180))
            if !result.contains(shortened) {
                result.append(shortened)
            }
            if result.count >= limit { break }
        }

        return result
    }

    private func cleanLine(_ line: String) -> String {
        line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-•*0123456789. "))
    }

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func scopedKey(base: String, token: String?) -> String {
        let raw = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = raw?.isEmpty == false ? raw! : "guest"
        let safe = Data(user.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        return "\(base)_\(safe)"
    }
}
