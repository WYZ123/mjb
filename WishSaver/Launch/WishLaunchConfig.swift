import Foundation

enum WishLaunchConfig {
    static var forceMainApp: Bool {
        ProcessInfo.processInfo.arguments.contains("-AppStoreScreenshot")
    }
}
