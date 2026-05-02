import Foundation

enum APIConfig {
    static let baseURL = URL(string: "https://a8a0-185-18-253-5.ngrok-free.app/api")!

    static func url(_ path: String) -> URL {
        let cleaned = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return baseURL.appendingPathComponent(cleaned)
    }
}
