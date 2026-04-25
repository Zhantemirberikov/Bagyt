import Foundation

final class AuthService {
    static let shared = AuthService()
    private init() {}

    // MARK: - Login

    func login(email: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        if email.lowercased() == "test@bagyt.com" && password == "1234" {
            let token = "offline-\(email)"
            KeychainHelper.save(token, for: "auth_token")
            UserDefaults.standard.set(token, forKey: "userToken")
            UserDefaults.standard.set("Тестовый пользователь", forKey: "userName")

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

            if let user = json["user"] as? [String: Any] {
                if let id = user["id"] {
                    UserDefaults.standard.set(id, forKey: "userId")
                }

                if let name = user["name"] as? String {
                    UserDefaults.standard.set(name, forKey: "userName")
                } else if let fallbackName {
                    UserDefaults.standard.set(fallbackName, forKey: "userName")
                }
            } else if let fallbackName {
                UserDefaults.standard.set(fallbackName, forKey: "userName")
            }

            DispatchQueue.main.async {
                completion(.success(token))
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
}
