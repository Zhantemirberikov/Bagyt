import Foundation

final class AuthService {
    static let shared = AuthService()
    private init() {}

    // MARK: - Login

    func login(email: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        if email.lowercased() == "test@bagyt.com" && password == "1234" {
            let token = "offline-\(email)"
            let name = "Тестовый пользователь"
            KeychainHelper.save(token, for: "auth_token")
            UserDefaults.standard.set(token, forKey: "userToken")
            Self.saveUserName(name, token: token)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                completion(.success(token))
            }
            return
        }

        sendAuthRequest(
            path: "login",
            body: [
                "email": email,
                "password": password
            ],
            fallbackName: nil,
            completion: completion
        )
    }

    // MARK: - Register

    func register(
        name: String,
        email: String,
        password: String,
        confirmPassword: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        sendAuthRequest(
            path: "register",
            body: [
                "name": name,
                "email": email,
                "password": password,
                "password_confirmation": confirmPassword
            ],
            fallbackName: name,
            completion: completion
        )
    }

    // MARK: - Auth Request

    private func sendAuthRequest(
        path: String,
        body: [String: Any],
        fallbackName: String?,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        var request = URLRequest(url: APIConfig.url(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("📤 AUTH \(path):", request.url?.absoluteString ?? "")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let raw = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""

            print("📡 AUTH status:", status)
            print("📦 AUTH raw:", raw)

            guard (200...299).contains(status) else {
                DispatchQueue.main.async {
                    completion(.failure(Self.makeError(code: status, message: raw.isEmpty ? "Server error" : raw)))
                }
                return
            }

            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["token"] as? String else {
                DispatchQueue.main.async {
                    completion(.failure(Self.makeError(code: -2, message: "Token not found in response")))
                }
                return
            }

            KeychainHelper.save(token, for: "auth_token")
            UserDefaults.standard.set(token, forKey: "userToken")

            var resolvedName = fallbackName

            if let user = json["user"] as? [String: Any] {
                if let id = user["id"] {
                    UserDefaults.standard.set(id, forKey: "userId")
                }

                if let name = user["name"] as? String,
                   !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    resolvedName = name
                }

                Self.applyUserProfile(user)
            }

            if let resolvedName {
                Self.saveUserName(resolvedName, token: token)
            }

            DispatchQueue.main.async {
                completion(.success(token))
            }
        }.resume()
    }

    // MARK: - Profile

    func updateProfile(
        name: String? = nil,
        age: Int? = nil,
        sex: String? = nil,
        height: Double? = nil,
        weight: Double? = nil,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        guard let token = KeychainHelper.read("auth_token") ?? UserDefaults.standard.string(forKey: "userToken"),
              !token.hasPrefix("offline-") else {
            completion?(.success(()))
            return
        }

        var body: [String: Any] = [:]

        if let name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                body["name"] = trimmed
            }
        }

        if let age, age > 0 {
            body["age"] = age
        }

        if let sex {
            let normalized = sex.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.isEmpty {
                body["sex"] = normalized
            }
        }

        if let height, height > 0 {
            body["height"] = Int(height.rounded())
        }

        if let weight, weight > 0 {
            body["weight"] = Int(weight.rounded())
        }

        guard !body.isEmpty else {
            completion?(.success(()))
            return
        }

        sendProfileUpdate(
            paths: ["profile", "user/profile", "user"],
            method: "PATCH",
            body: body,
            token: token,
            completion: completion
        )
    }

    private func sendProfileUpdate(
        paths: [String],
        method: String,
        body: [String: Any],
        token: String,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        guard let path = paths.first else {
            DispatchQueue.main.async {
                completion?(.failure(Self.makeError(code: 404, message: "Profile endpoint not found")))
            }
            return
        }

        var request = URLRequest(url: APIConfig.url(path))
        request.httpMethod = method
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async {
                    completion?(.failure(error))
                }
                return
            }

            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200...299).contains(status) {
                DispatchQueue.main.async {
                    completion?(.success(()))
                }
                return
            }

            if status == 405, method == "PATCH" {
                self.sendProfileUpdate(
                    paths: paths,
                    method: "PUT",
                    body: body,
                    token: token,
                    completion: completion
                )
                return
            }

            if [404, 405].contains(status), paths.count > 1 {
                self.sendProfileUpdate(
                    paths: Array(paths.dropFirst()),
                    method: "PATCH",
                    body: body,
                    token: token,
                    completion: completion
                )
                return
            }

            let raw = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            DispatchQueue.main.async {
                completion?(.failure(Self.makeError(code: status, message: raw.isEmpty ? "Profile update failed" : raw)))
            }
        }.resume()
    }

    // MARK: - Social Login

    func socialLogin(
        provider: String,
        token: String,
        name: String?,
        completion: ((Result<String, Error>) -> Void)? = nil
    ) {
        let error = Self.makeError(code: 501, message: "Social login is temporarily unavailable.")
        DispatchQueue.main.async {
            completion?(.failure(error))
        }
    }

    // MARK: - Logout

    func logout(completion: (() -> Void)? = nil) {
        let token = KeychainHelper.read("auth_token")

        func wipeLocal() {
            KeychainHelper.delete("auth_token")
            UserDefaults.standard.removeObject(forKey: "userToken")
            UserDefaults.standard.removeObject(forKey: "userName")
            UserDefaults.standard.removeObject(forKey: "userId")
            DispatchQueue.main.async {
                completion?()
            }
        }

        guard let token, !token.hasPrefix("offline-") else {
            wipeLocal()
            return
        }

        var request = URLRequest(url: APIConfig.url("logout"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { _, _, _ in
            wipeLocal()
        }.resume()
    }

    private static func makeError(code: Int, message: String) -> NSError {
        NSError(
            domain: "AuthService",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private static func saveUserName(_ name: String, token: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        UserDefaults.standard.set(trimmed, forKey: "userName")
        UserDefaults.standard.set(trimmed, forKey: "userName_\(token)")
    }

    private static func applyUserProfile(_ user: [String: Any]) {
        let store = UserProfileStore.shared
        var shouldSave = false

        if let age = user["age"] as? Int, age > 0 {
            store.age = age
            shouldSave = true
        }

        if let sex = user["sex"] as? String,
           !sex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            store.gender = sex
            shouldSave = true
        }

        if let height = numericValue(user["height"]), height > 0 {
            store.height = height
            shouldSave = true
        }

        if let weight = numericValue(user["weight"]), weight > 0 {
            store.weight = weight
            shouldSave = true
        }

        if shouldSave {
            store.save()
        }
    }

    private static func numericValue(_ value: Any?) -> Double? {
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let string = value as? String { return Double(string) }
        return nil
    }
}
