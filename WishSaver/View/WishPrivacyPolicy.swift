import SwiftUI

struct WishPrivacyPolicy: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    WishPageHeader(
                        title: "Privacy Policy",
                        detail: "Updated October 21, 2026. Applies to the version shown in More."
                    )

                    policyCard(
                        title: "The ledger stays on this phone",
                        paragraphs: [
                            "Wish names, target amounts, estimated days, daily savings, spending categories, and every deposit are stored in this app's folder on the device. Wish Saver has no account and does not upload these records to our servers.",
                            "Appearance, haptics, and the daily reminder time also stay on this phone. They are removed from the device when you tap Delete all data or uninstall the app."
                        ]
                    )

                    policyCard(
                        title: "Notifications",
                        paragraphs: [
                            "The daily reminder is a local system notification. It only sounds on this phone and does not go through a server. You can turn it off in More, or turn off notification permission in the system Settings.",
                            "Remote push uses JPush. The app connects to JPush only after an AppKey is entered and setup finishes. With no AppKey, it does not connect to JPush and does not ask for notification permission for that."
                        ]
                    )

                    policyCard(
                        title: "What JPush receives",
                        paragraphs: [
                            "After setup, JPush receives what it needs to deliver a notification, including the device model, system version, network status, push token, and Registration ID. The Registration ID identifies Wish Saver on this phone. It is not your name and it is not an account.",
                            "Wish details, amounts, and spending are not uploaded with the push. We do not ask for tracking permission and we do not send an advertising identifier to JPush. Collection of location, Wi-Fi name, and cell information is turned off.",
                            "You can turn notifications off in the system Settings. After that, JPush can no longer deliver a notification to this phone."
                        ]
                    )

                    policyCard(
                        title: "Export and sharing",
                        paragraphs: [
                            "A text record is created only when you tap Export ledger, and it is handed to the system share sheet. You choose who receives it. We do not share it automatically."
                        ]
                    )
                }
                .modifier(WishReadableColumn())
            }
            .background(WishTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                WishPrimaryButton(title: "OK") {
                    dismiss()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(WishTheme.background.ignoresSafeArea())
            }
        }
    }

    private func policyCard(title: String, paragraphs: [String]) -> some View {
        WishSurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(WishTheme.ink)
                ForEach(paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(WishTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
