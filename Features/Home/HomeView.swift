//
//  HomeView.swift
//  Bagyt — orb теперь открывает Ассистента (sheet), Журнал остаётся вкладкой

import SwiftUI
import Combine
import UIKit // для haptic

// MARK: - HomeView
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lang: LanguageManager

    @State private var selectedTab: Int = 0
    @State private var pulse = false
    @State private var showProfileSheet = false

    // sheet for Assistant
    @State private var showAssistantSheet = false

    // keyboard observer
    @StateObject private var keyboard = KeyboardObserver()

    // orb motion states
    @State private var orbOffset: CGSize = .zero
    @State private var orbIsPressed = false

    var body: some View {
        ZStack {
            AnimatedGradientBackground()

            VStack(spacing: 0) {
                // Top bar
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(greetingText())
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Text(localized("subtitle"))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Spacer()

                    Button(action: { showProfileSheet.toggle() }) {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 46, height: 46)
                            .overlay(Text(initials(for: appState.userName)).font(.headline).foregroundColor(.white))
                            .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                    }
                    .sheet(isPresented: $showProfileSheet) {
                        SettingsView()
                            .environmentObject(appState)
                            .environmentObject(lang)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)

                Spacer(minLength: 8)

                // Main content
                ZStack {
                    switch selectedTab {
                    case 0: homeContent
                    case 1: JournalView().environmentObject(appState).environmentObject(lang)
                    case 2: HealthMetricsView()
                    case 3: SettingsView().environmentObject(appState).environmentObject(lang)
                    default: homeContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom area (tabbar + orb). Смещение на высоту клавиатуры.
                bottomBar
                    .padding(.bottom, keyboard.keyboardHeight)
                    .animation(.easeOut(duration: 0.25), value: keyboard.keyboardHeight)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarHidden(true)
        .onAppear { pulse = true }
        // Assistant sheet (opened by orb)
        .sheet(isPresented: $showAssistantSheet) {
            ChatView()
                .environmentObject(appState)
                .environmentObject(lang)
        }
    }

    // MARK: - Bottom bar + orb
    private var bottomBar: some View {
        ZStack {
            // blurred container
            HStack { Spacer() }
                .frame(height: 78)
                .background(VisualEffectBlur(blurStyle: .systemUltraThinMaterial))
                .cornerRadius(20)
                .padding(.horizontal, 12)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -4)

            // normal tab icons
            HStack {
                tabButton(icon: "house.fill", label: localized("home"), index: 0)
                Spacer()
                tabButton(icon: "book.fill", label: localized("journal"), index: 1)
                Spacer(minLength: 72)
                tabButton(icon: "waveform.path.ecg", label: localized("metrics"), index: 2)
                Spacer()
                tabButton(icon: "gearshape.fill", label: localized("profile"), index: 3)
            }
            .padding(.horizontal, 34)
            .frame(height: 78)
            .padding(.bottom, 6)

            // central orb — теперь открывает ассистента как sheet
            orbView
                .offset(y: -36)
                .zIndex(2)
                .allowsHitTesting(true)
                .accessibilityLabel("AI Orb")
        }
        .padding(.bottom, 6)
    }

    // Orb view with Lottie, drag, haptic
    private var orbView: some View {
        ZStack {
            // invisible button layer to handle tap
            Button(action: {
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.impactOccurred()
                withAnimation(.spring()) {
                    showAssistantSheet = true
                }
            }) {
                LottieView(animationName: "aiaia")
                    .frame(width: 92, height: 92)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 0))
                    .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
                    .scaleEffect(orbIsPressed ? 0.95 : (pulse ? 1.04 : 0.98))
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    orbOffset = CGSize(width: value.translation.width * 0.22,
                                       height: value.translation.height * 0.22)
                    orbIsPressed = true
                }
                .onEnded { _ in
                    let g = UIImpactFeedbackGenerator(style: .light)
                    g.impactOccurred()
                    withAnimation(.interpolatingSpring(stiffness: 180, damping: 18)) {
                        orbOffset = .zero
                        orbIsPressed = false
                    }
                }
            )
        }
        .offset(x: orbOffset.width, y: orbOffset.height)
    }

    // MARK: - Home content
    private var homeContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                topWelcomeCard

                NavigationLink(destination: JournalView().environmentObject(appState).environmentObject(lang)) {
                    GlassCard(title: localized("ai_recommendations"), subtitle: localized("ai_text"), icon: "brain.head.profile")
                        .padding(.horizontal)
                }

                NavigationLink(destination: HealthMetricsView()) {
                    GlassCard(title: localized("health_metrics"), subtitle: localized("metrics_text"), icon: "waveform.path.ecg", accentColor: Color.green)
                        .padding(.horizontal)
                }

                NavigationLink(destination: MoodView()) {
                    GlassCard(title: localized("daily_mood"), subtitle: localized("mood_text"), icon: "face.smiling", accentColor: Color.purple)
                        .padding(.horizontal)
                }

                Spacer(minLength: 120)
            }
            .padding(.top, 10)
        }
    }

    private var topWelcomeCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("ai_recommendations"))
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(localized("ai_text"))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                Circle()
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.mint]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                    .overlay(Image(systemName: "sparkles").foregroundColor(.white))
            }
            .padding()
        }
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
        .padding(.horizontal)
    }

    // MARK: - Helpers
    private func tabButton(icon: String, label: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.spring()) { selectedTab = index }
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(selectedTab == index ? .white : .white.opacity(0.6))
                Text(label)
                    .font(.caption2)
                    .foregroundColor(selectedTab == index ? .white : .white.opacity(0.6))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
        }
    }

    private func greetingText() -> String {
        if let name = appState.userName, !name.isEmpty {
            return "\(localized("welcome_back")), \(name)"
        } else {
            return localized("welcome")
        }
    }

    private func displayName() -> String {
        if let name = appState.userName, !name.isEmpty { return name }
        if let token = appState.userToken, !token.isEmpty {
            return "User \(String(token.suffix(4)))"
        }
        return "User"
    }

    private func displaySecondary() -> String {
        if let token = appState.userToken, !token.isEmpty {
            return "ID:\(String(token.prefix(6)))"
        }
        return ""
    }

    private func initials(for name: String?) -> String {
        let source = (name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? name! : "U"
        let parts = source.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }.map(String.init)
        return (letters.joined().uppercased())
    }

    private func localized(_ key: String) -> String {
        switch key {
        case "welcome":
            switch lang.currentLanguage { case .kk: return "Қош келдіңіз!"; case .ru: return "Добро пожаловать!"; default: return "Welcome!" }
        case "journal": return ["kk":"Журнал","ru":"Журнал","en":"Journal"][lang.currentLanguage.rawValue] ?? "Journal"
        case "home": return ["kk": "Басты", "ru": "Главная", "en": "Home"][lang.currentLanguage.rawValue] ?? "Home"
        case "assistant": return ["kk": "Көмекші", "ru": "Ассистент", "en": "Assistant"][lang.currentLanguage.rawValue] ?? "Assistant"
        case "subtitle":
            switch lang.currentLanguage { case .kk: return "AI серіктесіңіз дайын 🩺"; case .ru: return "Ваш AI-помощник готов 🩺"; default: return "Your AI assistant is ready 🩺" }
        case "ai_recommendations":
            switch lang.currentLanguage { case .kk: return "AI кеңестері"; case .ru: return "AI рекомендации"; default: return "AI Recommendations" }
        case "ai_text":
            switch lang.currentLanguage { case .kk: return "Жеке талдау және пайдалы кеңестер"; case .ru: return "Персональный анализ и советы"; default: return "Personal insights and useful tips" }
        case "health_metrics":
            switch lang.currentLanguage { case .kk: return "Денсаулық көрсеткіштері"; case .ru: return "Показатели здоровья"; default: return "Health Metrics" }
        case "metrics_text":
            switch lang.currentLanguage { case .kk: return "Күнделікті бақылау және деректер"; case .ru: return "Ежедневные данные и мониторинг"; default: return "Daily tracking and stats" }
        case "daily_mood":
            switch lang.currentLanguage { case .kk: return "Күн сайынғы көңіл-күй"; case .ru: return "Ежедневное настроение"; default: return "Daily Mood" }
        case "mood_text":
            switch lang.currentLanguage { case .kk: return "AI көмегімен өзіңізді жақсырақ түсініңіз"; case .ru: return "Понимайте себя с помощью AI"; default: return "Understand yourself better with AI" }
        default: return key
        }
    }

    // safe area bottom
    private func safeAreaBottom() -> CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
    }
}
