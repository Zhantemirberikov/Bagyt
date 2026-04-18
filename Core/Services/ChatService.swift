import Foundation

// MARK: - Message model
struct ChatMessage: Identifiable, Codable, Equatable {
    enum Sender: String, Codable {
        case user
        case assistant
    }

    let id: UUID
    let text: String
    let sender: Sender
    let date: Date

    init(id: UUID = UUID(), text: String, sender: Sender, date: Date = Date()) {
        self.id = id
        self.text = text
        self.sender = sender
        self.date = date
    }
}

// MARK: - Chat Service
final class ChatService {
    static let shared = ChatService()
    
    private let baseURL = "https://a2e3-185-18-253-5.ngrok-free.app/api"
    private let storageKey = "chat_history_final"

    private init() {}

    // MARK: - LOAD
    func loadMessages() -> [ChatMessage] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([ChatMessage].self, from: data)) ?? []
    }

    // MARK: - SAVE
    func saveMessages(_ messages: [ChatMessage]) {
        let data = try? JSONEncoder().encode(messages)
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    // MARK: - MAIN SEND
    func sendMessageToAI(userText: String, completion: @escaping (ChatMessage) -> Void) {

        print("🔥 SEND MESSAGE:", userText)

        // 🔐 проверка токена
        guard let token = UserDefaults.standard.string(forKey: "auth_token") else {
            completion(ChatMessage(text: "❌ No auth token. Login first.", sender: .assistant))
            return
        }

        print("🔑 TOKEN:", token)

        // 1️⃣ создаём complaint
        createComplaint(text: userText, token: token) { complaintId in
            
            print("✅ Complaint created with id:", complaintId)

            // 2️⃣ отправляем в AI
            self.analyzeComplaint(id: complaintId, token: token, completion: completion)
        }
    }

    // MARK: - STEP 1: CREATE COMPLAINT
    private func createComplaint(text: String, token: String, completion: @escaping (Int) -> Void) {
        
        guard let url = URL(string: "\(baseURL)/complaints") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body = ["complaint": text]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("📡 CREATE REQUEST:", request.allHTTPHeaderFields ?? [:])

        URLSession.shared.dataTask(with: request) { data, response, error in

            if let error = error {
                print("❌ createComplaint error:", error)
                return
            }

            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("📊 STATUS:", status)

            guard let data = data else { return }

            let raw = String(data: data, encoding: .utf8) ?? ""
            print("📦 createComplaint RAW:", raw)

            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let id = json["id"] as? Int
            else {
                print("❌ Failed to parse complaint id")
                return
            }

            DispatchQueue.main.async {
                completion(id)
            }

        }.resume()
    }

    // MARK: - STEP 2: ANALYZE
    private func analyzeComplaint(id: Int, token: String, completion: @escaping (ChatMessage) -> Void) {

        guard let url = URL(string: "\(baseURL)/complaints/analyze") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body = ["complaint_id": id]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("📡 ANALYZE REQUEST:", request.allHTTPHeaderFields ?? [:])

        URLSession.shared.dataTask(with: request) { data, response, error in

            if let error = error {
                DispatchQueue.main.async {
                    completion(ChatMessage(
                        text: "❌ Network error:\n\(error.localizedDescription)",
                        sender: .assistant
                    ))
                }
                return
            }

            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("📊 ANALYZE STATUS:", status)

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(ChatMessage(
                        text: "❌ No data from server",
                        sender: .assistant
                    ))
                }
                return
            }

            let raw = String(data: data, encoding: .utf8) ?? ""
            print("📦 ANALYZE RAW:", raw)

            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                DispatchQueue.main.async {
                    completion(ChatMessage(
                        text: "❌ Invalid JSON",
                        sender: .assistant
                    ))
                }
                return
            }

            let reply =
                json["reply"] as? String ??
                json["message"] as? String ??
                "⚠️ No reply from AI"

            DispatchQueue.main.async {
                completion(ChatMessage(
                    text: reply,
                    sender: .assistant
                ))
            }

        }.resume()
    }
}
