import Foundation
import Security

enum WishKeychainStore {
    static func save(key: String, data: Data) -> Bool {
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        guard status == errSecSuccess else { return nil }
        return dataTypeRef as? Data
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum WishDeviceIdentity {
    private static let key = "com.wangyao.wishsaver.device.unique.id"

    /// Set to `true` to rotate the UDID for testing; set back to `false` when done.
    private static let forceRefreshForTesting = false
    private static var didApplyTestRefresh = false

    static func getUniqueID() -> String {
        if forceRefreshForTesting && !didApplyTestRefresh {
            WishKeychainStore.delete(key: key)
            didApplyTestRefresh = true
        }

        if let existingData = WishKeychainStore.load(key: key),
           let uuidString = String(data: existingData, encoding: .utf8),
           !uuidString.isEmpty {
            return uuidString
        }

        let newUUID = UUID().uuidString
        if let data = newUUID.data(using: .utf8), WishKeychainStore.save(key: key, data: data) {
            return newUUID
        }

        return UUID().uuidString
    }
}

enum WishAppMetadata {
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.1"
    }
}
