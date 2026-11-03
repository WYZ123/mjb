import SwiftUI
import UIKit

struct WishSettingsTab: View {
    @EnvironmentObject private var store: WishStore
    @AppStorage(WishPreferenceKey.appearance) private var appearanceRaw = WishAppearance.system.rawValue
    @AppStorage(WishPreferenceKey.haptics) private var hapticsEnabled = true
    @AppStorage(WishPreferenceKey.hideCompleted) private var hideCompleted = false
    @AppStorage(WishPreferenceKey.reminderOn) private var reminderOn = false
    @AppStorage(WishPreferenceKey.reminderHour) private var reminderHour = 21
    @AppStorage(WishPreferenceKey.reminderMinute) private var reminderMinute = 0
    @AppStorage(WishPreferenceKey.streakProtection) private var streakProtection = false

    @State private var confirmDelete = false
    @State private var didDelete = false
    @State private var reminderDenied = false
    @State private var showPrivacyPolicy = false
    @State private var showTutorial = false

    private var appearance: WishAppearance {
        WishAppearance(rawValue: appearanceRaw) ?? .system
    }

    private var reminderDate: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? .now
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderHour = parts.hour ?? 21
                reminderMinute = parts.minute ?? 0
            }
        )
    }

    var body: some View {
        WishTabScreen {
            WishPageHeader(
                tab: .settings,
                title: "More",
                detail: "Appearance, reminders, the achievement wall, and the ledger that stays on this phone."
            )

            WishSurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Appearance")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(WishTheme.secondary)
                    HStack(spacing: 8) {
                        ForEach(WishAppearance.allCases) { item in
                            Button {
                                appearanceRaw = item.rawValue
                            } label: {
                                Text(item.title)
                                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                                    .foregroundStyle(appearance == item ? WishTheme.onSeal : WishTheme.ink)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        appearance == item ? WishTheme.seal : WishTheme.background,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                            }
                            .buttonStyle(WishPressableStyle())
                        }
                    }

                    Divider().overlay(WishTheme.line)

                    WishToggleRow(
                        title: "Haptics",
                        detail: "A light tap when you save or delete.",
                        isOn: $hapticsEnabled
                    )

                    Divider().overlay(WishTheme.line)

                    WishToggleRow(
                        title: "Hide completed",
                        detail: "Keep finished wishes out of the Wishes list. Overview and Pace still include them.",
                        isOn: $hideCompleted
                    )
                }
            }

            WishSurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    WishToggleRow(
                        title: "Daily reminder",
                        detail: "A reminder to log today's amount.",
                        isOn: $reminderOn
                    )
                    if reminderOn {
                        HStack {
                            Text("Reminder time")
                                .font(.system(.body, design: .rounded).weight(.medium))
                                .foregroundStyle(WishTheme.ink)
                            Spacer()
                            DatePicker("Reminder time", selection: reminderDate, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
                }
            }

            WishSurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    WishToggleRow(
                        title: "Streak protection",
                        detail: "Each month includes one makeup day. Use it on Wishes after a missed day. It keeps the streak and does not add money.",
                        isOn: $streakProtection
                    )
                    Text(makeupStatus)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(WishTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Button {
                    let today = WishCheckIn.day(wishes: store.wishes, makeupDays: store.makeupDaySet, on: .now)
                    let streak = WishCheckIn.streak(wishes: store.wishes, makeupDays: store.makeupDaySet)
                    guard let image = WishAchievementExport.image(
                        streak: streak,
                        badges: WishCheckIn.badges(streak: streak),
                        todayMet: today.status == .met,
                        saved: today.saved,
                        target: today.target
                    ) else { return }
                    WishSharePresenter.present(image: image)
                } label: {
                    settingButtonLabel("Share achievement wall", role: .normal)
                }
                .buttonStyle(WishPressableStyle())

                Text("Makes a picture of the streak and badges, then opens the share sheet. Wish Saver does not upload it.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(WishTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ShareLink(item: store.ledgerText, subject: Text("Wish Saver")) {
                    settingButtonLabel("Export ledger", role: .normal)
                }
                .buttonStyle(WishPressableStyle())

                Text("Export a text record of each wish, including progress, spending, and achievement.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(WishTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    WishHaptics.warning()
                    confirmDelete = true
                } label: {
                    settingButtonLabel("Delete all data", role: store.wishes.isEmpty ? .quiet : .danger)
                }
                .buttonStyle(WishPressableStyle())
                .disabled(store.wishes.isEmpty)

                Text(store.wishes.isEmpty ? "There are no wishes or deposits right now." : "This removes every wish, spending category, and deposit. It cannot be undone.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(WishTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if didDelete && store.wishes.isEmpty {
                    Text("All data has been deleted.")
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(WishTheme.sage)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                WishSectionHeading(title: "About")
                WishSurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            Image("WishAppIcon")
                                .resizable()
                                .interpolation(.high)
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .accessibilityLabel("Wish Saver icon")
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Wish Saver")
                                    .font(.system(.title3, design: .serif).weight(.semibold))
                                    .foregroundStyle(WishTheme.ink)
                                Text("Turn a wish into a daily amount")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(WishTheme.secondary)
                            }
                        }

                        Divider().overlay(WishTheme.line)

                        HStack {
                            Text("Version")
                                .font(.system(.body, design: .rounded).weight(.medium))
                                .foregroundStyle(WishTheme.ink)
                            Spacer()
                            Text(versionText)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(WishTheme.secondary)
                        }

                        Divider().overlay(WishTheme.line)

                        Button {
                            showTutorial = true
                        } label: {
                            HStack {
                                Text("Tutorial")
                                    .font(.system(.body, design: .rounded).weight(.medium))
                                    .foregroundStyle(WishTheme.ink)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(WishTheme.secondary)
                            }
                        }
                        .buttonStyle(WishPressableStyle())

                        Divider().overlay(WishTheme.line)

                        Button {
                            showPrivacyPolicy = true
                        } label: {
                            HStack {
                                Text("Privacy Policy")
                                    .font(.system(.body, design: .rounded).weight(.medium))
                                    .foregroundStyle(WishTheme.ink)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(WishTheme.secondary)
                            }
                        }
                        .buttonStyle(WishPressableStyle())

                        Divider().overlay(WishTheme.line)

                        Text("Wish Saver breaks something you want into an amount you can save each day.")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(WishTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("You enter a target, estimated days, a daily amount, and spending by category. Wishes shows how long is left. Pace shows each day's share of everything saved, and whether you are on pace.")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(WishTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("The saving tips use the numbers you entered: what is left, which category is largest, and how much less to spend. These records are not uploaded. They stay on this phone.")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(WishTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .onChange(of: reminderOn) { _, enabled in
            Task { await applyReminder(enabled: enabled, requestIfNeeded: true) }
        }
        .onChange(of: reminderHour) { _, _ in
            guard reminderOn else { return }
            Task { await applyReminder(enabled: true, requestIfNeeded: false) }
        }
        .onChange(of: reminderMinute) { _, _ in
            guard reminderOn else { return }
            Task { await applyReminder(enabled: true, requestIfNeeded: false) }
        }
        .alert("Reminders are off", isPresented: $reminderDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Notification permission is off. Turn on notifications in Settings to get the daily reminder.")
        }
        .fullScreenCover(isPresented: $showTutorial) {
            WishTutorialView {
                showTutorial = false
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            WishPrivacyPolicy()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Delete all data?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete all", role: .destructive) {
                store.deleteAll()
                didDelete = true
                WishHaptics.warning()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every wish, spending category, and deposit will be removed. This cannot be undone.")
        }
    }

    private func applyReminder(enabled: Bool, requestIfNeeded: Bool) async {
        let granted = await WishReminder.update(
            enabled: enabled,
            hour: reminderHour,
            minute: reminderMinute,
            requestIfNeeded: requestIfNeeded
        )
        guard enabled, !granted else { return }
        reminderOn = false
        reminderDenied = true
    }

    private func settingButtonLabel(_ title: String, role: SettingRole) -> some View {
        Text(title)
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundStyle(role.foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(WishTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(role.stroke, lineWidth: 1)
            }
    }

    private var makeupStatus: String {
        guard streakProtection else {
            return "Off. Turn it on and this month's makeup day is ready to use."
        }
        if let used = WishCheckIn.makeupUsedThisMonth(days: store.makeupDays, grantMonths: store.makeupGrantMonths) {
            return "Used on \(WishFormat.monthDay(used)). A new one arrives next month."
        }
        return "1 makeup left in \(WishFormat.monthYear(.now))."
    }

    private var versionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.1"
    }

    private enum SettingRole {
        case normal
        case danger
        case quiet

        var foreground: Color {
            switch self {
            case .normal: WishTheme.ink
            case .danger: WishTheme.danger
            case .quiet: WishTheme.secondary
            }
        }

        var stroke: Color {
            switch self {
            case .normal: WishTheme.line
            case .danger: WishTheme.danger.opacity(0.45)
            case .quiet: WishTheme.line
            }
        }
    }
}

private struct WishToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(WishTheme.ink)
                Text(detail)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(WishTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(WishTheme.seal)
    }
}
