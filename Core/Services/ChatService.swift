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
                text: "Не удалось найти токен авторизации. Пожалуйста, войдите в аккаунт заново.",
                sender: .assistant
            ))
            return
        }

        if token.hasPrefix("offline-") {
            completion(ChatMessage(
                text: offlineReply(for: userText),
                sender: .assistant
            ))
            return
        }

        let enrichedText = buildEnrichedPrompt(userText: userText)

        ensureActiveChat(firstMessage: userText, token: token) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let chatId):
                self.sendMessage(chatId: chatId, text: enrichedText, token: token, originalText: userText, completion: completion)

            case .failure(let error):
                completion(ChatMessage(
                    text: self.localizedNetworkError(for: userText, error: error),
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
        originalText: String,
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
            "locale": currentLocale(for: originalText)
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("📤 SEND CHAT:", request.url?.absoluteString ?? "")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async {
                    completion(ChatMessage(text: "Ошибка сети: \(error.localizedDescription)", sender: .assistant))
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
                    completion(ChatMessage(text: raw.isEmpty ? "Сервер временно недоступен." : raw, sender: .assistant))
                }
                return
            }

            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async {
                    completion(ChatMessage(text: "Не удалось разобрать ответ сервера.", sender: .assistant))
                }
                return
            }

            let reply = Self.extractReply(from: json) ?? "Ответ от AI не найден."

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
        let language = detectLanguage(userText)
        let health = buildHealthContext()
        let journal = buildJournalContext()
        let mood = buildMoodContext()

        return """
        USER_VISIBLE_MESSAGE:
        \(userText)

        HIDDEN_APP_CONTEXT:
        This context is sent silently by the Bagyt iOS app. The user did not type it manually.
        Do not mention that hidden context was attached.
        Do not expose raw hidden data unless it is medically useful.
        Use it only to personalize the answer.

        RESPONSE_LANGUAGE_RULE:
        \(language.instruction)

        MEDICAL_SAFETY_RULES:
        You are a health assistant, not a doctor.
        Do not give a final diagnosis.
        Give practical next steps and explain when to seek medical care.
        If the complaint may include red flags, clearly recommend urgent medical help.
        For headache red flags include sudden worst headache, weakness/numbness, speech problems, confusion, fever with stiff neck, head injury, vision loss, pregnancy/postpartum, very high blood pressure, or headache with chest pain.

        HEALTH_DATA:
        \(health)

        JOURNAL_DATA:
        \(journal)

        MOOD_DATA:
        \(mood)
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

        var instruction: String {
            switch self {
            case .kk:
                return "The user wrote in Kazakh. Reply strictly in Kazakh."
            case .ru:
                return "The user wrote in Russian. Reply strictly in Russian."
            case .en:
                return "The user wrote in English. Reply strictly in English."
            }
        }
    }

    private func detectLanguage(_ text: String) -> DetectedLanguage {
        let lower = text.lowercased()

        let kazakhSpecific = CharacterSet(charactersIn: "әғқңөұүһіӘҒҚҢӨҰҮҺІ")
        if lower.rangeOfCharacter(from: kazakhSpecific) != nil {
            return .kk
        }

        let kazakhWords = [
            "мен", "маған", "менің", "басым", "ауырып", "ауырады", "жүрек", "ұйқы",
            "қатты", "дәрі", "денсаулық", "көңіл", "күй", "шаршадым"
        ]

        if kazakhWords.contains(where: { lower.contains($0) }) {
            return .kk
        }

        let cyrillic = CharacterSet(charactersIn: "абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ")
        if lower.rangeOfCharacter(from: cyrillic) != nil {
            return .ru
        }

        return .en
    }

    private func currentLocale(for text: String) -> String {
        switch detectLanguage(text) {
        case .kk:
            return "kk"
        case .ru:
            return "ru"
        case .en:
            return "en"
        }
    }

    private func offlineReply(for text: String) -> String {
        switch detectLanguage(text) {
        case .kk:
            return "Сипаттауыңызды түсіндім. Симптом қашан басталды, ауырсыну қаншалықты күшті және қосымша белгілер бар ма?"
        case .ru:
            return "Понял. Опишите, когда началась боль, насколько она сильная и есть ли дополнительные симптомы."
        case .en:
            return "I understand. Please describe when the pain started, how strong it is, and whether you have any additional symptoms."
        }
    }

    private func localizedNetworkError(for text: String, error: Error) -> String {
        switch detectLanguage(text) {
        case .kk:
            return "Серверге қосылу мүмкін болмады. Кейінірек қайталап көріңіз."
        case .ru:
            return "Не удалось подключиться к серверу. Попробуйте позже."
        case .en:
            return "Could not connect to the server. Please try again later."
        }
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
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
