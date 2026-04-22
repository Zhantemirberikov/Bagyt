//
//  ChatView.swift
//  Bagyt
//
//  Full redesign — Liquid Glass · Bagyt design system
//  ChatViewModel и ChatService не тронуты
//

import SwiftUI
import Combine
import UIKit

// MARK: - ChatViewModel (оригинальный, без изменений)

final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String       = ""
    @Published var isSending               = false
    private var cancellables               = Set<AnyCancellable>()

    init() { load() }

    func load() {
        messages = ChatService.shared.loadMessages()
    }

    func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSending = true
        let userMsg = ChatMessage(text: trimmed, sender: .user)
        messages.append(userMsg)
        ChatService.shared.saveMessages(messages)
        inputText = ""
        ChatService.shared.sendMessageToAI(userText: trimmed) { [weak self] reply in
            guard let self = self else { return }
            self.messages.append(reply)
            ChatService.shared.saveMessages(self.messages)
            withAnimation { self.isSending = false }
        }
    }

    func clearHistory() {
        messages = []
        ChatService.shared.saveMessages(messages)
    }
}

// MARK: - ChatView

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lang: LanguageManager
    @StateObject private var vm       = ChatViewModel()
    @StateObject private var keyboard = KeyboardObserver()
    @FocusState  private var inputFocused: Bool
    @State private var showAssistantInfo = false
    @State private var showClearAlert    = false
    @State private var appear            = false

    private let accent  = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.87, green: 0.95, blue: 1.0),
                    Color(red: 0.93, green: 0.97, blue: 1.0),
                    Color(red: 0.89, green: 0.97, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                liquidHeader
                messagesArea
                suggestionsBar
                liquidInputBar
            }
        }
        .onAppear {
            vm.load()
            withAnimation(.easeOut(duration: 0.4)) { appear = true }
        }
        .onTapGesture { inputFocused = false }
        .alert("Очистить чат?", isPresented: $showClearAlert) {
            Button("Очистить", role: .destructive) {
                withAnimation { vm.clearHistory() }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("История переписки будет удалена")
        }
        .sheet(isPresented: $showAssistantInfo) {
            AssistantInfoView()
                .environmentObject(appState)
                .environmentObject(lang)
        }
    }
    // MARK: - Liquid Glass Header

    private var liquidHeader: some View {
        ZStack {
            // Liquid glass background
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.35))
                )
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.06), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(accent.opacity(0.12))
                        .frame(height: 0.5)
                }

            HStack(spacing: 14) {
                // Lottie orb avatar — сохранён полностью
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showAssistantInfo.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(colors: [accent.opacity(0.15), accent2.opacity(0.1)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 52, height: 52)
                            .overlay(Circle().strokeBorder(accent.opacity(0.2), lineWidth: 1.5))

                        LottieView(animationName: "aiaia")
                            .frame(width: 52, height: 52)
                            .clipShape(Circle())
                            .shadow(color: accent.opacity(0.25), radius: 8, x: 0, y: 3)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(localizedKey("assistant"))
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))

                    HStack(spacing: 5) {
                        Circle()
                            .fill(vm.isSending
                                  ? Color(red: 1.0, green: 0.65, blue: 0.1)
                                  : Color(red: 0.1, green: 0.78, blue: 0.48))
                            .frame(width: 7, height: 7)
                            .scaleEffect(vm.isSending ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                                       value: vm.isSending)
                        Text(vm.isSending ? "Думает..." : "Онлайн")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(vm.isSending
                                             ? Color(red: 1.0, green: 0.65, blue: 0.1)
                                             : Color(red: 0.1, green: 0.78, blue: 0.48))
                    }
                }

                Spacer()

                // Clear button
                Button { showClearAlert = true } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 36, height: 36)
                            .overlay(Circle().strokeBorder(Color(red: 0.88, green: 0.93, blue: 0.97), lineWidth: 1))
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 0.5, green: 0.63, blue: 0.72))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(height: 80)
    }

    // MARK: - Messages Area

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    // Welcome message if empty
                    if vm.messages.isEmpty {
                        welcomeCard
                            .padding(.top, 20)
                    }

                    ForEach(vm.messages) { msg in
                        bubbleRow(msg: msg)
                            .id(msg.id)
                            .padding(.horizontal, 16)
                            .transition(.asymmetric(
                                insertion: .move(edge: msg.sender == .user ? .trailing : .leading)
                                    .combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    // Typing indicator
                    if vm.isSending {
                        HStack(alignment: .bottom, spacing: 8) {
                            botAvatar
                            typingBubble
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .id("typing")
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }

                    Color.clear.frame(height: 8).id("bottom")
                }
                .padding(.top, 12)
                .padding(.bottom, 8)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.messages.count)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.isSending)
            }
            .onChange(of: vm.messages.count) { _ in scrollToBottom(proxy) }
            .onChange(of: vm.isSending)      { _ in scrollToBottom(proxy) }
            .onChange(of: keyboard.keyboardHeight) { _ in scrollToBottom(proxy) }
        }
    }

    // MARK: - Welcome Card

    private var welcomeCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [accent.opacity(0.1), accent2.opacity(0.05)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                LottieView(animationName: "aiaia")
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .shadow(color: accent.opacity(0.2), radius: 12, x: 0, y: 5)
            }

            VStack(spacing: 8) {
                Text("Привет! Я Bagyt 👋")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                Text("Ваш персональный медицинский\nИИ-ассистент. Чем могу помочь?")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.55, blue: 0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.75))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(accent.opacity(0.1), lineWidth: 1))
                .shadow(color: accent.opacity(0.08), radius: 16, x: 0, y: 6)
        )
        .padding(.horizontal, 20)
        .opacity(appear ? 1 : 0)
        .scaleEffect(appear ? 1 : 0.95)
    }

    // MARK: - Bubble Row

    @ViewBuilder
    private func bubbleRow(msg: ChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if msg.sender == .assistant {
                botAvatar
                assistantBubble(msg)
                Spacer(minLength: 48)
            } else {
                Spacer(minLength: 48)
                userBubble(msg)
            }
        }
    }

    private var botAvatar: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [accent.opacity(0.12), accent2.opacity(0.08)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 32, height: 32)
                .overlay(Circle().strokeBorder(accent.opacity(0.15), lineWidth: 1))
            LottieView(animationName: "aiaia")
                .frame(width: 32, height: 32)
                .clipShape(Circle())
        }
    }

    private func assistantBubble(_ msg: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            // Liquid glass bubble
            Text(msg.text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                .lineSpacing(3)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.55))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                        )
                        .shadow(color: accent.opacity(0.10), radius: 8, x: 0, y: 3)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text(timeString(msg.date))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(red: 0.6, green: 0.72, blue: 0.78))
                .padding(.leading, 4)
        }
    }

    private func userBubble(_ msg: ChatMessage) -> some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text(msg.text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .lineSpacing(3)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent, accent2],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: accent.opacity(0.35), radius: 8, x: 0, y: 4)
                )

            Text(timeString(msg.date))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(red: 0.6, green: 0.72, blue: 0.78))
                .padding(.trailing, 4)
        }
    }

    // MARK: - Typing Bubble

    private var typingBubble: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(accent.opacity(0.6))
                    .frame(width: 7, height: 7)
                    .scaleEffect(vm.isSending ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: vm.isSending
                    )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.55)))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1))
                .shadow(color: accent.opacity(0.08), radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - Suggestions Bar

    private var suggestionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions(), id: \.self) { text in
                    Button {
                        vm.inputText = text
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        sendPressed()
                    } label: {
                        Text(text)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(Capsule().fill(Color.white.opacity(0.5)))
                                    .overlay(Capsule().strokeBorder(accent.opacity(0.2), lineWidth: 1))
                                    .shadow(color: accent.opacity(0.08), radius: 4, x: 0, y: 2)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Liquid Input Bar

    private var liquidInputBar: some View {
        HStack(spacing: 12) {
            // Text field
            HStack(spacing: 10) {
                Image(systemName: "message")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accent.opacity(0.7))

                TextField(localizedKey("type_message_placeholder"), text: $vm.inputText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit { sendPressed() }

                if !vm.inputText.isEmpty {
                    Button { vm.inputText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(red: 0.7, green: 0.8, blue: 0.85))
                            .font(.system(size: 16))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.6)))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            inputFocused ? accent.opacity(0.4) : Color.white.opacity(0.7),
                            lineWidth: inputFocused ? 1.5 : 1
                        ))
                    .shadow(color: inputFocused ? accent.opacity(0.15) : .clear, radius: 8, x: 0, y: 0)
                    .animation(.easeInOut(duration: 0.2), value: inputFocused)
            )

            // Send button
            Button { sendPressed() } label: {
                ZStack {
                    Circle()
                        .fill(
                            vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? LinearGradient(colors: [Color(red: 0.85, green: 0.92, blue: 0.97),
                                                       Color(red: 0.85, green: 0.92, blue: 0.97)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [accent, accent2],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 44, height: 44)
                        .shadow(
                            color: vm.inputText.isEmpty ? .clear : accent.opacity(0.4),
                            radius: 8, x: 0, y: 4
                        )
                        .animation(.easeInOut(duration: 0.2), value: vm.inputText.isEmpty)

                    if vm.isSending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(
                                vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color(red: 0.6, green: 0.72, blue: 0.78)
                                : .white
                            )
                            .rotationEffect(.degrees(45))
                            .animation(.easeInOut(duration: 0.2), value: vm.inputText.isEmpty)
                    }
                }
            }
            .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isSending)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Rectangle().fill(Color.white.opacity(0.4)))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(accent.opacity(0.1))
                        .frame(height: 0.5)
                }
        )
    }

    // MARK: - Helpers

    private func sendPressed() {
        guard !vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation { vm.send() }
        inputFocused = false
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        fmt.dateStyle = .none
        return fmt.string(from: date)
    }

    private func suggestions() -> [String] {
        switch lang.currentLanguage {
        case .kk: return ["Бас ауруы", "Ұйқы кеңесі", "Пульс дегеніміз не?", "Дәрумендер"]
        case .ru: return ["Болит голова", "Советы по сну", "Что значит пульс?", "Витамины"]
        case .en: return ["I have headache", "Sleep tips", "What's my pulse?", "Vitamins"]
        }
    }

    private func localizedKey(_ key: String) -> String {
        switch key {
        case "assistant":
            switch lang.currentLanguage { case .kk: return "Ассистент"; case .ru: return "Багыт ИИ"; case .en: return "Bagyt AI" }
        case "type_message_placeholder":
            switch lang.currentLanguage { case .kk: return "Жазып жіберіңіз..."; case .ru: return "Напишите сообщение..."; case .en: return "Type a message..." }
        default: return key
        }
    }
}

