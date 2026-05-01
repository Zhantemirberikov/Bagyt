//
//  ChatView.swift
//  Bagyt
//

import SwiftUI
import Combine

// MARK: - Models

struct BagytChatMessage: Identifiable, Codable, Equatable {
    var id        = UUID()
    var text      : String
    var isUser    : Bool
    var timestamp : Date = Date()
    var isEdited  : Bool = false
    var isThinking: Bool = false
    var isStreaming: Bool = false
}

struct ChatSession: Identifiable, Codable, Equatable {
    var id        = UUID()
    var title     : String
    var messages  : [BagytChatMessage]
    var createdAt : Date = Date()
    var updatedAt : Date = Date()

    var preview: String {
        if let last = messages.last {
            if last.isThinking  { return "Bagyt думает..." }
            if last.isStreaming { return "Bagyt печатает..." }
            return last.text.isEmpty ? "Начните диалог с Bagyt" : last.text
        }
        return "Начните диалог с Bagyt"
    }
}

// MARK: - ChatStore

class ChatStore: ObservableObject {
    @Published var sessions: [ChatSession] = []
    
    // 🔄 ПЕРЕКЛЮЧАТЕЛЬ РЕЖИМОВ
    // true  = Фейковые ответы (для тестов без интернета)
    // false = Реальные запросы на сервер через ChatService
    let isTestMode: Bool = false
    
    private let key       = "bagyt_chat_sessions_v4"
    private let activeKey = "bagyt_active_session_id"

    init() { load() }

