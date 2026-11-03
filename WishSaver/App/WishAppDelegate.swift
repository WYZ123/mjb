import UIKit
import UserNotifications

final class WishAppDelegate: NSObject, UIApplicationDelegate, JPUSHRegisterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        guard WishJPush.isConfigured else { return true }

        let control = JPushCollectControl()
        control.ssid = false
        control.bssid = false
        control.cell = false
        control.gps = false
        JPUSHService.setCollectControl(control)
        JPUSHService.setLocationEanable(false)
        JPUSHService.setDataInsightsEnable(false)
        JPUSHService.setSmartPushEnable(false)

        let entity = JPUSHRegisterEntity()
        let options: JPAuthorizationOptions = [.alert, .badge, .sound, .providesAppNotificationSettings]
        entity.types = Int(options.rawValue)
        JPUSHService.register(forRemoteNotificationConfig: entity, delegate: self)
        JPUSHService.setup(
            withOption: launchOptions,
            appKey: WishJPush.appKey,
            channel: WishJPush.channel,
            apsForProduction: WishJPush.isProduction,
            advertisingIdentifier: nil
        )
        #if DEBUG
        JPUSHService.setDebugMode()
        #endif

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(jpushDidLogin),
            name: .jpfNetworkDidLogin,
            object: nil
        )
        refreshRegistrationID()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        guard WishJPush.isConfigured else { return }
        JPUSHService.registerDeviceToken(deviceToken)
        refreshRegistrationID()
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            guard WishJPushCenter.shared.registrationID.isEmpty else { return }
            #if targetEnvironment(simulator)
            WishJPushCenter.shared.apply(code: 1011, registrationID: nil)
            #else
            WishJPushCenter.shared.apply(code: Int(JPUSHPushRegistrationErrorCode.internal.rawValue), registrationID: nil)
            #endif
        }
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if WishJPush.isConfigured {
            JPUSHService.handleRemoteNotification(userInfo)
        }
        completionHandler(.newData)
    }

    func jpushNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (Int) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        if WishJPush.isConfigured, notification.request.trigger is UNPushNotificationTrigger {
            JPUSHService.handleRemoteNotification(userInfo)
        }
        let presentation = UNNotificationPresentationOptions([.banner, .list, .sound, .badge])
        completionHandler(Int(presentation.rawValue))
    }

    func jpushNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if WishJPush.isConfigured, response.notification.request.trigger is UNPushNotificationTrigger {
            JPUSHService.handleRemoteNotification(userInfo)
        }
        completionHandler()
    }

    func jpushNotificationCenter(
        _ center: UNUserNotificationCenter,
        openSettingsFor notification: UNNotification
    ) {}

    func jpushNotificationAuthorization(
        _ status: JPAuthorizationStatus,
        withInfo info: [AnyHashable: Any]?
    ) {}

    @objc private func jpushDidLogin() {
        refreshRegistrationID()
    }

    private func refreshRegistrationID() {
        JPUSHService.registrationIDCompletionHandler { code, registrationID in
            Task { @MainActor in
                WishJPushCenter.shared.apply(code: Int(code), registrationID: registrationID)
            }
        }
    }
}
