import Foundation

struct APIUser: Codable {
    let id: Int
    let name: String
    let email: String
    let sex: String?
    let age: Int?
    let createdAt: Date?
}

struct AuthResponse: Codable {
    let user: APIUser
    let roles: [String]
    let permissions: [String]
    let token: String
    let tokenType: String?
    let expiresIn: Int?
}

struct ChatSummary: Codable {
    let id: Int
    let title: String?
    let lastMessage: String?
    let createdAt: Date?
    let updatedAt: Date?
}

struct ChatPaginator: Codable {
    let data: [ChatSummary]
    let currentPage: Int?
    let lastPage: Int?
    let total: Int?
    let perPage: Int?
}

struct APIMessage: Codable {
    let id: Int
    let role: String
    let message: String
    let createdAt: Date?
}

struct CreatedChatResponse: Codable {
    let id: Int
    let title: String?
    let createdAt: Date?
}

struct SendMessageResponse: Codable {
    let userMessage: APIMessage
    let assistantMessage: APIMessage
}
