import Foundation

enum WishNetworkLogger {
    static func logRequest(
        tag: String,
        url: URL,
        method: String = "POST",
        parameters: [String: String] = [:],
        body: String? = nil
    ) {
        print("========== [\(tag)] Request ==========")
        print("[\(tag)] \(method) \(url.absoluteString)")
        if !parameters.isEmpty {
            print("[\(tag)] Parameters: \(parameters)")
        }
        if let body, !body.isEmpty {
            print("[\(tag)] Body: \(body)")
        }
        print("======================================")
    }

    static func logResponse(tag: String, statusCode: Int, body: String?) {
        print("========== [\(tag)] Response ==========")
        print("[\(tag)] HTTP \(statusCode)")
        if let body, !body.isEmpty {
            print("[\(tag)] \(body)")
        } else {
            print("[\(tag)] (empty response)")
        }
        print("=======================================")
    }

    static func logError(tag: String, error: Error) {
        print("[\(tag)] Request failed: \(error.localizedDescription)")
    }
}