    func load() {
        guard let data    = UserDefaults.standard.data(forKey: key),
              var decoded = try? JSONDecoder().decode([ChatSession].self, from: data)
        else { return }
        // Чистим зависшие состояния
        for i in decoded.indices {
            for j in decoded[i].messages.indices {
                if decoded[i].messages[j].isThinking || decoded[i].messages[j].isStreaming {
                    decoded[i].messages[j].isThinking  = false
                    decoded[i].messages[j].isStreaming = false
                    if decoded[i].messages[j].text.isEmpty {
                        decoded[i].messages[j].text = "Генерация была прервана."
                    }
                }
            }
        }
        sessions = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - Возвращает последний активный чат.
    // Если activeKey сохранён и такой чат существует — возвращаем его.
    // Иначе берём самый свежий из списка.
    // Новый чат НЕ создаётся здесь — это делает вызывающий код явно.
    func lastActive() -> ChatSession? {
        // 1. Пробуем по сохранённому ID
        if let idStr = UserDefaults.standard.string(forKey: activeKey),
           let uuid  = UUID(uuidString: idStr),
           let found = sessions.first(where: { $0.id == uuid }) {
            return found
        }
        // 2. Самый свежий из существующих
        return sessions.first
    }

    @discardableResult
    func createNew() -> ChatSession {
        let s = ChatSession(title: "Новый чат", messages: [])
        sessions.insert(s, at: 0)
        save()
        return s
    }

    func setActive(_ session: ChatSession) {
        UserDefaults.standard.set(session.id.uuidString, forKey: activeKey)
    }

    func update(_ session: ChatSession) {
        var s = session; s.updatedAt = Date()
        if let i = sessions.firstIndex(where: { $0.id == s.id }) {
            sessions[i] = s
        } else {
            sessions.insert(s, at: 0)
        }
        sessions.sort { $0.updatedAt > $1.updatedAt }
        save()
    }

    func rename(_ id: UUID, to title: String) {
        if let i = sessions.firstIndex(where: { $0.id == id }) {
            sessions[i].title = title; save()
        }
    }

    func delete(_ session: ChatSession) {
        sessions.removeAll { $0.id == session.id }
        // Если удалили активный — сбрасываем на самый свежий (или убираем ключ)
        if UserDefaults.standard.string(forKey: activeKey) == session.id.uuidString {
            if let next = sessions.first {
                UserDefaults.standard.set(next.id.uuidString, forKey: activeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: activeKey)
            }
        }
        save()
    }

    func deleteAll() {
        sessions.removeAll()
        UserDefaults.standard.removeObject(forKey: activeKey)
        save()
    }

    // MARK: - Отправка и генерация ответа

    func sendMessage(_ text: String, in sessionId: UUID) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionId }) else { return }

        // Добавляем сообщение пользователя
        if sessions[idx].messages.isEmpty {
            sessions[idx].title = String(text.prefix(40))
        }
        sessions[idx].messages.append(
            BagytChatMessage(text: text, isUser: true)
        )
        // Добавляем плейсхолдер AI
        let aiId = UUID()
        sessions[idx].messages.append(
            BagytChatMessage(id: aiId, text: "", isUser: false, isThinking: true)
        )
        sessions[idx].updatedAt = Date()
        sessions.sort { $0.updatedAt > $1.updatedAt }
        // НЕ сохраняем здесь — сохраним после завершения

        if isTestMode {
            let delay = Double.random(in: 1.8...2.8)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                self.beginStreaming(aiId: aiId, sessionId: sessionId, fullText: self.mockReply(to: text), sourceUserText: text)
            }
        } else {
            ChatService.shared.sendMessageToAI(userText: text) { [weak self] responseMsg in
                guard let self else { return }
                self.beginStreaming(aiId: aiId, sessionId: sessionId, fullText: responseMsg.text, sourceUserText: text)
            }
        }
    }
    
    // MARK: - Редактирование и повторная генерация
    func editAndRegenerate(messageId: UUID, in sessionId: UUID, newText: String) {
        guard let sIdx = sessions.firstIndex(where: { $0.id == sessionId }),
              let mIdx = sessions[sIdx].messages.firstIndex(where: { $0.id == messageId }) else { return }

        sessions[sIdx].messages[mIdx].text = newText
        sessions[sIdx].messages[mIdx].isEdited = true

        if mIdx + 1 < sessions[sIdx].messages.count {
            sessions[sIdx].messages.removeSubrange((mIdx + 1)...)
        }

        let aiId = UUID()
        sessions[sIdx].messages.append(
            BagytChatMessage(id: aiId, text: "", isUser: false, isThinking: true)
        )

        sessions[sIdx].updatedAt = Date()
        sessions.sort { $0.updatedAt > $1.updatedAt }
        
        if isTestMode {
            let delay = Double.random(in: 1.8...2.8)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                self.beginStreaming(aiId: aiId, sessionId: sessionId, fullText: self.mockReply(to: newText), sourceUserText: newText)
            }
        } else {
            ChatService.shared.sendMessageToAI(userText: newText) { [weak self] responseMsg in
                guard let self else { return }
                self.beginStreaming(aiId: aiId, sessionId: sessionId, fullText: responseMsg.text, sourceUserText: newText)
            }
        }
    }

    private func beginStreaming(aiId: UUID, sessionId: UUID, fullText: String, sourceUserText: String) {
        guard let sIdx = sessions.firstIndex(where: { $0.id == sessionId }),
              let mIdx = sessions[sIdx].messages.firstIndex(where: { $0.id == aiId })
        else { return }

        sessions[sIdx].messages[mIdx].isThinking  = false
        sessions[sIdx].messages[mIdx].isStreaming  = true

        let chars = Array(fullText)
        var pos   = 0

        func appendNext() {
            guard let si = self.sessions.firstIndex(where: { $0.id == sessionId }),
                  let mi = self.sessions[si].messages.firstIndex(where: { $0.id == aiId }),
                  self.sessions[si].messages[mi].isStreaming
            else { return }

            if pos < chars.count {
                self.sessions[si].messages[mi].text.append(chars[pos])
                pos += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) { appendNext() }
            } else {
                self.sessions[si].messages[mi].isStreaming = false
                self.sessions[si].updatedAt = Date()
                self.sessions.sort { $0.updatedAt > $1.updatedAt }
                BagytMemoryStore.shared.captureAIResponse(userText: sourceUserText, assistantText: fullText)
                self.save()
            }
        }

        appendNext()
    }

    func stopGenerating(in sessionId: UUID) {
        guard let sIdx = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        for mIdx in sessions[sIdx].messages.indices {
            if sessions[sIdx].messages[mIdx].isThinking || sessions[sIdx].messages[mIdx].isStreaming {
                sessions[sIdx].messages[mIdx].isThinking  = false
                sessions[sIdx].messages[mIdx].isStreaming  = false
                if sessions[sIdx].messages[mIdx].text.isEmpty {
                    sessions[sIdx].messages[mIdx].text = "Генерация остановлена."
                }
            }
        }
        save()
    }

    var isGenerating: Bool {
        sessions.contains { s in s.messages.contains { $0.isThinking || $0.isStreaming } }
    }

    func isGenerating(in sessionId: UUID) -> Bool {
        guard let s = sessions.first(where: { $0.id == sessionId }) else { return false }
        return s.messages.contains { $0.isThinking || $0.isStreaming }
    }

    private func mockReply(to text: String) -> String {
        ["Я понимаю ваш вопрос. На основе медицинских данных — это нормальная ситуация. Рекомендую обратиться к специалисту для детальной консультации.",
         "Регулярные нагрузки и сбалансированное питание значительно улучшают самочувствие. Постарайтесь выпивать не менее 2 литров воды в день.",
         "Каждый организм индивидуален. Рекомендую вести дневник самочувствия в разделе «Журнал» и отслеживать изменения.",
         "Ваши симптомы могут быть связаны с несколькими факторами. Увеличьте потребление воды, наладьте режим сна и снизьте уровень стресса."
        ].randomElement()!
    }
}

