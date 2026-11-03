import Foundation

struct WishVersionResult: Codable {
    let code: Int
    let msg: String?
    let data: WishVersionPayload?
}

struct WishVersionPayload: Codable {
    let status: Int?
    let version: String?
    let type: Int?
    let url: String?
    let isTabbar: Int?
    let isCode: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case version
        case type
        case url
        case isTabbar = "is_tabbar"
        case isCode = "is_code"
    }
}

enum WishVersionClient {
    private static let tag = "VersionAPI"

    static func fetchVersion(appVersion: String, udid: String) async throws -> WishVersionResult {
        var components = URLComponents(url: WishAPIConfig.publicEndpoint("get_version"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "version", value: appVersion),
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
            parameters: ["version": appVersion, "udid": udid]
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

        return try JSONDecoder().decode(WishVersionResult.self, from: data)
    }
}
