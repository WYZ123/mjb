import SwiftUI
import UIKit

struct WishDailyCheckInCard: View {
    let wishes: [Wish]
    let makeupDays: Set<Date>
    let grantMonths: [String]
    let protectionEnabled: Bool
    let onMakeup: (Date) -> Void

    private var today: WishCheckDay {
        WishCheckIn.day(wishes: wishes, makeupDays: makeupDays, on: .now)
    }

    private var streak: Int {
        WishCheckIn.streak(wishes: wishes, makeupDays: makeupDays)
    }

    private var badges: [WishStreakBadge] {
        WishCheckIn.badges(streak: streak)
    }

    private var makeupDay: Date? {
        WishCheckIn.makeupCandidate(
            wishes: wishes,
            makeupDays: makeupDays,
            grantMonths: grantMonths,
            protectionEnabled: protectionEnabled
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WishSectionHeading(
                title: "Daily check-in",
                subtitle: "Meet today's save goal to light the badge. The wall fills as the streak grows."
            )
            WishSurfaceCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 14) {
                        todayBadge
                        VStack(alignment: .leading, spacing: 4) {
                            Text(today.status == .met ? "Today is lit" : "Today")
                                .font(.system(.title3, design: .serif).weight(.semibold))
                                .foregroundStyle(WishTheme.ink)
                            Text(todayLine)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(WishTheme.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(streakLine)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(streak > 0 ? WishTheme.seal : WishTheme.secondary)
                        }
                        Spacer(minLength: 0)
                    }

                    if let makeupDay {
                        Button {
                            onMakeup(makeupDay)
                        } label: {
                            Text("Use makeup for \(WishFormat.monthDay(makeupDay))")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(WishTheme.onSeal)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(WishTheme.seal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(WishPressableStyle())
                        Text("This month's one makeup day. It keeps the streak without adding money.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(WishTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if !protectionEnabled, WishCheckIn.makeupCandidate(wishes: wishes, makeupDays: makeupDays, grantMonths: grantMonths, protectionEnabled: true) != nil {
                        Text("Streak protection in More gives one makeup day each month.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(WishTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    achievementWall
                }
            }
        }
    }

    private var todayBadge: some View {
        let lit = today.status == .met
        return ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(lit ? WishTheme.seal : WishTheme.track)
                .frame(width: 72, height: 72)
            Image(systemName: lit ? "checkmark.seal.fill" : "seal")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(lit ? WishTheme.onSeal : WishTheme.secondary)
                .symbolEffect(.bounce, value: lit)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(lit ? "Today's badge is lit" : "Today's badge is not lit")
    }

    private var todayLine: String {
        if wishes.isEmpty {
            return "Add a wish to set today's goal."
        }
        if today.target <= 0.009 {
            return "No open daily goal. Finished wishes no longer count."
        }
        return "Saved \(WishFormat.money(today.saved)) of \(WishFormat.money(today.target))."
    }

    private var streakLine: String {
        let noun = streak == 1 ? "day" : "days"
        if today.status == .met {
            return "\(streak) \(noun) in a row."
        }
        if streak == 0 {
            return "No streak yet."
        }
        return "\(streak) \(noun) in a row. Today is still open."
    }

    private var achievementWall: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Achievement wall")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(WishTheme.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(badges) { badge in
                        VStack(spacing: 6) {
                            Image(systemName: badge.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(badge.earned ? WishTheme.onSeal : WishTheme.secondary)
                                .frame(width: 44, height: 44)
                                .background(
                                    badge.earned ? WishTheme.seal : WishTheme.track,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                            Text(badge.title)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(WishTheme.ink)
                            Text("\(badge.days)d")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(WishTheme.secondary)
                        }
                        .frame(width: 64)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(badge.title), \(badge.days) days")
                        .accessibilityValue(badge.earned ? "Earned" : "Locked")
                    }
                }
            }
        }
    }
}

struct WishCheckInHeatmap: View {
    let wishes: [Wish]
    let makeupDays: Set<Date>

    private var grid: (symbols: [String], columns: [WishHeatWeek]) {
        WishCheckIn.heatmap(wishes: wishes, makeupDays: makeupDays)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WishSectionHeading(
                title: "Check-in heatmap",
                subtitle: "Each square is a day. Darker means more of that day's goal was saved."
            )
            WishSurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 4) {
                        VStack(spacing: 3) {
                            ForEach(Array(grid.symbols.enumerated()), id: \.offset) { _, symbol in
                                Text(symbol)
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(WishTheme.secondary)
                                    .frame(width: 12, height: 13)
                            }
                        }
                        HStack(alignment: .top, spacing: 3) {
                            ForEach(grid.columns) { week in
                                VStack(spacing: 3) {
                                    ForEach(week.days) { day in
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .fill(fill(for: day))
                                            .frame(width: 13, height: 13)
                                    }
                                }
                            }
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Check-in heatmap")
                    .accessibilityValue(summary)
                    }

                    HStack(spacing: 12) {
                        legendSwatch(color: WishTheme.seal.opacity(0.18), title: "Missed")
                        legendSwatch(color: WishTheme.seal.opacity(0.55), title: "Partial")
                        legendSwatch(color: WishTheme.seal, title: "Done")
                        legendSwatch(color: WishTheme.sage, title: "Makeup")
                    }
                }
            }
        }
    }

    private var summary: String {
        let days = grid.columns.flatMap(\.days).filter { $0.status == .met || $0.status == .makeup }
        return "\(days.count) days met the goal in this window."
    }

    private func fill(for day: WishCheckDay) -> Color {
        switch day.status {
        case .future:
            return WishTheme.track.opacity(0.35)
        case .none:
            return WishTheme.track
        case .makeup:
            return WishTheme.sage
        case .missed, .partial, .met:
            return WishTheme.seal.opacity(0.16 + 0.84 * day.heat)
        }
    }

    private func legendSwatch(color: Color, title: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(WishTheme.secondary)
        }
    }
}

