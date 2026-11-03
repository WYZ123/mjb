import Foundation
import UIKit

struct WishPayFieldResult: Codable {
    let code: Int
    let msg: String?
    let data: WishPayFieldPayload?
}

struct WishPayFieldPayload: Codable {
    let zhifu: String?
}

enum WishPayFieldClient {
    private static let tag = "PayFieldAPI"
    private static let endpoint = WishAPIConfig.publicEndpoint("pay_field")

    static func fetchZhifuPrefixes() async -> [String] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15

        WishNetworkLogger.logRequest(tag: tag, url: endpoint)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let responseText = String(data: data, encoding: .utf8)

            guard let http = response as? HTTPURLResponse else {
                WishNetworkLogger.logError(tag: tag, error: URLError(.badServerResponse))
                return []
            }

            WishNetworkLogger.logResponse(tag: tag, statusCode: http.statusCode, body: responseText)

            guard (200...299).contains(http.statusCode) else {
                return []
            }

            let decoded = try JSONDecoder().decode(WishPayFieldResult.self, from: data)
            guard decoded.code == 1, let zhifu = decoded.data?.zhifu else {
                return []
            }

            return zhifu
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        } catch {
            WishNetworkLogger.logError(tag: tag, error: error)
            return []
        }
    }
}

final class WishPayFieldStore {
    private(set) var prefixes: [String] = []

    func load() async {
        prefixes = await WishPayFieldClient.fetchZhifuPrefixes()
    }

    func matches(_ url: URL) -> Bool {
        let absolute = url.absoluteString
        return prefixes.contains { !$0.isEmpty && absolute.contains($0) }
    }

    @discardableResult
    func openExternalIfMatched(_ url: URL) -> Bool {
        guard matches(url) else { return false }
        guard UIApplication.shared.canOpenURL(url) else { return true }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        return true
    }
}
