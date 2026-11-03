import Foundation

struct WishAdvResult: Codable {
    let code: Int
    let msg: String?
    let data: WishAdvPayload?
}

struct WishAdvPayload: Codable {
    let img: String?
    let isBlank: Int?

    enum CodingKeys: String, CodingKey {
        case img
        case isBlank = "is_blank"
    }
}

enum WishAdvClient {
    private static let tag = "AdvAPI"
    private static let endpoint = WishAPIConfig.publicEndpoint("adv")

    static func fetch() async throws -> WishAdvResult {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        WishNetworkLogger.logRequest(tag: tag, url: endpoint, method: "GET")

        let (data, response) = try await URLSession.shared.data(for: request)
        let responseText = String(data: data, encoding: .utf8)

        guard let http = response as? HTTPURLResponse else {
            WishNetworkLogger.logError(tag: tag, error: URLError(.badServerResponse))
            throw URLError(.badServerResponse)
        }

        WishNetworkLogger.logResponse(tag: tag, statusCode: http.statusCode, body: responseText)

        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(WishAdvResult.self, from: data)
    }
}
