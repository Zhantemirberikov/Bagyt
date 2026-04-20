import Foundation
import Combine

final class AuthViewModel: ObservableObject {

    @Published var name = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isRegisterMode = false

    @Published var didLogin = false
    @Published var loggedUserName: String?

    // MARK: - Validation
    var isValid: Bool {
        if isRegisterMode {
            return !name.isEmpty &&
                   !email.isEmpty &&
                   !password.isEmpty &&
                   password == confirmPassword
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }

    // MARK: - LOGIN
    func login() {
        errorMessage = nil

        // 🔥 ТЕСТОВЫЙ ПОЛЬЗОВАТЕЛЬ
        if email == "test@test.com" && password == "123456" {
            print("⚡ Test user login")
            self.loggedUserName = "Test User"
            self.didLogin = true
            return
        }

        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Введите email и пароль"
            return
        }

        isLoading = true

        AuthService.shared.login(email: email, password: password) { result in
            DispatchQueue.main.async {
                self.isLoading = false

                switch result {
                case .success(let token):
                    print("✅ Logged in with token: \(token)")
                    let derivedName = self.email.components(separatedBy: "@").first ?? "User"
                    self.loggedUserName = derivedName.capitalized
                    self.didLogin = true

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - REGISTER
    func register() {
        errorMessage = nil

        guard !name.isEmpty,
              !email.isEmpty,
              !password.isEmpty,
              !confirmPassword.isEmpty else {
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
                self.isLoading = false

                switch result {
                case .success(let token):
                    print("✅ Registered with token: \(token)")
                    self.loggedUserName = self.name
                    self.didLogin = true

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