struct WishMonthReportCard: View {
    let wishes: [Wish]
    let makeupDays: Set<Date>

    private var report: WishMonthReport {
        WishCheckIn.report(wishes: wishes, makeupDays: makeupDays)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WishSectionHeading(
                title: "Monthly report",
                subtitle: "Efficiency is money saved divided by the daily goals for that month."
            )
            WishSurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(WishFormat.monthYear(report.month))
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundStyle(WishTheme.ink)

                    HStack(spacing: 12) {
                        monthTile(title: "This month", saved: report.saved, efficiency: report.efficiency)
                        monthTile(title: "Last month", saved: report.previousSaved, efficiency: report.hasPrevious ? report.previousEfficiency : nil)
                    }

                    Text(comparisonLine)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(WishTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    if report.nodes.isEmpty {
                        Text("No daily goal in this month yet, so there is nothing to compare.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(WishTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(report.nodes) { node in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(node.kind == .progress ? "Up" : "Down")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(node.kind == .progress ? WishTheme.sage : WishTheme.danger)
                                        .frame(width: 42, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(WishFormat.monthDay(node.day))
                                            .font(.system(.caption, design: .rounded).weight(.semibold))
                                            .foregroundStyle(WishTheme.ink)
                                        Text(node.detail)
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(WishTheme.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var comparisonLine: String {
        guard report.expected > 0.009 else {
            return "This month has no daily goal yet."
        }
        if !report.hasPrevious {
            return "Last month had no daily goal. Turning points below use a 100% daily pace."
        }
        if abs(report.delta) < 0.005 {
            return "Same efficiency as last month, \(WishFormat.percent(report.efficiency))."
        }
        if report.delta > 0 {
            return "\(WishFormat.percent(report.efficiency)) this month, up from \(WishFormat.percent(report.previousEfficiency)) last month."
        }
        return "\(WishFormat.percent(report.efficiency)) this month, down from \(WishFormat.percent(report.previousEfficiency)) last month."
    }

    private func monthTile(title: String, saved: Double, efficiency: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(WishTheme.secondary)
            Text(WishFormat.money(saved))
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(WishTheme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(efficiency.map { WishFormat.percent($0) } ?? "No goal")
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(WishTheme.seal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(WishTheme.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

enum WishAchievementExport {
    @MainActor
    static func image(streak: Int, badges: [WishStreakBadge], todayMet: Bool, saved: Double, target: Double) -> UIImage? {
        let poster = WishAchievementPoster(streak: streak, badges: badges, todayMet: todayMet, saved: saved, target: target)
            .frame(width: 360)
        let renderer = ImageRenderer(content: poster)
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

enum WishSharePresenter {
    @MainActor
    static func present(image: UIImage) {
        let controller = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController ?? scene.windows.first?.rootViewController else { return }
        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(controller, animated: true)
    }
}

private struct WishAchievementPoster: View {
    let streak: Int
    let badges: [WishStreakBadge]
    let todayMet: Bool
    let saved: Double
    let target: Double

    private let paper = Color(hex: 0xF4EFE6)
    private let ink = Color(hex: 0x1C1916)
    private let seal = Color(hex: 0x9E3D22)
    private let onSeal = Color(hex: 0xFFF8F2)
    private let secondary = Color(hex: 0x5E564E)
    private let card = Color(hex: 0xFFFCF7)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Text("W")
                    .font(.custom("Georgia-Bold", size: 28))
                    .foregroundStyle(onSeal)
                    .frame(width: 52, height: 52)
                    .background(seal, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wish Saver")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundStyle(ink)
                    Text("Achievement wall")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(streak)")
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .foregroundStyle(seal)
                    .monospacedDigit()
                Text(streak == 1 ? "day in a row" : "days in a row")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(ink)
                Text(todayLine)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(secondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 10) {
                ForEach(badges) { badge in
                    VStack(spacing: 4) {
                        Image(systemName: badge.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(badge.earned ? onSeal : secondary)
                            .frame(width: 36, height: 36)
                            .background(badge.earned ? seal : Color(hex: 0xE7DDD0), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Text(badge.title)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(ink)
                        Text(badge.earned ? "Earned" : "\(badge.days)d")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            Text(WishFormat.fullDate(.now))
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(secondary)
        }
        .padding(24)
        .background(paper)
    }

    private var todayLine: String {
        if todayMet {
            return "Today's goal is met. Saved \(WishFormat.money(saved))."
        }
        if target <= 0.009 {
            return "No daily goal today."
        }
        return "Today: \(WishFormat.money(saved)) of \(WishFormat.money(target))."
    }
}
