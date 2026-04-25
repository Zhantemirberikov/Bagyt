import Foundation

enum APIError: Error, LocalizedError {
    case invalidResponse
    case http(status: Int, body: String)
    case noData
    case decoding(Error)
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .http(let status, let body):
            return "HTTP \(status): \(body.isEmpty ? HTTPURLResponse.localizedString(forStatusCode: status) : body)"
        case .noData: return "No data received"
        case .decoding(let e): return "Decoding error: \(e.localizedDescription)"
        case .underlying(let e): return e.localizedDescription
        }
    }
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 60
        cfg.timeoutIntervalForResource = 120
        return URLSession(configuration: cfg)
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let s = try container.decode(String.self)
            if let date = iso.date(from: s) ?? isoBasic.date(from: s) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(s)")
        }
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    // MARK: - Request

    func request<T: Decodable>(
        _ method: String,
        path: String,
        body: [String: Any]? = nil,
        authenticated: Bool = true,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        var request = URLRequest(url: APIConfig.url(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if authenticated, let token = KeychainHelper.read("auth_token"), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        print("📡 \(method) \(request.url?.absoluteString ?? "?")")

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                return DispatchQueue.main.async { completion(.failure(.underlying(error))) }
            }
            guard let http = response as? HTTPURLResponse else {
                return DispatchQueue.main.async { completion(.failure(.invalidResponse)) }
            }
            let raw = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            print("📊 \(http.statusCode) ← \(method) \(path)")

            guard (200...299).contains(http.statusCode) else {
                return DispatchQueue.main.async {
                    completion(.failure(.http(status: http.statusCode, body: raw)))
                }
            }
            guard let data = data else {
                return DispatchQueue.main.async { completion(.failure(.noData)) }
            }
            do {
                let value = try APIClient.decoder.decode(T.self, from: data)
                DispatchQueue.main.async { completion(.success(value)) }
            } catch {
                print("❌ Decode failed: \(error)\nRaw: \(raw.prefix(500))")
                DispatchQueue.main.async { completion(.failure(.decoding(error))) }
            }
        }.resume()
    }

    func requestVoid(
        _ method: String,
        path: String,
        body: [String: Any]? = nil,
        authenticated: Bool = true,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        var request = URLRequest(url: APIConfig.url(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if authenticated, let token = KeychainHelper.read("auth_token"), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                return DispatchQueue.main.async { completion(.failure(.underlying(error))) }
            }
            guard let http = response as? HTTPURLResponse else {
                return DispatchQueue.main.async { completion(.failure(.invalidResponse)) }
            }
            let raw = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            guard (200...299).contains(http.statusCode) else {
                return DispatchQueue.main.async {
                    completion(.failure(.http(status: http.statusCode, body: raw)))
                }
            }
            DispatchQueue.main.async { completion(.success(())) }
        }.resume()
    }
}
