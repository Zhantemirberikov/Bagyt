import SwiftUI
import AuthenticationServices

// MARK: - Анимированный фон с эффектом сердцебиения
struct AnimatedGradientBackground: View {
    @State private var moveGradient = false
    @State private var pulse = false

    var body: some View {
        // AccentColor с fallback
        let accentColor: Color = {
            if let ui = UIColor(named: "AccentColor") {
                return Color(uiColor: ui)
            } else {
                // fallback — тёплый медицинский оттенок
                return Color(red: 0.94, green: 0.96, blue: 1.0)
            }
        }()

        ZStack {
            // Основной плавный фон
            LinearGradient(
                gradient: Gradient(colors: [
                    accentColor.opacity(0.9),
                    Color.white.opacity(0.95),
                    accentColor.opacity(0.85)
                ]),
                startPoint: moveGradient ? .topLeading : .bottomTrailing,
                endPoint: moveGradient ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .animation(
                .easeInOut(duration: 8).repeatForever(autoreverses: true),
                value: moveGradient
            )

            // Пульсирующее свечение — эффект сердца
            RadialGradient(
                gradient: Gradient(colors: [
                    accentColor.opacity(pulse ? 0.35 : 0.15),
                    Color.clear
                ]),
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .blendMode(.softLight)
            .ignoresSafeArea()
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: pulse
            )
        }
        .onAppear {
            moveGradient.toggle()
            pulse.toggle()
        }
    }
}

// MARK: - Эффект стеклянной панели
struct GlassPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(
                Color.white.opacity(0.15)
                    .blur(radius: 20)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
    }
}

// MARK: - Основной экран логина
struct LoginView: View {
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var appState: AppState

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            // 🔹 Новый живой фон
            AnimatedGradientBackground()

            VStack(spacing: 30) {
                // Верхняя панель с языками
                HStack {
                    Text("Bagyt")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(radius: 3)
                        .overlay(
                            // Маленькое пульсирующее сердечко ❤️
                            Image(systemName: "heart.fill")
                                .foregroundColor(.white.opacity(0.8))
                                .scaleEffect(showPassword ? 1.2 : 1.0)
                                .animation(
                                    .easeInOut(duration: 0.8)
                                        .repeatForever(autoreverses: true),
                                    value: showPassword
                                )
                                .offset(x: 55, y: -5)
                        )

                    Spacer()

                    Menu {
                        ForEach(AppLanguage.allCases, id: \.self) { code in
                            Button {
                                withAnimation(.easeInOut) {
                                    lang.changeLanguage(to: code)
                                }
                            } label: {
                                Text("\(code.flag)  \(code.title)")
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(lang.currentLanguage.flag)
                            Text(lang.currentLanguage.title)
                                .font(.caption)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(.ultraThinMaterial.opacity(0.6))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)

                Spacer()

                // Описание
                Text(localized("subtitle"))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .shadow(radius: 2)

                // Glass-панель логина
                GlassPanel {
                    VStack(spacing: 14) {
                        TextField(localized("email_placeholder"), text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .foregroundColor(.white)

                        HStack {
                            if showPassword {
                                TextField(localized("password_placeholder"), text: $password)
                                    .textContentType(.password)
                            } else {
                                SecureField(localized("password_placeholder"), text: $password)
                            }
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)

                        if let err = errorMessage {
                            Text(err)
                                .foregroundColor(.red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }

                        Button {
                            inlineLogin()
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(localized("sign_email"))
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 30)

                // Разделитель
                HStack {
                    Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.2))
                    Text(localized("or"))
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                    Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.2))
                }
                .padding(.horizontal)

                // Кнопки соцсетей
                VStack(spacing: 12) {
                    Button(action: { print("Google tapped") }) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                            Text(localized("sign_google"))
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                        .shadow(radius: 3)
                    }
                    .padding(.horizontal)

                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        switch result {
                        case .success:
                            appState.isLoggedIn = true
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                Spacer()

                // Политика
                VStack(spacing: 6) {
                    Text("\(localized("policy_prefix")) \(localized("policy_link"))")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 10)
                }
                .padding(.horizontal)
            }
        }
        .onAppear { showPassword.toggle() } // запустить анимацию сердечка
    }

    // MARK: - Logic
    private func inlineLogin() {
        errorMessage = nil
        guard email.contains("@"), password.count >= 4 else {
            errorMessage = localized("login_validation")
            return
        }
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isLoading = false
            appState.isLoggedIn = true
        }
    }

    // MARK: - Localized text
    private func localized(_ key: String) -> String {
        switch key {
        case "subtitle":
            switch lang.currentLanguage {
            case .kk: return "Сіздің AI серіктесіңіз — денсаулық пен бақыт үшін"
            case .ru: return "Ваш AI-помощник для здоровья и счастья"
            case .en: return "Your AI companion for health and happiness"
            }
        case "email_placeholder": return ["kk": "Электрондық пошта", "ru": "Email", "en": "Email"][lang.currentLanguage.rawValue]!
        case "password_placeholder": return ["kk": "Құпия сөз", "ru": "Пароль", "en": "Password"][lang.currentLanguage.rawValue]!
        case "sign_email": return ["kk": "Пошта арқылы кіру", "ru": "Войти по Email", "en": "Continue with Email"][lang.currentLanguage.rawValue]!
        case "sign_google": return ["kk": "Google арқылы кіру", "ru": "Войти через Google", "en": "Sign in with Google"][lang.currentLanguage.rawValue]!
        case "or": return ["kk": "немесе", "ru": "или", "en": "or"][lang.currentLanguage.rawValue]!
        case "login_validation": return ["kk": "Электрондық пошта немесе пароль дұрыс емес", "ru": "Проверьте Email и пароль", "en": "Check email and password"][lang.currentLanguage.rawValue]!
        case "policy_prefix": return ["kk": "Жалғастырған кезде сіз қабылдайсыз", "ru": "Продолжая, вы соглашаетесь с", "en": "By continuing you accept the"][lang.currentLanguage.rawValue]!
        case "policy_link": return ["kk": "Құпиялылық саясаты", "ru": "Политику конфиденциальности", "en": "Privacy Policy"][lang.currentLanguage.rawValue]!
        default: return ""
        }
    }
}

#if DEBUG
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(LanguageManager())
            .environmentObject(AppState())
    }
}
#endif
