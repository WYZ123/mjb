import Foundation
import SwiftUI
import UserNotifications

enum WishPreferenceKey {
    static let appearance = "wish.appearance"
    static let haptics = "wish.haptics"
    static let hideCompleted = "wish.hideCompleted"
    static let reminderOn = "wish.reminderOn"
    static let reminderHour = "wish.reminderHour"
    static let reminderMinute = "wish.reminderMinute"
    static let tutorialSeen = "wish.tutorialSeen.en"
    static let streakProtection = "wish.streakProtection"
}

enum WishAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum WishReminder {
    static let identifier = "wish.daily"

    @MainActor
    static func refreshSaved() async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: WishPreferenceKey.reminderOn) else { return }
        let hour = defaults.object(forKey: WishPreferenceKey.reminderHour) as? Int ?? 21
        let minute = defaults.object(forKey: WishPreferenceKey.reminderMinute) as? Int ?? 0
        _ = await update(enabled: true, hour: hour, minute: minute, requestIfNeeded: false)
    }

    @MainActor
    static func update(enabled: Bool, hour: Int, minute: Int, requestIfNeeded: Bool) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard enabled else { return true }

        let allowed = await authorizationGranted(requestIfNeeded: requestIfNeeded)
        guard allowed else { return false }

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let content = UNMutableNotificationContent()
        content.title = "Save today's amount"
        content.body = "Open Wish Saver and log today's amount. Save before you spend."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

    private static func authorizationGranted(requestIfNeeded: Bool) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            guard requestIfNeeded else { return false }
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
}
