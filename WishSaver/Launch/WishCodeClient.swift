import Foundation

struct WishCodeResult: Codable {
    let code: Int
    let msg: String?
    let data: WishCodePayload?
}

struct WishCodePayload: Codable {
    let url: String?
    let isTabbar: Int?

    enum CodingKeys: String, CodingKey {
        case url
        case isTabbar = "is_tabbar"
    }
}

enum WishCodeClient {
    private static let tag = "CodeAPI"

    static func fetch(code: String, udid: String) async throws -> WishCodeResult {
        var components = URLComponents(url: WishAPIConfig.publicEndpoint("get_code"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "udid", value: udid),
        ]
        let endpoint = components.url!

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        WishNetworkLogger.logRequest(
            tag: tag,
            url: endpoint,
            method: "GET",
            parameters: ["code": code, "udid": udid]
        )

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

        return try JSONDecoder().decode(WishCodeResult.self, from: data)
    }
}
