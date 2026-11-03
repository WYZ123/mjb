import Foundation

enum WishCheckStatus: Equatable {
    case none
    case future
    case missed
    case partial
    case met
    case makeup
}

struct WishCheckDay: Identifiable, Equatable {
    var day: Date
    var saved: Double
    var target: Double
    var status: WishCheckStatus

    var id: Date { day }

    var countsForStreak: Bool {
        status == .met || status == .makeup
    }

    var heat: Double {
        switch status {
        case .none, .future:
            return 0
        case .missed:
            return 0.12
        case .partial:
            guard target > 0 else { return 0.4 }
            return min(max(saved / target, 0.35), 0.72)
        case .makeup:
            return 0.82
        case .met:
            return 1
        }
    }
}

struct WishStreakBadge: Identifiable, Equatable {
    let days: Int
    let title: String
    let symbol: String
    var earned: Bool

    var id: Int { days }
}

enum WishPaceNodeKind: Equatable {
    case progress
    case slip
}

struct WishPaceNode: Identifiable, Equatable {
    var day: Date
    var kind: WishPaceNodeKind
    var detail: String

    var id: String { "\(day.timeIntervalSince1970)-\(kind)" }
}

struct WishMonthReport: Equatable {
    var month: Date
    var saved: Double
    var expected: Double
    var efficiency: Double
    var previousSaved: Double
    var previousExpected: Double
    var previousEfficiency: Double
    var hasPrevious: Bool
    var nodes: [WishPaceNode]

    var delta: Double {
        efficiency - previousEfficiency
    }
}

struct WishHeatWeek: Identifiable, Equatable {
    var days: [WishCheckDay]
    var id: Date { days[0].day }
}

enum WishCheckIn {
    static let milestones: [(days: Int, title: String, symbol: String)] = [
        (3, "Spark", "flame.fill"),
        (7, "Week", "calendar"),
        (14, "Fortnight", "seal.fill"),
        (30, "Month", "moon.stars.fill"),
        (60, "Steady", "bolt.fill"),
        (100, "Hundred", "star.fill"),
        (365, "Year", "crown.fill")
    ]

    static func day(
        wishes: [Wish],
        makeupDays: Set<Date>,
        on date: Date,
        now: Date = .now
    ) -> WishCheckDay {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        let saved = saved(wishes: wishes, on: day)
        let target = target(wishes: wishes, on: day)
        if day > today {
            return WishCheckDay(day: day, saved: saved, target: target, status: .future)
        }
        guard target > 0.009 else {
            return WishCheckDay(day: day, saved: saved, target: target, status: .none)
        }
        if saved + 0.009 >= target {
            return WishCheckDay(day: day, saved: saved, target: target, status: .met)
        }
        if makeupDays.contains(day) {
            return WishCheckDay(day: day, saved: saved, target: target, status: .makeup)
        }
        if saved > 0.009 {
            return WishCheckDay(day: day, saved: saved, target: target, status: .partial)
        }
        return WishCheckDay(day: day, saved: saved, target: target, status: .missed)
    }

