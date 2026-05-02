//
//  LoginView.swift
//  Bagyt
//
//  Premium redesign — Bagyt design system
//  AuthViewModel и AuthService не тронуты
//

import SwiftUI
import AuthenticationServices
import Combine

// MARK: - LoginView

struct LoginView: View {
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = AuthViewModel()

    var showBackground: Bool = true
    var showHeader: Bool     = true

    @State private var showPassword  = false
    @State private var showPrivacy   = false
    @State private var appear        = false

    enum Field { case name, email, password, confirmPassword }
    @FocusState private var focused: Field?

    private let accent  = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)

    var body: some View {
        ZStack {
            if showBackground { AnimatedGradientBackground() }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if showHeader { headerBlock }

                    VStack(spacing: 24) {
                        titleBlock
                        formCard
                        if !vm.isRegisterMode { socialBlock }
                        privacyBlock
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }

            if vm.isLoading {
                Color.black.opacity(0.25).ignoresSafeArea()
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 80, height: 80)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: accent))
                        .scaleEffect(1.3)
                }
            }
        }
        .onTapGesture { focused = nil }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appear = true }
        }
        .onChange(of: vm.didLogin) { success in
            if success {
                appState.logIn(
                    token: vm.loggedUserToken ?? UserDefaults.standard.string(forKey: "userToken") ?? vm.email,
                    name: vm.loggedUserName
                )
            }
        }
        .sheet(isPresented: $showPrivacy) {
            SafariView(url: URL(string: "https://google.com")!)
        }
    }

    // MARK: - Header

    private var headerBlock: some View {
        HStack {
            HStack(spacing: 4) {
                Text("Bagyt")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                Image(systemName: "heart.fill")
                    .foregroundColor(Color(red: 0.95, green: 0.25, blue: 0.25))
                    .font(.system(size: 14))
                    .offset(y: -2)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(spacing: 16) {
            // Иконка в стиле Liquid Glass
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .background(.ultraThinMaterial, in: Circle())
                    .frame(width: 76, height: 76)
                
                Circle()
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)

                Image(systemName: vm.isRegisterMode ? "person.badge.plus" : "lock.shield.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            .padding(.top, 8)
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)
            .scaleEffect(appear ? 1 : 0.8)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: appear)

            Text(vm.isRegisterMode ? loc("register_subtitle") : loc("subtitle"))
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 10)
                .animation(.easeOut(duration: 0.5).delay(0.1), value: appear)
        }
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(spacing: 14) {
            // Имя (только регистрация)
            if vm.isRegisterMode {
                authField(
                    icon: "person",
                    placeholder: loc("name_placeholder"),
                    text: $vm.name,
                    field: .name,
                    next: .email
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Email
            authField(
                icon: "envelope",
                placeholder: loc("email_placeholder"),
                text: $vm.email,
                field: .email,
                next: .password,
                keyboard: .emailAddress
            )

            // Пароль
            passwordField(
                placeholder: loc("password_placeholder"),
                text: $vm.password,
                field: .password,
                isLast: !vm.isRegisterMode
            )

            // Подтверждение пароля
            if vm.isRegisterMode {
                passwordField(
                    placeholder: loc("confirm_password_placeholder"),
                    text: $vm.confirmPassword,
                    field: .confirmPassword,
                    isLast: true
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Ошибка
            if let err = vm.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.95, green: 0.25, blue: 0.25))
                    Text(err)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(red: 0.95, green: 0.25, blue: 0.25))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.95, green: 0.25, blue: 0.25).opacity(0.08))
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Кнопка войти/зарегистрироваться
            Button { submit() } label: {
                HStack(spacing: 8) {
                    if vm.isLoading {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.85)
                    } else {
                        Image(systemName: vm.isRegisterMode ? "person.badge.plus" : "arrow.right.circle.fill")
                            .font(.system(size: 17))
                    }
                    Text(vm.isRegisterMode ? loc("sign_up_email") : loc("sign_email"))
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Group {
                        if vm.isValid {
                            LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
                        } else {
                            LinearGradient(colors: [Color(red: 0.7, green: 0.82, blue: 0.90), Color(red: 0.7, green: 0.82, blue: 0.90)],
                                           startPoint: .leading, endPoint: .trailing)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: vm.isValid ? accent.opacity(0.35) : .clear, radius: 12, x: 0, y: 5)
            }
            .disabled(!vm.isValid)
            .animation(.easeInOut(duration: 0.2), value: vm.isValid)

            // Переключение вход/регистрация
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    vm.isRegisterMode.toggle()
                    vm.errorMessage = nil
                    vm.name = ""
                    vm.confirmPassword = ""
                }
            } label: {
                Text(vm.isRegisterMode ? loc("already_have_account") : loc("no_account"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accent)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.88))
                .shadow(color: accent.opacity(0.10), radius: 16, x: 0, y: 6)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 1))
        )
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.15), value: appear)
    }

    // MARK: - Auth Field

    private func authField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        next: Field? = nil,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(focused == field ? accent : Color(red: 0.55, green: 0.67, blue: 0.75))
                .frame(width: 20)
                .animation(.easeInOut(duration: 0.2), value: focused == field)

            TextField(placeholder, text: text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                .keyboardType(keyboard)
                .autocapitalization(.none)
                .focused($focused, equals: field)
                .submitLabel(next != nil ? .next : .done)
                .onSubmit {
                    if let next = next { focused = next }
                    else { submit() }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(focused == field
                      ? accent.opacity(0.05)
                      : Color(red: 0.94, green: 0.97, blue: 1.0))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(focused == field ? accent.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
                .animation(.easeInOut(duration: 0.2), value: focused == field)
        )
    }

    // MARK: - Password Field

    private func passwordField(placeholder: String, text: Binding<String>, field: Field, isLast: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(focused == field ? accent : Color(red: 0.55, green: 0.67, blue: 0.75))
                .frame(width: 20)
                .animation(.easeInOut(duration: 0.2), value: focused == field)

            Group {
                if showPassword {
                    TextField(placeholder, text: text)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
            .focused($focused, equals: field)
            .submitLabel(isLast ? .done : .next)
            .onSubmit {
                if isLast { submit() }
                else { focused = .confirmPassword }
            }

            Button {
                showPassword.toggle()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 0.55, green: 0.67, blue: 0.75))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(focused == field
                      ? accent.opacity(0.05)
                      : Color(red: 0.94, green: 0.97, blue: 1.0))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(focused == field ? accent.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
                .animation(.easeInOut(duration: 0.2), value: focused == field)
        )
    }

    // MARK: - Social Block

    private var socialBlock: some View {
        VStack(spacing: 14) {
            // Разделитель
            HStack(spacing: 12) {
                Rectangle().fill(Color.white.opacity(0.5)).frame(height: 1)
                Text(loc("or"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .fixedSize()
                Rectangle().fill(Color.white.opacity(0.5)).frame(height: 1)
            }

            // Google
            Button { fakeGoogleLogin() } label: {
                HStack(spacing: 10) {
                    // Google G иконка
                    ZStack {
                        Circle().fill(Color.white).frame(width: 24, height: 24)
                        Text("G")
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(Color(red: 0.22, green: 0.46, blue: 0.95))
                    }
                    Text(loc("sign_google"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.88))
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color(red: 0.88, green: 0.93, blue: 0.97), lineWidth: 1))
                )
            }

            // Apple
            Button { fakeAppleLogin() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Sign in with Apple")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.06, green: 0.09, blue: 0.16))
                        .shadow(color: .black.opacity(0.20), radius: 8, x: 0, y: 3)
                )
            }
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.22), value: appear)
    }

    // MARK: - Privacy

    private var privacyBlock: some View {
        (
            Text(loc("policy_prefix") + " ")
                .foregroundColor(.white.opacity(0.85))
            + Text(loc("policy_link"))
                .underline()
                .foregroundColor(.white)
        )
        .font(.system(size: 12, weight: .bold))
        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 10)
        .onTapGesture { showPrivacy = true }
        .opacity(appear ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.28), value: appear)
    }

    // MARK: - Helpers

    private func submit() {
        focused = nil
        vm.isRegisterMode ? vm.register() : vm.login()
    }

    private func fakeGoogleLogin() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        appState.logIn(token: "fake-google-token", name: "Google User")
    }

    private func fakeAppleLogin() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        appState.logIn(token: "fake-apple-token", name: "Apple User")
    }

    private func loc(_ key: String) -> String {
        let l = lang.currentLanguage
        switch key {
        case "subtitle":
            switch l { case .kk: return "Денсаулық пен бақыт үшін"; case .ru: return "Войдите в свой аккаунт"; case .en: return "Sign in to your account" }
        case "register_subtitle":
            switch l { case .kk: return "Жаңа аккаунт жасаңыз"; case .ru: return "Создайте новый аккаунт"; case .en: return "Create your account" }
        case "name_placeholder":       return ["kk": "Атыңыз", "ru": "Имя", "en": "Full name"][l.rawValue]!
        case "email_placeholder":      return ["kk": "Электрондық пошта", "ru": "Email", "en": "Email"][l.rawValue]!
        case "password_placeholder":   return ["kk": "Құпия сөз", "ru": "Пароль", "en": "Password"][l.rawValue]!
        case "confirm_password_placeholder": return ["kk": "Растау", "ru": "Подтвердите пароль", "en": "Confirm password"][l.rawValue]!
        case "sign_email":             return ["kk": "Кіру", "ru": "Войти", "en": "Sign In"][l.rawValue]!
        case "sign_up_email":          return ["kk": "Тіркелу", "ru": "Зарегистрироваться", "en": "Sign Up"][l.rawValue]!
        case "no_account":             return ["kk": "Аккаунт жоқ па? Тіркелу", "ru": "Нет аккаунта? Зарегистрироваться", "en": "No account? Sign Up"][l.rawValue]!
        case "already_have_account":   return ["kk": "Аккаунт бар ма? Кіру", "ru": "Уже есть аккаунт? Войти", "en": "Have account? Sign In"][l.rawValue]!
        case "sign_google":            return ["kk": "Google арқылы кіру", "ru": "Войти через Google", "en": "Continue with Google"][l.rawValue]!
        case "or":                     return ["kk": "немесе", "ru": "или", "en": "or"][l.rawValue]!
        case "policy_prefix":          return ["kk": "Жалғастыру арқылы сіз қабылдайсыз", "ru": "Продолжая, вы соглашаетесь с", "en": "By continuing you agree to"][l.rawValue]!
        case "policy_link":            return ["kk": "Құпиялылық саясатын", "ru": "Политикой конфиденциальности", "en": "Privacy Policy"][l.rawValue]!
        default: return key
        }
    }
}

// MARK: - Preview

#Preview {
    LoginView()
        .environmentObject(AppState())
        .environmentObject(LanguageManager())
}
