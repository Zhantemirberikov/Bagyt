//
//  ChatView.swift
//  Bagyt
//
//  Created by Жантemир Бериков on 21.11.2025.
//  Updated: assistant avatar, keyboard handling, improved bubbles
//

import SwiftUI
import Combine
import UIKit

// MARK: - ViewModel
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isSending = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        load()
    }

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

        // simulate assistant reply (async)
        ChatService.shared.sendMessageToAI(userText: trimmed) { [weak self] reply in
            guard let self = self else { return }
            
            self.messages.append(reply)
            ChatService.shared.saveMessages(self.messages)
            
            withAnimation {
                self.isSending = false
            }
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

    @StateObject private var vm = ChatViewModel()
    @StateObject private var keyboard = KeyboardObserver()

    @FocusState private var inputFocused: Bool
    @State private var showAssistantInfo = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal)
                .padding(.top, 12)

            Divider().padding(.vertical, 6)

            // Messages + tap to dismiss keyboard
            messagesList
                .onTapGesture {
                    inputFocused = false
                }

            // Input
            inputArea
                .padding(.horizontal)
                // двигаем input на высоту клавиатуры (с учётом safe area)
                .padding(.bottom, keyboard.keyboardHeight)
                .animation(.easeOut(duration: 0.22), value: keyboard.keyboardHeight)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.load() }
        .sheet(isPresented: $showAssistantInfo) {
            AssistantInfoView()
                .environmentObject(appState)
                .environmentObject(lang)
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 12) {
            Button(action: {
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.impactOccurred()
                showAssistantInfo.toggle()
            }) {
                // Lottie avatar — use your LottieView file and animation name
                LottieView(animationName: "aiaia")
                    .frame(width: 54, height: 54)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.primary.opacity(0.06), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(localized("assistant"))
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(localizedSubtitle())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                vm.clearHistory()
                let gen = UINotificationFeedbackGenerator()
                gen.notificationOccurred(.success)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.primary)
            }
            .help("Clear chat")
        }
    }

    // MARK: - Messages list
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.messages) { msg in
                        bubbleRow(msg: msg)
                            .id(msg.id)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical, 10)
            }
            .onChange(of: vm.messages) { _ in
                // scroll to last message when messages change
                if let last = vm.messages.last {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeOut) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            .onChange(of: keyboard.keyboardHeight) { _ in
                // when keyboard opens, scroll to bottom
                if let last = vm.messages.last {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeOut) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Input area
    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField(localized("type_message_placeholder"), text: $vm.inputText)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground).opacity(0.02))
                .cornerRadius(10)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit { sendPressed() }

            if vm.isSending {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(width: 36, height: 36)
            } else {
                Button(action: sendPressed) {
                    Image(systemName: "paperplane.fill")
                        .rotationEffect(.degrees(45))
                        .font(.system(size: 20))
                        .frame(width: 40, height: 40)
                }
                .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
    }

    private func sendPressed() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
        vm.send()
        inputFocused = false
    }

    // MARK: - Bubble row
    @ViewBuilder
    private func bubbleRow(msg: ChatMessage) -> some View {
        HStack {
            if msg.sender == .assistant {
                // assistant bubble left
                VStack(alignment: .leading, spacing: 6) {
                    Text(msg.text)
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(14)
                    Text(dateString(msg.date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(msg.text)
                        .padding(12)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.blue, Color("AccentColorBlue").opacity(0.9)]),
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    Text(dateString(msg.date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers
    private func dateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        fmt.dateStyle = .none
        return fmt.string(from: date)
    }

    private func localized(_ key: String) -> String {
        switch key {
        case "assistant":
            switch lang.currentLanguage {
            case .kk: return "Ассистент"
            case .ru: return "Ассистент"
            case .en: return "Assistant"
            }
        case "type_message_placeholder":
            switch lang.currentLanguage {
            case .kk: return "Жазып жіберіңіз..."
            case .ru: return "Напишите сообщение..."
            case .en: return "Type a message..."
            }
        default:
            return key
        }
    }

    private func localizedSubtitle() -> String {
        if vm.isSending { return "Thinking..." }
        return "Assistant (simulated)"
    }

    // safe area bottom — robust scene-based approach
    private func safeAreaBottom() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        if let window = scenes.first?.windows.first(where: \.isKeyWindow) {
            return window.safeAreaInsets.bottom
        }
        return 0
    }
}

// MARK: - Assistant Info sheet (simple)
struct AssistantInfoView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        VStack(spacing: 18) {
            LottieView(animationName: "aiaia")
                .frame(width: 180, height: 180)

            Text("Bagyt Assistant")
                .font(.title2)
                .fontWeight(.bold)

            Text("AI help coming soon — here will be tips, 3D avatar and more.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            Spacer()
        }
        .padding()
    }
}
