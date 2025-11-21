import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lang: LanguageManager

    @State private var pulse = false

    var body: some View {
        ZStack {
            // 🔹 Фон в том же стиле, что и LoginView
            AnimatedGradientBackground()

            VStack(spacing: 20) {
                // Верхняя панель
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        // ✅ Персональное приветствие
                        if let name = appState.userName, !name.isEmpty {
                            Text("\(localized("welcome_back")), \(name) 👋")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        } else {
                            Text(localized("welcome"))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }

                        Text(localized("subtitle"))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()

                    // "Пульсирующее сердце" как элемент бренда
                    Image(systemName: "heart.fill")
                        .foregroundColor(.white.opacity(0.8))
                        .scaleEffect(pulse ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                        .onAppear { pulse.toggle() }
                }
                .padding(.horizontal)

                Spacer().frame(height: 20)

                // Карточки
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        GlassCard(
                            title: localized("ai_recommendations"),
                            subtitle: localized("ai_text"),
                            icon: "brain.head.profile"
                        )

                        GlassCard(
                            title: localized("health_metrics"),
                            subtitle: localized("metrics_text"),
                            icon: "waveform.path.ecg"
                        )

                        GlassCard(
                            title: localized("daily_mood"),
                            subtitle: localized("mood_text"),
                            icon: "face.smiling"
                        )

                        GlassCard(
                            title: localized("settings"),
                            subtitle: localized("settings_text"),
                            icon: "gearshape.fill"
                        )
                    }
                    .padding(.horizontal)
                }

                Spacer()

                // Кнопка выхода
                Button(action: {
                    withAnimation {
                        appState.logOut()
                    }
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text(localized("logout"))
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(14)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 20)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Localized Texts
    private func localized(_ key: String) -> String {
        switch key {
        case "welcome":
            switch lang.currentLanguage {
            case .kk: return "Қош келдіңіз!"
            case .ru: return "Добро пожаловать!"
            case .en: return "Welcome!"
            }
        case "welcome_back":
            switch lang.currentLanguage {
            case .kk: return "Қайта оралдыңыз"
            case .ru: return "С возвращением"
            case .en: return "Welcome back"
            }
        case "subtitle":
            switch lang.currentLanguage {
            case .kk: return "AI серіктесіңіз дайын 🩺"
            case .ru: return "Ваш AI-помощник готов 🩺"
            case .en: return "Your AI assistant is ready 🩺"
            }
        case "ai_recommendations":
            switch lang.currentLanguage {
            case .kk: return "AI кеңестері"
            case .ru: return "AI рекомендации"
            case .en: return "AI Recommendations"
            }
        case "ai_text":
            switch lang.currentLanguage {
            case .kk: return "Жеке талдау және пайдалы кеңестер"
            case .ru: return "Персональный анализ и советы"
            case .en: return "Personal insights and useful tips"
            }
        case "health_metrics":
            switch lang.currentLanguage {
            case .kk: return "Денсаулық көрсеткіштері"
            case .ru: return "Показатели здоровья"
            case .en: return "Health Metrics"
            }
        case "metrics_text":
            switch lang.currentLanguage {
            case .kk: return "Күнделікті бақылау және деректер"
            case .ru: return "Ежедневные данные и мониторинг"
            case .en: return "Daily tracking and stats"
            }
        case "daily_mood":
            switch lang.currentLanguage {
            case .kk: return "Күн сайынғы көңіл-күй"
            case .ru: return "Ежедневное настроение"
            case .en: return "Daily Mood"
            }
        case "mood_text":
            switch lang.currentLanguage {
            case .kk: return "AI көмегімен өзіңізді жақсырақ түсініңіз"
            case .ru: return "Понимайте себя с помощью AI"
            case .en: return "Understand yourself better with AI"
            }
        case "settings":
            switch lang.currentLanguage {
            case .kk: return "Параметрлер"
            case .ru: return "Настройки"
            case .en: return "Settings"
            }
        case "settings_text":
            switch lang.currentLanguage {
            case .kk: return "Қолданба опциялары және профиль"
            case .ru: return "Опции приложения и профиль"
            case .en: return "App options and profile"
            }
        case "logout":
            switch lang.currentLanguage {
            case .kk: return "Шығу"
            case .ru: return "Выйти"
            case .en: return "Log out"
            }
        default:
            return ""
        }
    }
}

// MARK: - Вспомогательный компонент карточки
struct GlassCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.trailing, 6)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
            }
            .padding()
        }
        .background(
            Color.white.opacity(0.15)
                .blur(radius: 20)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}
