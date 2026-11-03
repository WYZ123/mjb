import SwiftUI

@main
struct WishSaverApp: App {
    @UIApplicationDelegateAdaptor(WishAppDelegate.self) private var appDelegate
    @StateObject private var store = WishStore()
    @StateObject private var launchRouter = WishLaunchRouter()

    init() {
        WishTheme.applyTabBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            WishLaunchRootView()
                .environmentObject(store)
                .environmentObject(launchRouter)
                .environment(\.locale, Locale(identifier: "en_US"))
                .tint(WishTheme.seal)
        }
    }
}