// MARK: - AssistantInfoView (улучшенный)

struct AssistantInfoView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    private let accent  = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.87, green: 0.95, blue: 1.0), Color(red: 0.93, green: 0.97, blue: 1.0)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                // Lottie orb большой
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [accent.opacity(0.12), accent2.opacity(0.06)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 160, height: 160)
                    LottieView(animationName: "aiaia")
                        .frame(width: 160, height: 160)
                        .clipShape(Circle())
                        .shadow(color: accent.opacity(0.25), radius: 20, x: 0, y: 8)
                }
                .padding(.top, 20)

                VStack(spacing: 8) {
                    Text("Bagyt ИИ-ассистент")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))

                    HStack(spacing: 5) {
                        Circle().fill(Color(red: 0.1, green: 0.78, blue: 0.48)).frame(width: 8, height: 8)
                        Text("Онлайн · Готов помочь")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(red: 0.1, green: 0.78, blue: 0.48))
                    }
                }

                // Features
                VStack(spacing: 12) {
                    featureRow(icon: "cross.circle.fill",   color: Color(red: 1, green: 0.35, blue: 0.35),
                               text: "Анализ симптомов и советы")
                    featureRow(icon: "heart.text.square.fill", color: accent,
                               text: "Интерпретация медицинских данных")
                    featureRow(icon: "moon.stars.fill",     color: Color(red: 0.55, green: 0.35, blue: 1),
                               text: "Рекомендации по сну и восстановлению")
                    featureRow(icon: "leaf.fill",           color: Color(red: 0.1, green: 0.78, blue: 0.48),
                               text: "Советы по питанию и образу жизни")
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.75))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(accent.opacity(0.1), lineWidth: 1))
                )
                .padding(.horizontal, 24)

                Text("⚠️ Не заменяет консультацию врача")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.6, green: 0.72, blue: 0.78))

                Button { dismiss() } label: {
                    Text("Начать общение")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: accent.opacity(0.35), radius: 12, x: 0, y: 6)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    ChatView()
        .environmentObject(AppState())
        .environmentObject(LanguageManager())
}
