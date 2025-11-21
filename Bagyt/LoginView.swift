import SwiftUI
import AuthenticationServices

// MARK: - Анимированный фон с эффектом сердцебиения
struct AnimatedGradientBackground: View {
    @State private var moveGradient = false
    @State private var pulse = false

    var body: some View {
        let accentColor: Color = {
            if let ui = UIColor(named: "AccentColor") {
                return Color(uiColor: ui)
            } else {
                return Color(red: 0.94, green: 0.96, blue: 1.0)
            }
        }()

        ZStack {
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
            .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: moveGradient)

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
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
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

// MARK: - Основной экран логина/регистрации
struct LoginView: View {
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var appState: AppState

    var showBackground: Bool = true
    var showHeader: Bool = true

    @State private var name = ""                // ✅ добавлено поле имени
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isRegisterMode = false

    var body: some View {
        ZStack {
            if showBackground {
                AnimatedGradientBackground()
            }

            VStack(spacing: 30) {
                if showHeader {
                    HStack {
                        Text("Bagyt")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.black)
                            .shadow(radius: 3)
                            .overlay(
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.black.opacity(0.8))
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
                                        .foregroundColor(.black)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(lang.currentLanguage.flag)
                                Text(lang.currentLanguage.title)
                                    .font(.caption)
                                    .foregroundColor(.black)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(.ultraThinMaterial.opacity(0.6))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }

                Spacer()

                Text(isRegisterMode ? localized("register_subtitle") : localized("subtitle"))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .shadow(radius: 2)

                GlassPanel {
                    VStack(spacing: 14) {
                        // ✅ Name (только при регистрации)
                        if isRegisterMode {
                            TextField(localized("name_placeholder"), text: $name)
                                .textContentType(.name)
                                .padding()
                                .background(Color.black.opacity(0.05))
                                .cornerRadius(10)
                                .foregroundColor(.black)
                        }

                        // Email
                        TextField(localized("email_placeholder"), text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .padding()
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(10)
                            .foregroundColor(.black)

                        // Password
                        HStack {
                            if showPassword {
                                TextField(localized("password_placeholder"), text: $password)
                                    .textContentType(.password)
                            } else {
                                SecureField(localized("password_placeholder"), text: $password)
                            }
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.black.opacity(0.7))
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(10)

                        // ✅ Confirm Password (только при регистрации)
                        if isRegisterMode {
                            HStack {
                                if showPassword {
                                    TextField(localized("confirm_password_placeholder"), text: $confirmPassword)
                                        .textContentType(.password)
                                } else {
                                    SecureField(localized("confirm_password_placeholder"), text: $confirmPassword)
                                }
                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.black.opacity(0.7))
                                }
                            }
                            .padding()
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(10)
                        }

                        if let err = errorMessage {
                            Text(err)
                                .foregroundColor(.red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }

                        // Кнопка логина/регистрации
                        Button {
                            if isRegisterMode {
                                inlineRegister()
                            } else {
                                inlineLogin()
                            }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                }
                                Text(isRegisterMode ? localized("sign_up_email") : localized("sign_email"))
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black.opacity(0.1))
                            .cornerRadius(10)
                            .foregroundColor(.black)
                        }
                        .padding(.top, 8)

                        Button(action: {
                            withAnimation {
                                isRegisterMode.toggle()
                                errorMessage = nil
                                name = ""
                                confirmPassword = ""
                            }
                        }) {
                            Text(isRegisterMode ? localized("already_have_account") : localized("no_account"))
                                .font(.footnote)
                                .foregroundColor(.black.opacity(0.8))
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 30)

                if !isRegisterMode {
                    HStack {
                        Rectangle().frame(height: 1).foregroundColor(.black.opacity(0.2))
                        Text(localized("or"))
                            .foregroundColor(.black.opacity(0.8))
                            .font(.caption)
                        Rectangle().frame(height: 1).foregroundColor(.black.opacity(0.2))
                    }
                    .padding(.horizontal)

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
                }

                Spacer()

                VStack(spacing: 6) {
                    Text("\(localized("policy_prefix")) \(localized("policy_link"))")
                        .font(.footnote)
                        .foregroundColor(.black.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 10)
                }
                .padding(.horizontal)
            }
        }
        .onAppear { showPassword.toggle() }
    }

    // MARK: - Logic
    private func inlineLogin() {
        errorMessage = nil
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Введите email и пароль"
            return
        }

        isLoading = true

        AuthService.shared.login(email: email, password: password) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let token):
                    print("✅ Logged in with token: \(token)")
                    let derivedName = email.components(separatedBy: "@").first ?? "User"
                    appState.logIn(token: token, name: derivedName.capitalized)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func inlineRegister() {
        errorMessage = nil
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "Пожалуйста, заполните все поля"
            return
        }

        guard password == confirmPassword else {
            errorMessage = "Пароли не совпадают"
            return
        }

        isLoading = true

        AuthService.shared.register(
            name: name,
            email: email,
            password: password,
            confirmPassword: confirmPassword
        ) { result in

            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let token):
                    print("✅ Registered with token: \(token)")
                    appState.logIn(token: token, name: name)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Localized text
    private func localized(_ key: String) -> String {
        switch key {
        case "name_placeholder": return ["kk": "Атыңыз", "ru": "Имя", "en": "Name"][lang.currentLanguage.rawValue]!
        case "confirm_password_placeholder": return ["kk": "Құпия сөзді растау", "ru": "Подтвердите пароль", "en": "Confirm Password"][lang.currentLanguage.rawValue]!
        case "subtitle":
            switch lang.currentLanguage {
            case .kk: return "Сіздің AI серіктесіңіз — денсаулық пен бақыт үшін"
            case .ru: return "Ваш AI-помощник для здоровья и счастья"
            case .en: return "Your AI companion for health and happiness"
            }
        case "register_subtitle":
            switch lang.currentLanguage {
            case .kk: return "Тіркелу арқылы AI әлеміне қосылыңыз"
            case .ru: return "Присоединяйтесь к миру AI — зарегистрируйтесь"
            case .en: return "Join the AI world — create your account"
            }
        case "email_placeholder": return ["kk": "Электрондық пошта", "ru": "Email", "en": "Email"][lang.currentLanguage.rawValue]!
        case "password_placeholder": return ["kk": "Құпия сөз", "ru": "Пароль", "en": "Password"][lang.currentLanguage.rawValue]!
        case "sign_email": return ["kk": "Пошта арқылы кіру", "ru": "Войти по Email", "en": "Continue with Email"][lang.currentLanguage.rawValue]!
        case "sign_up_email": return ["kk": "Тіркелу", "ru": "Зарегистрироваться", "en": "Sign Up"][lang.currentLanguage.rawValue]!
        case "no_account": return ["kk": "Аккаунт жоқ па? Тіркеліңіз", "ru": "Нет аккаунта? Зарегистрироваться", "en": "Don’t have an account? Sign Up"][lang.currentLanguage.rawValue]!
        case "already_have_account": return ["kk": "Тіркелгенсіз бе? Кіру", "ru": "Уже есть аккаунт? Войти", "en": "Already have an account? Log In"][lang.currentLanguage.rawValue]!
        case "sign_google": return ["kk": "Google арқылы кіру", "ru": "Войти через Google", "en": "Sign in with Google"][lang.currentLanguage.rawValue]!
        case "or": return ["kk": "немесе", "ru": "или", "en": "or"][lang.currentLanguage.rawValue]!
        case "policy_prefix": return ["kk": "Жалғастырған кезде сіз қабылдайсыз", "ru": "Продолжая, вы соглашаетесь с", "en": "By continuing you accept the"][lang.currentLanguage.rawValue]!
        case "policy_link": return ["kk": "Құпиялылық саясатын", "ru": "Политикой конфиденциальности", "en": "Privacy Policy"][lang.currentLanguage.rawValue]!
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