    static func streak(wishes: [Wish], makeupDays: Set<Date>, now: Date = .now) -> Int {
        let calendar = Calendar.current
        guard let earliest = wishes.map({ calendar.startOfDay(for: $0.createdAt) }).min() else { return 0 }
        var cursor = calendar.startOfDay(for: now)
        let today = day(wishes: wishes, makeupDays: makeupDays, on: cursor, now: now)
        if !today.countsForStreak {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = previous
        }
        var count = 0
        var steps = 0
        while cursor >= earliest, steps < 800 {
            steps += 1
            let item = day(wishes: wishes, makeupDays: makeupDays, on: cursor, now: now)
            if item.status == .none {
                guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = previous
                continue
            }
            guard item.countsForStreak else { break }
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    static func badges(streak: Int) -> [WishStreakBadge] {
        milestones.map { item in
            WishStreakBadge(days: item.days, title: item.title, symbol: item.symbol, earned: streak >= item.days)
        }
    }

    static func monthKey(for date: Date = .now, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    static func makeupCandidate(
        wishes: [Wish],
        makeupDays: Set<Date>,
        grantMonths: [String] = [],
        now: Date = .now,
        protectionEnabled: Bool
    ) -> Date? {
        guard protectionEnabled else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        if grantMonths.contains(monthKey(for: today, calendar: calendar)) {
            return nil
        }
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let earliest = calendar.date(byAdding: .day, value: -40, to: today) else { return nil }
        var cursor = yesterday
        var steps = 0
        while cursor >= earliest, steps < 40 {
            steps += 1
            let item = day(wishes: wishes, makeupDays: makeupDays, on: cursor, now: now)
            if item.status == .missed || item.status == .partial {
                return cursor
            }
            if item.status == .met || item.status == .makeup || item.status == .none {
                guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { return nil }
                cursor = previous
                continue
            }
            return nil
        }
        return nil
    }

    static func makeupUsedThisMonth(days: [Date], grantMonths: [String], now: Date = .now) -> Date? {
        guard grantMonths.contains(monthKey(for: now)) else { return nil }
        return days.max()
    }

    static func heatmap(wishes: [Wish], makeupDays: Set<Date>, now: Date = .now, weeks: Int = 13) -> (symbols: [String], columns: [WishHeatWeek]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let delta = (weekday - calendar.firstWeekday + 7) % 7
        let thisWeek = calendar.date(byAdding: .day, value: -delta, to: today) ?? today
        let start = calendar.date(byAdding: .day, value: -(weeks - 1) * 7, to: thisWeek) ?? thisWeek
        var columns: [WishHeatWeek] = []
        for week in 0..<weeks {
            var days: [WishCheckDay] = []
            for offset in 0..<7 {
                let date = calendar.date(byAdding: .day, value: week * 7 + offset, to: start) ?? start
                days.append(day(wishes: wishes, makeupDays: makeupDays, on: date, now: now))
            }
            columns.append(WishHeatWeek(days: days))
        }
        return (weekdaySymbols(calendar: calendar), columns)
    }

    static func report(wishes: [Wish], makeupDays: Set<Date>, now: Date = .now) -> WishMonthReport {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let current = monthTotals(wishes: wishes, makeupDays: makeupDays, containing: today, through: today, now: now)
        let previousAnchor = calendar.date(byAdding: .month, value: -1, to: today) ?? today
        let previous = monthTotals(wishes: wishes, makeupDays: makeupDays, containing: previousAnchor, through: nil, now: now)
        let baseline = previous.expected > 0.009 ? previous.efficiency : 1
        let nodes = paceNodes(
            wishes: wishes,
            makeupDays: makeupDays,
            containing: today,
            through: today,
            baseline: baseline,
            hasPrevious: previous.expected > 0.009,
            now: now
        )
        return WishMonthReport(
            month: current.start,
            saved: current.saved,
            expected: current.expected,
            efficiency: current.efficiency,
            previousSaved: previous.saved,
            previousExpected: previous.expected,
            previousEfficiency: previous.efficiency,
            hasPrevious: previous.expected > 0.009,
            nodes: nodes
        )
    }

    private static func saved(wishes: [Wish], on day: Date) -> Double {
        let calendar = Calendar.current
        return wishes.reduce(0) { total, wish in
            total + wish.deposits.reduce(0) { partial, deposit in
                calendar.startOfDay(for: deposit.date) == day ? partial + deposit.amount : partial
            }
        }
    }

    private static func target(wishes: [Wish], on day: Date) -> Double {
        let calendar = Calendar.current
        return wishes.reduce(0) { total, wish in
            guard calendar.startOfDay(for: wish.createdAt) <= day, wish.dailySaving > 0 else { return total }
            let savedBefore = wish.deposits.reduce(0) { partial, deposit in
                calendar.startOfDay(for: deposit.date) < day ? partial + deposit.amount : partial
            }
            if savedBefore + 0.009 >= wish.targetAmount {
                return total
            }
            return total + wish.dailySaving
        }
    }

    private static func monthTotals(
        wishes: [Wish],
        makeupDays: Set<Date>,
        containing anchor: Date,
        through limit: Date?,
        now: Date
    ) -> (start: Date, saved: Double, expected: Double, efficiency: Double) {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: anchor)) ?? anchor
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        var cursor = start
        var saved = 0.0
        var expected = 0.0
        while cursor < end {
            if let limit, cursor > calendar.startOfDay(for: limit) { break }
            let item = day(wishes: wishes, makeupDays: makeupDays, on: cursor, now: now)
            if item.status != .none && item.status != .future {
                saved += item.saved
                expected += item.target
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        let efficiency = expected > 0.009 ? saved / expected : 0
        return (start, saved, expected, efficiency)
    }

    private static func paceNodes(
        wishes: [Wish],
        makeupDays: Set<Date>,
        containing anchor: Date,
        through limit: Date,
        baseline: Double,
        hasPrevious: Bool,
        now: Date
    ) -> [WishPaceNode] {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: anchor)) ?? anchor
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        let last = min(calendar.startOfDay(for: limit), calendar.date(byAdding: .day, value: -1, to: end) ?? limit)
        var cursor = start
        var runningSaved = 0.0
        var runningExpected = 0.0
        var above: Bool?
        var nodes: [WishPaceNode] = []
        while cursor <= last {
            let item = day(wishes: wishes, makeupDays: makeupDays, on: cursor, now: now)
            if item.status != .none && item.status != .future && item.target > 0.009 {
                runningSaved += item.saved
                runningExpected += item.target
                let rate = runningExpected > 0 ? runningSaved / runningExpected : 0
                let nowAbove = rate + 0.005 >= baseline
                if let above {
                    if !above && nowAbove {
                        nodes.append(WishPaceNode(
                            day: cursor,
                            kind: .progress,
                            detail: crossDetail(rate: rate, baseline: baseline, ahead: true, hasPrevious: hasPrevious)
                        ))
                    } else if above && !nowAbove {
                        nodes.append(WishPaceNode(
                            day: cursor,
                            kind: .slip,
                            detail: crossDetail(rate: rate, baseline: baseline, ahead: false, hasPrevious: hasPrevious)
                        ))
                    }
                }
                above = nowAbove
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        if nodes.isEmpty, runningExpected > 0.009, let above {
            let rate = runningSaved / runningExpected
            nodes.append(WishPaceNode(
                day: last,
                kind: above ? .progress : .slip,
                detail: above
                    ? "Stayed ahead of \(comparisonName(hasPrevious: hasPrevious)) all month, at \(WishFormat.percent(rate))."
                    : "Stayed behind \(comparisonName(hasPrevious: hasPrevious)) all month, at \(WishFormat.percent(rate))."
            ))
        }
        if nodes.count > 6 {
            return Array(nodes.suffix(6))
        }
        return nodes
    }

    private static func crossDetail(rate: Double, baseline: Double, ahead: Bool, hasPrevious: Bool) -> String {
        let name = comparisonName(hasPrevious: hasPrevious)
        if ahead {
            return "Running efficiency reached \(WishFormat.percent(rate)), past \(name) at \(WishFormat.percent(baseline))."
        }
        return "Running efficiency fell to \(WishFormat.percent(rate)), behind \(name) at \(WishFormat.percent(baseline))."
    }

    private static func comparisonName(hasPrevious: Bool) -> String {
        hasPrevious ? "last month" : "a full daily pace"
    }

    private static func weekdaySymbols(calendar: Calendar) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.calendar = calendar
        let symbols = formatter.veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        let start = calendar.firstWeekday - 1
        return (0..<7).map { symbols[($0 + start) % symbols.count] }
    }
}
