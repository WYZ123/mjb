import Foundation

enum WishJPush {
    /// JPush console AppKey for this app. An empty key skips setup and does not ask for notification permission.
    static let appKey = "a57a6564ce968d9c10707734"
    static let channel = "App Store"

    static var isConfigured: Bool {
        !appKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static var isProduction: Bool {
        #if DEBUG
        false
        #else
        true
        #endif
    }
}

@MainActor
final class WishJPushCenter: ObservableObject {
    static let shared = WishJPushCenter()

    @Published private(set) var registrationID = ""
    @Published private(set) var statusText = ""

    private init() {
        if !WishJPush.isConfigured {
            statusText = "Paste the JPush console AppKey into WishJPush.appKey, upload the APNs key, then run on a device."
        }
    }

    func apply(code: Int, registrationID: String?) {
        let identifier = registrationID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !identifier.isEmpty else {
            self.registrationID = ""
            if code == 1011 {
                statusText = "The simulator has no APNs. The Registration ID only appears on a device."
            } else {
                statusText = "Still registering with JPush. Run on a device and check that the AppKey matches the APNs key."
            }
            return
        }
        self.registrationID = identifier
        statusText = "Paste this ID into the JPush console to send a test notification to this phone."
    }
}
