import Foundation

enum WishAPIConfig {
    static let baseURL = "https://api.sun-damage.com/api/public"

    static func publicEndpoint(_ path: String) -> URL {
        URL(string: "\(baseURL)/\(path)")!
    }
}
