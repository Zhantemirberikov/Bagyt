//
//  AuthService.swift
//  Bagyt
//
//  Created by Жантемир Бериков on 10.11.2025.
//

import Foundation

final class AuthService {
    static let shared = AuthService()
    private init() {}

    // ✅ Прямые URL эндпоинтов
    private let registerURL = URL(string: "https://2cc2abd0c289.ngrok-free.app/api/register")!
    private let loginURL = URL(string: "https://2cc2abd0c289.ngrok-free.app/api/login")!

    // MARK: - Login
    func login(email: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {

        // ✅ Offline вход — работает даже если сервер не отвечает
        if email.lowercased() == "test@bagyt.com" && password == "1234" {
            print("🟢 Offline login activated for test@bagyt.com")
            UserDefaults.standard.set("Тестовый пользователь", forKey: "userName")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion(.success("offline-token"))
            }
            return
        }

        // Если не тестовый аккаунт — обычный сетевой логин
        sendLoginRequest(to: loginURL, email: email, password: password, completion: completion)
    }

    // MARK: - Register
    func register(
        name: String,
        email: String,
        password: String,
        confirmPassword: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        sendRegisterRequest(
            to: registerURL,
            name: name,
            email: email,
            password: password,
            confirmPassword: confirmPassword,
            completion: completion
        )
    }

    // MARK: - Логика Login
    private func sendLoginRequest(
        to url: URL,
        email: String,
        password: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("📤 Sending LOGIN request to:", url.absoluteString)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error:", error.localizedDescription)
                // Если сервер не отвечает — всё ещё разрешаем вход под test@bagyt.com
                return DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                return DispatchQueue.main.async {
                    completion(.failure(
                        NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
                    ))
                }
            }

            print("📡 Login status:", httpResponse.statusCode)

            guard (200...299).contains(httpResponse.statusCode) else {
                let message = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                print("⚠️ Server returned error:", message)
                return DispatchQueue.main.async {
                    completion(.failure(
                        NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
                    ))
                }
            }

            guard let data = data else {
                return DispatchQueue.main.async {
                    completion(.failure(
                        NSError(domain: "", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    ))
                }
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("✅ JSON Response:", json)

                    if let token = json["token"] as? String {
                        // ✅ Извлекаем имя из user.name
                        if let user = json["user"] as? [String: Any],
                           let name = user["name"] as? String {
                            UserDefaults.standard.set(name, forKey: "userName")
                            print("💾 Saved userName:", name)
                        }

                        DispatchQueue.main.async {
                            completion(.success(token))
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(
                                NSError(domain: "", code: -3, userInfo: [NSLocalizedDescriptionKey: "Token not found in response"])
                            ))
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(
                            NSError(domain: "", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])
                        ))
                    }
                }
            } catch {
                print("❌ JSON parse error:", error)
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    // MARK: - Логика Register
    private func sendRegisterRequest(
        to url: URL,
        name: String,
        email: String,
        password: String,
        confirmPassword: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let body: [String: Any] = [
            "name": name,
            "email": email,
            "password": password,
            "password_confirmation": confirmPassword
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("📤 Sending REGISTER request to:", url.absoluteString)
        print("📦 Body:", body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error:", error.localizedDescription)
                return DispatchQueue.main.async { completion(.failure(error)) }
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                return DispatchQueue.main.async {
                    completion(.failure(
                        NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
                    ))
                }
            }

            print("📡 Register status:", httpResponse.statusCode)

            guard (200...299).contains(httpResponse.statusCode) else {
                let message = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                print("⚠️ Server returned error:", message)
                return DispatchQueue.main.async {
                    completion(.failure(
                        NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
                    ))
                }
            }

            guard let data = data else {
                return DispatchQueue.main.async {
                    completion(.failure(
                        NSError(domain: "", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    ))
                }
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("✅ JSON Response:", json)

                    if let token = json["token"] as? String {
                        // 💾 Сохраняем имя сразу после регистрации
                        UserDefaults.standard.set(name, forKey: "userName")
                        print("💾 Saved userName:", name)

                        DispatchQueue.main.async {
                            completion(.success(token))
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(
                                NSError(domain: "", code: -3, userInfo: [NSLocalizedDescriptionKey: "Token not found in response"])
                            ))
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(
                            NSError(domain: "", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])
                        ))
                    }
                }
            } catch {
                print("❌ JSON parse error:", error)
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    // MARK: - Logout
    func logout() {
        print("🟡 Logged out locally")
    }
}
