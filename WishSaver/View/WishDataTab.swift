import Charts
import SwiftUI

struct WishDataTab: View {
    @EnvironmentObject private var store: WishStore
    @State private var dayCount = 7

    var body: some View {
        WishTabScreen {
            WishPageHeader(
                tab: .data,
                title: "Pace",
                detail: "A check-in heatmap, this month against last month, and each day's share of everything saved."
            )

            if store.wishes.isEmpty {
                WishSurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nothing to summarize yet")
                            .font(.system(.title3, design: .serif).weight(.semibold))
                            .foregroundStyle(WishTheme.ink)
                        Text("Write a wish on New. After a deposit, this page shows the check-in heatmap, the monthly report, and achievement.")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(WishTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                WishCheckInHeatmap(wishes: store.wishes, makeupDays: store.makeupDaySet)
                WishMonthReportCard(wishes: store.wishes, makeupDays: store.makeupDaySet)
                depositSection
                achievementSection
            }
        }
    }

    private var days: [WishDayTotal] {
        store.recentDays(count: dayCount)
    }

    private var windowAmount: Double {
        days.reduce(0) { $0 + $1.amount }
    }

    private var windowShare: Double {
        days.reduce(0) { $0 + $1.share }
    }

    private var depositSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            WishSectionHeading(
                title: "Daily deposits",
                subtitle: "Saved in total \(WishFormat.money(store.totalSaved)). Shares use that total, not only the days in the chart."
            )
            Picker("Range", selection: $dayCount) {
                Text("7 days").tag(7)
                Text("30 days").tag(30)
            }
            .pickerStyle(.segmented)

            WishSurfaceCard {
                if store.totalSaved <= 0.009 {
                    Text("After the first deposit, this chart shows each day's amount and its share of everything saved.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(WishTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        depositChart
                        Text("These \(dayCount) days saved \(WishFormat.money(windowAmount)), \(WishFormat.percent(windowShare)) of the total.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(WishTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if windowShare + 0.005 < 1 {
                            Text("Earlier deposits are part of the total, so these \(dayCount) bars do not add up to 100%.")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(WishTheme.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        dayList
                    }
                }
            }
        }
    }

    private var depositChart: some View {
        let peak = days.map(\.amount).max() ?? 0
        let ceiling = peak > 0 ? peak * 1.35 : 1
        return Chart(days) { day in
            BarMark(
                x: .value("Date", day.day, unit: .day),
                y: .value("Amount", day.amount)
            )
            .foregroundStyle(WishTheme.seal.gradient)
            .cornerRadius(5)
            .annotation(position: .top, spacing: 2) {
                if day.amount > 0, dayCount <= 7 {
                    Text(WishFormat.percent(day.share))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(WishTheme.ink)
                        .monospacedDigit()
                }
            }
        }
        .chartYScale(domain: 0...ceiling)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: dayCount > 7 ? 5 : 1)) { value in
                AxisGridLine().foregroundStyle(Color.clear)
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(axisDay(date))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(WishTheme.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(WishTheme.line)
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(WishFormat.axisAmount(amount))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(WishTheme.secondary)
                    }
                }
            }
        }
        .frame(height: 230)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily deposit chart")
        .accessibilityValue(chartVoice)
    }

    private var dayList: some View {
        let recorded = days.filter { $0.amount > 0.009 }.reversed()
        return VStack(alignment: .leading, spacing: 10) {
            if recorded.isEmpty {
                Text("No deposits in these \(dayCount) days.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(WishTheme.secondary)
            } else {
                ForEach(Array(recorded)) { day in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(WishFormat.monthDay(day.day))
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(WishTheme.ink)
                            Spacer()
                            Text(WishFormat.money(day.amount))
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                                .foregroundStyle(WishTheme.ink)
                                .monospacedDigit()
                            Text(WishFormat.percent(day.share))
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(WishTheme.secondary)
                                .frame(width: 52, alignment: .trailing)
                                .monospacedDigit()
                        }
                        WishProgressTrack(progress: day.share, tint: WishTheme.seal, height: 6)
                    }
                }
            }
        }
    }

    private var achievementSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            WishSectionHeading(
                title: "Pace against the estimate",
                subtitle: "Achievement is saved amount divided by what an even pace would have saved by today. Over 100% means ahead of plan."
            )
            ForEach(store.orderedWishes) { wish in
                WishAchievementCard(wish: wish)
            }
        }
    }

    private var chartVoice: String {
        days.filter { $0.amount > 0 }.map {
            "\(WishFormat.monthDay($0.day)) \(WishFormat.money($0.amount)), \(WishFormat.percent($0.share)) of the total"
        }.joined(separator: "，")
    }

    private func axisDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = dayCount > 7 ? "M/d" : "d"
        return formatter.string(from: date)
    }
}

private struct WishAchievementCard: View {
    let wish: Wish

    var body: some View {
        WishSurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(wish.name)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(WishTheme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(WishFormat.percent(wish.achievementRate))
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(rateColor)
                        .monospacedDigit()
                }
                WishProgressTrack(progress: min(wish.achievementRate, 1), tint: rateColor)
                Text("\(wish.daysElapsed) days in / \(wish.estimatedDays) planned · expected \(WishFormat.money(wish.expectedSaved)) · saved \(WishFormat.money(wish.savedAmount))")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(WishTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if wish.isComplete {
                    Text("The target is saved.")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(WishTheme.sage)
                } else if wish.isPastEstimate {
                    Text("Past the estimate, with \(WishFormat.money(wish.remaining)) left.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(WishTheme.seal)
                } else if wish.achievementRate + 0.001 >= 1 {
                    Text("Ahead of the estimated pace.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(WishTheme.sage)
                }
            }
        }
    }

    private var rateColor: Color {
        if wish.isComplete || wish.achievementRate + 0.001 >= 1 {
            return WishTheme.sage
        }
        if wish.achievementRate >= 0.7 {
            return WishTheme.seal
        }
        return WishTheme.danger
    }
}