// MARK: - ChatView

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var store = ChatStore()
    @State private var currentSessionId: UUID? = nil
    @State private var showHistory = false
    
    @AppStorage("isDarkModeEnabled") private var isDarkMode = false

    private let bg = Color(red: 0.878, green: 0.949, blue: 0.992)

    private var activeSession: ChatSession? {
        guard let id = currentSessionId else { return nil }
        return store.sessions.first(where: { $0.id == id })
    }

    /// Находит последний активный чат или создаёт новый если сессий нет.
    /// Вызывается при onAppear и при изменении списка сессий.
    private func resolveActiveSession() {
        if let id = currentSessionId, store.sessions.first(where: { $0.id == id }) != nil {
            // Текущая сессия жива — ничего не делаем
            return
        }
        if let existing = store.lastActive() {
            currentSessionId = existing.id
            store.setActive(existing)
        } else {
            // Сессий нет совсем (первый запуск или удалили все)
            let s = store.createNew()
            currentSessionId = s.id
            store.setActive(s)
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: isDarkMode
                    ? [Color(red: 0.05, green: 0.07, blue: 0.10), Color(red: 0.08, green: 0.10, blue: 0.15), Color(red: 0.05, green: 0.07, blue: 0.10)]
                    : [bg, Color(red:0.941,green:0.976,blue:1.0), bg],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // ✅ FIX: activeSession может быть nil только в первый момент до onAppear.
            // Не создаём новый чат здесь — всё в onAppear.
            if let session = activeSession {
                ChatSessionView(
                    sessionId: session.id,
                    store: store,
                    onDismiss:     { dismiss() },
                    onNewChat:     {
                        let s = store.createNew()
                        store.setActive(s)
                        currentSessionId = s.id
                    },
                    onShowHistory: { showHistory = true }
                )
                .id(session.id)
                .environmentObject(appState)
                .environmentObject(lang)
            } else {
                // Пустой экран пока onAppear не отработал (мгновенно)
                Color.clear
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear {
            resolveActiveSession()
        }
        // ✅ FIX: Реагируем на любое изменение списка сессий (deleteAll, delete).
        // Если текущая сессия пропала — сразу находим или создаём новую.
        .onChange(of: store.sessions) { sessions in
            let stillExists = sessions.first(where: { $0.id == currentSessionId }) != nil
            if !stillExists {
                resolveActiveSession()
            }
        }
        .sheet(isPresented: $showHistory) {
            ChatHistoryView(store: store) { selected in
                currentSessionId = selected.id
                store.setActive(selected)
                showHistory = false
            }
        }
    }
}

// MARK: - ChatHistoryView

struct ChatHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ChatStore
    let onSelect: (ChatSession) -> Void
    
    @AppStorage("isDarkModeEnabled") private var isDarkMode = false

    @State private var renamingID    : UUID? = nil
    @State private var renameText    = ""
    @State private var showRename    = false
    @State private var showDeleteAll = false

    private let accent  = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)
    private let bg      = Color(red: 0.878, green: 0.949, blue: 0.992)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: isDarkMode
                    ? [Color(red: 0.05, green: 0.07, blue: 0.10), Color(red: 0.08, green: 0.10, blue: 0.15), Color(red: 0.05, green: 0.07, blue: 0.10)]
                    : [bg, Color(red:0.941,green:0.976,blue:1.0), bg],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        ZStack {
                            Circle()
                                .fill(isDarkMode ? Color.white.opacity(0.1) : Color.white.opacity(0.75))
                                .frame(width: 40, height: 40)
                                .shadow(color: accent.opacity(0.10), radius: 6, x: 0, y: 2)
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(isDarkMode ? .white.opacity(0.8) : Color(red:0.3,green:0.45,blue:0.6))
                        }
                    }
                    Spacer()
                    Text("История чатов")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(isDarkMode ? .white : Color(red:0.06,green:0.09,blue:0.16))
                    Spacer()
                    if !store.sessions.isEmpty {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showDeleteAll = true
                        } label: {
                            ZStack {
                                Circle().fill(Color(red:0.95,green:0.25,blue:0.25).opacity(0.10))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(red:0.95,green:0.25,blue:0.25))
                            }
                        }
                    } else {
                        Color.clear.frame(width: 40, height: 40)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)

                if store.sessions.isEmpty {
                    Spacer()
                    VStack(spacing: 14) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(accent.opacity(0.35))
                        Text("Нет сохранённых чатов")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : Color(red:0.4,green:0.55,blue:0.65))
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(store.sessions) { session in
                            historyRow(session)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                        }
                        .onDelete { idx in
                            withAnimation { idx.forEach { store.delete(store.sessions[$0]) } }
                        }
                    }
                    .listStyle(.plain)
                    .scrollIndicators(.hidden)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .confirmationDialog("Удалить все чаты?", isPresented: $showDeleteAll, titleVisibility: .visible) {
            Button("Удалить все", role: .destructive) { withAnimation { store.deleteAll() }; dismiss() }
            Button("Отмена", role: .cancel) {}
        }
        .alert("Переименовать чат", isPresented: $showRename) {
            TextField("Название", text: $renameText)
                .colorScheme(isDarkMode ? .dark : .light)
            Button("Сохранить") {
                if let id = renamingID, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                    store.rename(id, to: renameText)
                }
            }
            Button("Отмена", role: .cancel) {}
        }
    }

    private func historyRow(_ session: ChatSession) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSelect(session)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white.opacity(0.1))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(LinearGradient(stops: [.init(color: Color.cyan.opacity(0.6), location: 0.0), .init(color: .clear, location: 0.3), .init(color: .clear, location: 0.7), .init(color: Color.purple.opacity(0.6), location: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                        .blur(radius: 2)
                        .blendMode(.plusLighter)

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(LinearGradient(stops: [.init(color: .white.opacity(0.9), location: 0), .init(color: .white.opacity(0.1), location: 0.3), .init(color: .white.opacity(0.1), location: 0.7), .init(color: .white.opacity(0.4), location: 1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)

                    LottieView(animationName: "aiaia")
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .frame(width: 50, height: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(session.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(isDarkMode ? .white : Color(red:0.06,green:0.09,blue:0.16)).lineLimit(1)
                        Spacer()
                        Text(formatDate(session.updatedAt))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isDarkMode ? .white.opacity(0.5) : Color(red:0.55,green:0.67,blue:0.75))
                    }
                    Text(session.preview)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : Color(red:0.4,green:0.55,blue:0.65)).lineLimit(1)
                    Text("\(session.messages.count) сообщ.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.5) : Color(red:0.6,green:0.72,blue:0.78))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white.opacity(0.3) : Color(red:0.75,green:0.85,blue:0.90))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isDarkMode ? Color(red: 0.12, green: 0.14, blue: 0.18) : Color.white.opacity(0.88))
                    .shadow(color: accent.opacity(isDarkMode ? 0 : 0.07), radius: 8, x: 0, y: 3)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(isDarkMode ? Color.white.opacity(0.1) : Color.white.opacity(0.90), lineWidth: 1))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button {
                renamingID = session.id; renameText = session.title; showRename = true
            } label: { Label("Переименовать", systemImage: "pencil") }
            Divider()
            Button(role: .destructive) {
                withAnimation { store.delete(session) }
            } label: { Label("Удалить", systemImage: "trash") }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation { store.delete(session) }
            } label: { Label("Удалить", systemImage: "trash") }
            .tint(Color(red:0.95,green:0.25,blue:0.25))
        }
    }

    private func formatDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
        } else if cal.isDateInYesterday(date) { return "Вчера" }
        let f = DateFormatter(); f.dateFormat = "d MMM"; f.locale = Locale(identifier: "ru_RU")
        return f.string(from: date)
    }
}

