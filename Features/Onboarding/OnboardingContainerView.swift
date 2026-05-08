//
//  OnboardingContainerView.swift
//  Bagyt
//

import SwiftUI

struct OnboardingContainerView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lang: LanguageManager

    @State private var currentPage        = 0
    @State private var animateHeart       = false
    @State private var showLanguagePicker = false
    @State private var particlesTick      = false
    @State private var btnPulse           = false
    @State private var bgAnimate          = false
    @StateObject private var motion       = MotionManager()
    @State private var completedProfileOnboardingToken: String?

    // Цвета фона для каждого слайда
    private let slideColors: [(Color, Color)] = [
        (Color(red: 0.055, green: 0.647, blue: 0.914), Color(red: 0.024, green: 0.714, blue: 0.831)),
        (Color(red: 0.45,  green: 0.25,  blue: 0.95),  Color(red: 0.20,  green: 0.45,  blue: 1.00)),
        (Color(red: 0.055, green: 0.647, blue: 0.914), Color(red: 0.024, green: 0.714, blue: 0.831)),
    ]

    private let accent  = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)

    private let pages = [
        OnboardingPage(
            imageName: "record",
            title: [
                .kk: "Сіздің денсаулық деректеріңіз — қауіпсіз жерде",
                .ru: "Ваши медицинские данные в безопасности",
                .en: "Your health data is safe"
            ],
            description: [
                .kk: "Біз сіздің медициналық жазбаларыңызды қауіпсіз және ыңғайлы сақтауға көмектесеміз.",
                .ru: "Мы помогаем хранить ваши медицинские записи безопасно и удобно.",
                .en: "We help you store your medical records safely and conveniently."
            ]
        ),
        OnboardingPage(
            imageName: "safe",
            title: [
                .kk: "AI сіздің әл-ауқатыңызды қолдайды",
                .ru: "AI поддерживает ваше благополучие",
                .en: "AI supports your wellbeing"
            ],
            description: [
                .kk: "Bagyt қолданбасы сіздің көңіл-күйіңіз бен денсаулығыңызды бақылауға көмектеседі.",
                .ru: "Bagyt помогает отслеживать настроение и состояние здоровья.",
                .en: "Bagyt helps you track your mood and health state."
            ]
        ),
        OnboardingPage(
            imageName: "docs",
            title: [
                .kk: "Барлығы бір жерде",
                .ru: "Всё в одном месте",
                .en: "Everything in one place"
            ],
            description: [
                .kk: "Сіздің деректеріңіз, жазбаларыңыз және ұсыныстарыңыз бір қосымшада сақталады.",
                .ru: "Ваши данные, записи и рекомендации хранятся в одном приложении.",
                .en: "Your data, notes, and recommendations are stored in one app."
            ]
        )
    ]

    // Текущие цвета фона (с анимацией при смене слайда)
    private var currentBg: (Color, Color) {
        guard currentPage < slideColors.count else {
            return (accent, accent2)
        }
        return slideColors[currentPage]
    }
    
    private var hasCompletedProfile: Bool {
        let key = "hasCompletedProfileOnboarding_\(appState.userToken ?? "guest")"
        return UserDefaults.standard.bool(forKey: key)
    }

    private var hasJustCompletedProfile: Bool {
        completedProfileOnboardingToken == (appState.userToken ?? "guest")
    }

    var body: some View {
        ZStack {
            // Анимированный фон — меняет цвет со слайдом
            animatedBackground

            if appState.isLoggedIn {
                if !hasCompletedProfile && !hasJustCompletedProfile {
                    ProfileOnboardingView(userName: appState.userName ?? "Друг") {
                        let key = "hasCompletedProfileOnboarding_\(appState.userToken ?? "guest")"
                        UserDefaults.standard.set(true, forKey: key)

                        withAnimation(.easeInOut(duration: 0.35)) {
                            completedProfileOnboardingToken = appState.userToken ?? "guest"
                        }
                    }
                    .environmentObject(appState)
                    .environmentObject(lang)
                    .transition(.opacity.combined(with: .scale))
                } else {
                    HomeView()
                        .environmentObject(appState)
                        .environmentObject(lang)
                        .transition(.opacity.combined(with: .scale))
                }

            } else {
                onboardingContent
            }
        }
        .animation(.easeInOut(duration: 0.35), value: appState.isLoggedIn)
        .onChange(of: appState.userToken) { _ in
            completedProfileOnboardingToken = nil
        }
        .onChange(of: appState.isLoggedIn) { isLoggedIn in
            if !isLoggedIn {
                completedProfileOnboardingToken = nil
            }
        }
    }

    // MARK: - Animated Background

    private var animatedBackground: some View {
        ZStack {
            // Основной градиент — меняется со слайдом
            LinearGradient(
                colors: [currentBg.0, currentBg.1],
                startPoint: bgAnimate ? .topLeading : .bottomTrailing,
                endPoint:   bgAnimate ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.7), value: currentPage)
            .animation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true), value: bgAnimate)

            // Большой размытый блоб 1
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(
                    x: bgAnimate ? -60 : 60,
                    y: bgAnimate ? -120 : -60
                )
                .animation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true), value: bgAnimate)

            // Блоб 2
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 50)
                .offset(
                    x: bgAnimate ? 80 : -40,
                    y: bgAnimate ? 200 : 300
                )
                .animation(.easeInOut(duration: 7.0).repeatForever(autoreverses: true), value: bgAnimate)

            // Блоб 3 — маленький яркий
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 140, height: 140)
                .blur(radius: 30)
                .offset(
                    x: bgAnimate ? 100 : -80,
                    y: bgAnimate ? 400 : 500
                )
                .animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: bgAnimate)
        }
        .ignoresSafeArea()
    }

    // MARK: - Onboarding Content

    private var onboardingContent: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar.padding(.top, 10)

                Spacer()

                ZStack {
                    TabView(selection: $currentPage) {
                        ForEach(0..<pages.count, id: \.self) { i in
                            slideView(index: i).tag(i)
                        }
                        LoginView(showBackground: false, showHeader: false)
                            .environmentObject(appState)
                            .environmentObject(lang)
                            .tag(pages.count)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .transaction { $0.animation = nil }
                    .animation(.easeInOut(duration: 0.28), value: currentPage)

                    // Dots + орб-кнопка
                    if currentPage < pages.count {
                        VStack {
                            Spacer()
                            HStack {
                                // Dots
                                HStack(spacing: 8) {
                                    ForEach(0..<pages.count, id: \.self) { i in
                                        Capsule()
                                            .fill(i == currentPage
                                                  ? Color.white
                                                  : Color.white.opacity(0.35))
                                            .frame(width: i == currentPage ? 22 : 7, height: 7)
                                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
                                    }
                                }
                                .padding(.leading, 32)

                                Spacer()

                                // Живой орб-кнопка
                                liveOrbButton
                                    .padding(.trailing, 24)
                            }
                            .padding(.bottom, 40)
                        }
                        .transition(.opacity)
                    }
                }

                Spacer(minLength: 0)
            }

            // Языковой попап
            if showLanguagePicker {
                languagePopup
            }
        }
        .onAppear {
            animateHeart = true
            bgAnimate = true
            HeartbeatHaptics.shared.start()
            withAnimation { btnPulse = true }
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                particlesTick.toggle()
            }
        }
        .onChange(of: currentPage) { page in
            if page >= pages.count {
                HeartbeatHaptics.shared.stop()
            } else {
                HeartbeatHaptics.shared.start()
            }
        }
        .onChange(of: appState.isLoggedIn) { loggedIn in
            if loggedIn { HeartbeatHaptics.shared.stop() }
        }
    }

    // MARK: - Live Orb Button (зовёт нажать)

    private var liveOrbButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.linear(duration: 0.12)) { currentPage += 1 }
        } label: {
            ZStack {
                // Внешнее кольцо 3 — самое тихое
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    .frame(width: 82, height: 82)
                    .scaleEffect(btnPulse ? 1.45 : 1.0)
                    .opacity(btnPulse ? 0.0 : 0.8)
                    .animation(
                        .easeOut(duration: 1.6)
                            .repeatForever(autoreverses: false)
                            .delay(0.4),
                        value: btnPulse
                    )

                // Внешнее кольцо 2
                Circle()
                    .stroke(Color.white.opacity(0.20), lineWidth: 1.5)
                    .frame(width: 70, height: 70)
                    .scaleEffect(btnPulse ? 1.35 : 1.0)
                    .opacity(btnPulse ? 0.0 : 1.0)
                    .animation(
                        .easeOut(duration: 1.6)
                            .repeatForever(autoreverses: false)
                            .delay(0.2),
                        value: btnPulse
                    )

                // Внешнее кольцо 1
                Circle()
                    .stroke(Color.white.opacity(0.30), lineWidth: 2)
                    .frame(width: 60, height: 60)
                    .scaleEffect(btnPulse ? 1.25 : 1.0)
                    .opacity(btnPulse ? 0.0 : 1.0)
                    .animation(
                        .easeOut(duration: 1.6)
                            .repeatForever(autoreverses: false),
                        value: btnPulse
                    )

                // Основной круг с blur-эффектом
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 54, height: 54)
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(0.25))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.55), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)

                // Иконка стрелки
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            HStack(spacing: 4) {
                Text("Bagyt")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.1), radius: 2)
                Image(systemName: "heart.fill")
                    .foregroundColor(Color.white.opacity(0.9))
                    .font(.system(size: 15))
                    .scaleEffect(animateHeart ? 1.28 : 0.88)
                    .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: animateHeart)
                    .offset(y: -2)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                    showLanguagePicker.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(lang.currentLanguage.flag).font(.system(size: 15))
                    Text(lang.currentLanguage.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Image(systemName: showLanguagePicker ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 13)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.20))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.40), lineWidth: 1))
                )
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Language Popup

    private var languagePopup: some View {
        VStack {
            HStack {
                Spacer()
                VStack(spacing: 0) {
                    ForEach(Array(AppLanguage.allCases.enumerated()), id: \.1) { idx, code in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                lang.changeLanguage(to: code)
                                showLanguagePicker = false
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: 10) {
                                Text(code.flag).font(.system(size: 18))
                                Text(code.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                                Spacer()
                                if lang.currentLanguage == code {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(accent)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 13)
                            .background(
                                lang.currentLanguage == code ? accent.opacity(0.07) : Color.clear
                            )
                        }
                        if idx < AppLanguage.allCases.count - 1 {
                            Divider().padding(.horizontal, 14).opacity(0.4)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.85)))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.9), lineWidth: 1))
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
                )
                .frame(width: 200)
                .padding(.trailing, 24)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.85, anchor: .topTrailing).combined(with: .opacity),
                    removal:   .scale(scale: 0.85, anchor: .topTrailing).combined(with: .opacity)
                ))
            }
            .padding(.top, 68)
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) { showLanguagePicker = false }
        }
    }

    // MARK: - Slide View

    private func slideView(index: Int) -> some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                // Блоб под картинкой
                Ellipse()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 260, height: 140)
                    .blur(radius: 35)
                    .scaleEffect(particlesTick ? 1.12 : 0.90)
                    .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: particlesTick)

                // Тень
                Ellipse()
                    .fill(Color.black.opacity(0.10))
                    .frame(width: 180, height: 22)
                    .blur(radius: 10)
                    .offset(y: 108)

                // Картинка + параллакс
                Image(pages[index].imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 230)
                    .rotation3DEffect(.degrees(motion.pitch * 18), axis: (x: 1, y: 0, z: 0))
                    .rotation3DEffect(.degrees(motion.roll * 18), axis: (x: 0, y: -1, z: 0))
                    .offset(x: CGFloat(motion.roll * 42), y: CGFloat(motion.pitch * 26))
                    .shadow(color: .black.opacity(0.18), radius: 28,
                            x: CGFloat(motion.roll * 18), y: CGFloat(motion.pitch * 12))
                    .animation(.easeOut(duration: 0.12), value: motion.pitch)
                    .animation(.easeOut(duration: 0.12), value: motion.roll)
            }
            .frame(height: 270)

            Spacer().frame(height: 36)

            // Текст — белый на цветном фоне
            VStack(spacing: 14) {
                // Тег
                HStack(spacing: 6) {
                    Image(systemName: index == 0 ? "lock.shield.fill"
                                    : index == 1 ? "sparkles"
                                    : "square.stack.3d.up.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    Text(index == 0
                         ? tagLabel(kk: "Қауіпсіздік",       ru: "Безопасность",            en: "Security")
                         : index == 1
                         ? tagLabel(kk: "Жасанды интеллект",  ru: "Искусственный интеллект", en: "AI")
                         : tagLabel(kk: "Барлығы",             ru: "Всё в одном",             en: "All in one"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .tracking(0.3)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.20))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.40), lineWidth: 1))
                )

                // Заголовок
                Text(pages[index].title[lang.currentLanguage] ?? "")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .shadow(color: .black.opacity(0.08), radius: 4)

                // Описание
                Text(pages[index].description[lang.currentLanguage] ?? "")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer().frame(height: 80)
        }
    }

    private func tagLabel(kk: String, ru: String, en: String) -> String {
        switch lang.currentLanguage {
        case .kk: return kk
        case .ru: return ru
        case .en: return en
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingContainerView()
        .environmentObject(AppState())
        .environmentObject(LanguageManager())
}
