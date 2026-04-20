import SwiftUI
import AuthenticationServices
import Combine

struct LoginView: View {
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var appState: AppState
    
    @StateObject private var viewModel = AuthViewModel()
    
    var showBackground: Bool = true
    var showHeader: Bool = true

    @State private var showPassword = false
    @State private var showPrivacy = false
    
    enum Field {
        case name, email, password, confirmPassword
    }
    @FocusState private var focusedField: Field?

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

                Text(viewModel.isRegisterMode ? localized("register_subtitle") : localized("subtitle"))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .shadow(radius: 2)

                GlassPanel {
                    VStack(spacing: 14) {

                        if viewModel.isRegisterMode {
                            TextField(localized("name_placeholder"), text: $viewModel.name)
                                .focused($focusedField, equals: .name)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .email }
                                .padding()
                                .background(Color.black.opacity(0.05))
                                .cornerRadius(10)
                        }

                        TextField(localized("email_placeholder"), text: $viewModel.email)
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                            .padding()
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(10)

                        HStack {
                            if showPassword {
                                TextField(localized("password_placeholder"), text: $viewModel.password)
                            } else {
                                SecureField(localized("password_placeholder"), text: $viewModel.password)
                            }

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                            }
                        }
                        .focused($focusedField, equals: .password)
                        .submitLabel(viewModel.isRegisterMode ? .next : .done)
                        .onSubmit {
                            if viewModel.isRegisterMode {
                                focusedField = .confirmPassword
                            } else {
                                submit()
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(10)

                        if viewModel.isRegisterMode {
                            HStack {
                                if showPassword {
                                    TextField(localized("confirm_password_placeholder"), text: $viewModel.confirmPassword)
                                } else {
                                    SecureField(localized("confirm_password_placeholder"), text: $viewModel.confirmPassword)
                                }

                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                }
                            }
                            .focused($focusedField, equals: .confirmPassword)
                            .submitLabel(.done)
                            .onSubmit { submit() }
                            .padding()
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(10)
                        }

                        if let err = viewModel.errorMessage {
                            Text(err)
                                .foregroundColor(.red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .animation(.easeInOut, value: viewModel.errorMessage)
                        }

                        Button {
                            submit()
                        } label: {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                }
                                Text(viewModel.isRegisterMode ? localized("sign_up_email") : localized("sign_email"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .disabled(!viewModel.isValid)
                        .opacity(viewModel.isValid ? 1 : 0.5)

                        Button {
                            withAnimation {
                                viewModel.isRegisterMode.toggle()
                                viewModel.errorMessage = nil
                                viewModel.name = ""
                                viewModel.confirmPassword = ""
                            }
                        } label: {
                            Text(viewModel.isRegisterMode ? localized("already_have_account") : localized("no_account"))
                                .font(.footnote)
                                .foregroundColor(.black.opacity(0.8))
                        }
                    }
                }
                .padding(.horizontal, 30)

                // 🔥 SOCIAL LOGIN (ФЕЙК)
                if !viewModel.isRegisterMode {
                    HStack {
                        Rectangle().frame(height: 1).foregroundColor(.black.opacity(0.2))
                        Text(localized("or"))
                            .foregroundColor(.black.opacity(0.8))
                            .font(.caption)
                        Rectangle().frame(height: 1).foregroundColor(.black.opacity(0.2))
                    }
                    .padding(.horizontal)

                    VStack(spacing: 12) {

                        // ✅ GOOGLE FAKE LOGIN
                        Button {
                            fakeGoogleLogin()
                        } label: {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                Text(localized("sign_google"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                            .shadow(radius: 3)
                        }
                        .padding(.horizontal)

                        // ✅ APPLE FAKE LOGIN
                        Button {
                            fakeAppleLogin()
                        } label: {
                            HStack {
                                Image(systemName: "applelogo")
                                Text("Sign in with Apple")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }

                // 🔥 PRIVACY
                VStack(spacing: 6) {
                    (
                        Text("\(localized("policy_prefix")) ")
                            .foregroundColor(.black.opacity(0.8))
                        +
                        Text(localized("policy_link"))
                            .underline()
                            .foregroundColor(.blue)
                    )
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .onTapGesture {
                        showPrivacy = true
                    }
                }
                .padding(.horizontal)

                Spacer()
            }

            if viewModel.isLoading {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView().scaleEffect(1.5)
            }
        }
        .onTapGesture { focusedField = nil }
        .onAppear {
            showPassword.toggle()
                        
        }
        .onChange(of: viewModel.didLogin) { success in
            if success {
                appState.logIn(token: viewModel.email, name: viewModel.loggedUserName)
            }
        }
        .sheet(isPresented: $showPrivacy) {
            SafariView(url: URL(string: "https://google.com")!)
        }
    }

    // ✅ FAKE GOOGLE
    private func fakeGoogleLogin() {
        print("🟢 Fake Google login")
        appState.logIn(token: "fake-google-token", name: "Google User")
    }

    // ✅ FAKE APPLE
    private func fakeAppleLogin() {
        print("🍎 Fake Apple login")
        appState.logIn(token: "fake-apple-token", name: "Apple User")
    }

    private func submit() {
        viewModel.isRegisterMode ? viewModel.register() : viewModel.login()
    }

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