// MARK: - ThinkingIndicator

struct ThinkingIndicator: View {
    @AppStorage("isDarkModeEnabled") private var isDarkMode = false
    
    private let accent  = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)
    private let phases  = ["Думаю над ответом","Анализирую информацию","Формулирую ответ","Почти готово"]

    @State private var phase = 0
    @State private var dot   = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .background(.ultraThinMaterial, in: Circle())
                    .frame(width: 28, height: 28)
                
                Circle()
                    .strokeBorder(LinearGradient(stops: [.init(color: Color.cyan.opacity(0.6), location: 0.0), .init(color: .clear, location: 0.3), .init(color: .clear, location: 0.7), .init(color: Color.purple.opacity(0.6), location: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                    .frame(width: 28, height: 28)
                    .blur(radius: 1)
                    .blendMode(.plusLighter)

                Circle()
                    .strokeBorder(LinearGradient(stops: [.init(color: .white.opacity(0.9), location: 0), .init(color: .white.opacity(0.1), location: 0.3), .init(color: .white.opacity(0.1), location: 0.7), .init(color: .white.opacity(0.4), location: 1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.5)
                    .frame(width: 28, height: 28)

                LottieView(animationName: "aiaia").frame(width: 28, height: 28).clipShape(Circle())
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(phases[min(phase, phases.count-1)])
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : Color(red:0.4,green:0.55,blue:0.65))
                    .animation(.easeInOut, value: phase)
                ZStack(alignment: .leading) {
                    Capsule().fill(accent.opacity(0.12)).frame(width: 120, height: 3)
                    Capsule()
                        .fill(LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing))
                        .frame(width: CGFloat(phase + 1) * 30, height: 3)
                        .animation(.easeInOut(duration: 0.5), value: phase)
                }
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(accent.opacity(dot == i ? 0.9 : 0.22))
                            .frame(width: 7, height: 7)
                            .scaleEffect(dot == i ? 1.3 : 1.0)
                            .animation(.spring(response: 0.3), value: dot)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(
                    (isDarkMode ? Color(red: 0.12, green: 0.14, blue: 0.18).opacity(0.9) : Color.white.opacity(0.90))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: isDarkMode ? .clear : .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
            }
            Spacer(minLength: 60)
        }
        .onAppear { startAnim() }
    }

    private func startAnim() {
        func tick(_ n: Int) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.25)) { dot = n % 3 }
                if n % 5 == 0 { withAnimation { phase = min(phase + 1, phases.count - 1) } }
                tick(n + 1)
            }
        }
        tick(0)
    }
}

// MARK: - ChatSessionView

struct ChatSessionView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lang: LanguageManager
    @AppStorage("isDarkModeEnabled") private var isDarkMode = false

    let sessionId    : UUID
    @ObservedObject var store: ChatStore
    let onDismiss    : () -> Void
    let onNewChat    : () -> Void
    let onShowHistory: () -> Void

    private var session: ChatSession {
        store.sessions.first(where: { $0.id == sessionId })
        ?? ChatSession(title: "", messages: [])
    }
    private var isGenerating: Bool { store.isGenerating(in: sessionId) }

    @State private var inputText     = ""
    @State private var editingMsg    : BagytChatMessage? = nil
    @State private var editText      = ""
    @State private var orbPulse      = false
    @FocusState private var focused  : Bool

    private let accent  = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)
    private let bg      = Color(red: 0.878, green: 0.949, blue: 0.992)

    private var sendColor: Color {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? Color(red:0.75,green:0.85,blue:0.92) : accent
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            messageList
            inputBar
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) { orbPulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focused = true
            }
        }
        .sheet(item: $editingMsg) { msg in editSheet(msg) }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Button { onDismiss() } label: {
                ZStack {
                    Circle().fill(isDarkMode ? Color.white.opacity(0.1) : Color.white.opacity(0.75)).frame(width: 38, height: 38)
                        .shadow(color: accent.opacity(0.10), radius: 5, x: 0, y: 2)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : Color(red:0.3,green:0.45,blue:0.6))
                }
            }
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .background(.ultraThinMaterial, in: Circle())
                    .frame(width: 42, height: 42)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                
                Circle()
                    .strokeBorder(LinearGradient(stops: [.init(color: Color.cyan.opacity(0.6), location: 0.0), .init(color: .clear, location: 0.3), .init(color: .clear, location: 0.7), .init(color: Color.purple.opacity(0.6), location: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                    .frame(width: 42, height: 42)
                    .blur(radius: 1.5)
                    .blendMode(.plusLighter)

                Circle()
                    .strokeBorder(LinearGradient(stops: [.init(color: .white.opacity(0.9), location: 0), .init(color: .white.opacity(0.1), location: 0.3), .init(color: .white.opacity(0.1), location: 0.7), .init(color: .white.opacity(0.4), location: 1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    .frame(width: 42, height: 42)

                LottieView(animationName: "aiaia").frame(width: 42, height: 42).clipShape(Circle())
                
                Circle().stroke(Color.white.opacity(0.4), lineWidth: 1.5).frame(width: 42, height: 42)
                    .scaleEffect(orbPulse ? 1.35 : 1.0)
                    .opacity(orbPulse ? 0.0 : 0.8)
                    .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: orbPulse)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Bagyt").font(.system(size: 16, weight: .black))
                    .foregroundColor(isDarkMode ? .white : Color(red:0.06,green:0.09,blue:0.16))
                HStack(spacing: 4) {
                    Circle()
                        .fill(isGenerating ? Color(red:1.0,green:0.65,blue:0.10) : Color(red:0.1,green:0.78,blue:0.48))
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: isGenerating)
                    Text(isGenerating ? "Bagyt печатает..." : "AI помощник · онлайн")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : Color(red:0.4,green:0.55,blue:0.65)).lineLimit(1)
                }
            }
            Spacer()
            Button { onShowHistory() } label: {
                ZStack {
                    Circle().fill(isDarkMode ? Color.white.opacity(0.1) : Color.white.opacity(0.75)).frame(width: 38, height: 38)
                        Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : Color(red:0.3,green:0.45,blue:0.6))
                }
            }
            Button { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); onNewChat() } label: {
                ZStack {
                    Circle().fill(accent.opacity(0.12)).frame(width: 38, height: 38)
                    Image(systemName: "plus.bubble").font(.system(size: 14, weight: .semibold)).foregroundColor(accent)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(
            Rectangle().fill(.ultraThinMaterial)
                .overlay(Rectangle().fill(isDarkMode ? Color.black.opacity(0.4) : Color.white.opacity(0.50)))
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    if session.messages.isEmpty { welcomeCard }
                    ForEach(session.messages) { msg in
                        Group {
                            if msg.isThinking {
                                ThinkingIndicator()
                            } else {
                                messageBubble(msg)
                            }
                        }
                        .id(msg.id)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .onChange(of: session.messages) { msgs in
                if let last = msgs.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: Welcome

    private var welcomeCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .background(.ultraThinMaterial, in: Circle())
                    .frame(width: 90, height: 90)
                    .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
                    .shadow(color: Color.white.opacity(0.3), radius: 10, x: -2, y: -2)
                
                Circle()
                    .strokeBorder(LinearGradient(stops: [.init(color: Color.cyan.opacity(0.6), location: 0.0), .init(color: .clear, location: 0.3), .init(color: .clear, location: 0.7), .init(color: Color.purple.opacity(0.6), location: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 4)
                    .frame(width: 90, height: 90)
                    .blur(radius: 3)
                    .blendMode(.plusLighter)

                Circle()
                    .strokeBorder(LinearGradient(stops: [.init(color: .white.opacity(0.9), location: 0), .init(color: .white.opacity(0.1), location: 0.3), .init(color: .white.opacity(0.1), location: 0.7), .init(color: .white.opacity(0.4), location: 1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                    .frame(width: 90, height: 90)

                LottieView(animationName: "aiaia").frame(width: 90, height: 90).clipShape(Circle())
            }
            VStack(spacing: 8) {
                Text("Привет! Я Bagyt 👋").font(.system(size: 22, weight: .black))
                    .foregroundColor(isDarkMode ? .white : Color(red:0.06,green:0.09,blue:0.16))
                Text("Ваш персональный AI-помощник по здоровью.\nСпросите меня о симптомах или получите рекомендации.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : Color(red:0.4,green:0.55,blue:0.65))
                    .multilineTextAlignment(.center).lineSpacing(4)
            }
            VStack(spacing: 8) {
                Text("Попробуйте спросить:").font(.system(size: 12, weight: .bold))
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : Color(red:0.55,green:0.67,blue:0.75)).tracking(0.5)
                ForEach(["Как улучшить качество сна?",
                         "У меня болит голова, что делать?",
                         "Сколько воды нужно пить в день?"], id: \.self) { q in
                    Button {
                        inputText = q; sendMessage()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack {
                            Text(q).font(.system(size: 13, weight: .semibold))
                                .foregroundColor(accent).multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .bold))
                                .foregroundColor(accent.opacity(0.55))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(accent.opacity(isDarkMode ? 0.15 : 0.07))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(accent.opacity(isDarkMode ? 0.25 : 0.14), lineWidth: 1)))
                    }
                }
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(isDarkMode ? Color(red: 0.12, green: 0.14, blue: 0.18) : Color.white.opacity(0.85))
            .shadow(color: accent.opacity(isDarkMode ? 0 : 0.08), radius: 14, x: 0, y: 5))
        .padding(.vertical, 10)
    }

    // MARK: Bubble

    private func messageBubble(_ msg: BagytChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if msg.isUser { Spacer(minLength: 50) }
            if !msg.isUser {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .background(.ultraThinMaterial, in: Circle())
                        .frame(width: 28, height: 28)
                    
                    Circle()
                        .strokeBorder(LinearGradient(stops: [.init(color: Color.cyan.opacity(0.6), location: 0.0), .init(color: .clear, location: 0.3), .init(color: .clear, location: 0.7), .init(color: Color.purple.opacity(0.6), location: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                        .frame(width: 28, height: 28)
                        .blur(radius: 1)
                        .blendMode(.plusLighter)

                    Circle()
                        .strokeBorder(LinearGradient(stops: [.init(color: .white.opacity(0.9), location: 0), .init(color: .white.opacity(0.1), location: 0.3), .init(color: .white.opacity(0.1), location: 0.7), .init(color: .white.opacity(0.4), location: 1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.5)
                        .frame(width: 28, height: 28)

                    LottieView(animationName: "aiaia").frame(width: 28, height: 28).clipShape(Circle())
                }
            }
            VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(msg.text.isEmpty ? " " : msg.text)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(msg.isUser ? .white : (isDarkMode ? .white : Color(red:0.06,green:0.09,blue:0.16)))
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(bubbleBg(isUser: msg.isUser))
                }
                .contextMenu {
                    if msg.isUser {
                        Button { editingMsg = msg; editText = msg.text }
                        label: { Label("Редактировать", systemImage: "pencil") }
                    }
                    Button(role: .destructive) {
                        if let si = store.sessions.firstIndex(where: { $0.id == sessionId }) {
                            var s = store.sessions[si]
                            s.messages.removeAll { $0.id == msg.id }
                            store.update(s)
                        }
                    } label: { Label("Удалить", systemImage: "trash") }
                }

                HStack(spacing: 4) {
                    Text(fmtTime(msg.timestamp)).font(.system(size: 10, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.5) : Color(red:0.55,green:0.67,blue:0.75))
                    if msg.isEdited { Text("· изм.").font(.system(size: 10, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.5) : Color(red:0.55,green:0.67,blue:0.75)) }
                }
            }
            if !msg.isUser { Spacer(minLength: 50) }
        }
    }

    @ViewBuilder
    private func bubbleBg(isUser: Bool) -> some View {
        if isUser {
            LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: accent.opacity(isDarkMode ? 0.1 : 0.28), radius: 6, x: 0, y: 2)
        } else {
            (isDarkMode ? Color(red: 0.16, green: 0.18, blue: 0.22) : Color.white.opacity(0.90))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: isDarkMode ? .clear : .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: Input

    private var inputBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    TextField("Напишите Bagyt...", text: $inputText, axis: .vertical)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isDarkMode ? .white : Color(red:0.06,green:0.09,blue:0.16))
                        .lineLimit(1...5).focused($focused)
                        .colorScheme(isDarkMode ? .dark : .light)
                    if !inputText.isEmpty {
                        Button {
                            withAnimation(.spring(response: 0.3)) { inputText = "" }
                        } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 18))
                                .foregroundColor(isDarkMode ? .white.opacity(0.5) : Color(red:0.6,green:0.72,blue:0.78))
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isDarkMode ? Color(red: 0.12, green: 0.14, blue: 0.18) : Color.white.opacity(0.88))
                    .shadow(color: accent.opacity(isDarkMode ? 0 : 0.08), radius: 8, x: 0, y: 2))

                if isGenerating {
                    Button {
                        store.stopGenerating(in: sessionId)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        ZStack {
                            Circle().fill(Color(red:1.0,green:0.25,blue:0.25).opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "stop.fill").font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(red:1.0,green:0.25,blue:0.25))
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Button { sendMessage() } label: {
                        ZStack {
                            Circle().fill(sendColor).frame(width: 44, height: 44)
                                .shadow(color: inputText.isEmpty ? .clear : accent.opacity(isDarkMode ? 0.15 : 0.35), radius: 10, x: 0, y: 4)
                            Image(systemName: "arrow.up").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                        }
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .animation(.spring(response: 0.3), value: inputText.isEmpty)
                }
            }
            Text("ИИ может ошибаться. Не заменяет консультацию врача.")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isDarkMode ? .white.opacity(0.5) : Color(red:0.55,green:0.67,blue:0.75))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)
        .background(Rectangle().fill(.ultraThinMaterial)
            .overlay(Rectangle().fill(isDarkMode ? Color.black.opacity(0.4) : Color.white.opacity(0.55)))
            .ignoresSafeArea(edges: .bottom))
    }

    // MARK: Edit Sheet

    private func editSheet(_ msg: BagytChatMessage) -> some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: isDarkMode
                        ? [Color(red: 0.05, green: 0.07, blue: 0.10), Color(red: 0.08, green: 0.10, blue: 0.15), Color(red: 0.05, green: 0.07, blue: 0.10)]
                        : [bg, Color(red:0.941,green:0.976,blue:1.0), bg],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Редактировать").font(.system(size: 18, weight: .black))
                        .foregroundColor(isDarkMode ? .white : Color(red:0.06,green:0.09,blue:0.16)).padding(.top, 20)
                    TextEditor(text: $editText).font(.system(size: 15))
                        .padding(14)
                        .colorScheme(isDarkMode ? .dark : .light)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isDarkMode ? Color(red: 0.12, green: 0.14, blue: 0.18) : Color.white.opacity(0.88)))
                        .frame(minHeight: 120).padding(.horizontal, 20)
                    Button {
                        store.editAndRegenerate(messageId: msg.id, in: sessionId, newText: editText)
                        editingMsg = nil
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        Text("Сохранить").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing))
                            .clipShape(Capsule()).shadow(color: accent.opacity(isDarkMode ? 0.15 : 0.35), radius: 12, x: 0, y: 5)
                    }.padding(.horizontal, 20)
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { editingMsg = nil }.foregroundColor(accent)
                }
            }
        }
    }

    // MARK: Send

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        store.sendMessage(text, in: sessionId)
    }

    private func fmtTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
    }
}

#Preview {
    ChatView()
        .environmentObject(AppState())
        .environmentObject(LanguageManager())
}
