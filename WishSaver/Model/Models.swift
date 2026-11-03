import Foundation

enum WishNameCategory: String, Codable, CaseIterable, Identifiable {
    case digital = "tech"
    case travel = "travel"
    case sport = "sports"
    case home = "home"
    case clothing = "clothes"
    case study = "study"
    case other = "other"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .digital: "Tech"
        case .travel: "Travel"
        case .sport: "Sports"
        case .home: "Home"
        case .clothing: "Clothes"
        case .study: "Study"
        case .other: "Other"
        }
    }

    func resolvedName(custom: String) -> String {
        custom.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func stored(name: String) -> (category: WishNameCategory, custom: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let preset = allCases.first(where: { $0 != .other && ($0.rawValue == trimmed || $0.title == trimmed || $0.legacyNames.contains(trimmed)) }) {
            return (preset, "")
        }
        return (.other, trimmed)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let match = Self(rawValue: raw) ?? Self.legacy[raw] {
            self = match
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown wish category \(raw)")
    }

    private var legacyNames: [String] {
        switch self {
        case .digital: ["数码"]
        case .travel: ["旅行"]
        case .sport: ["运动"]
        case .home: ["家居"]
        case .clothing: ["服饰"]
        case .study: ["学习"]
        case .other: ["其他"]
        }
    }

    private static let legacy: [String: WishNameCategory] = [
        "数码": .digital,
        "旅行": .travel,
        "运动": .sport,
        "家居": .home,
        "服饰": .clothing,
        "学习": .study,
        "其他": .other
    ]
}

enum WishDurationUnit: Int, CaseIterable, Identifiable {
    case day = 1
    case week = 7
    case month = 30
    case year = 365

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }

    func days(count: Int) -> Int? {
        let safe = max(count, 1)
        let total = safe * rawValue
        guard total > 0, total < 100_000 else { return nil }
        return total
    }

    static func split(_ days: Int) -> (count: Int, unit: WishDurationUnit) {
        let safe = max(days, 1)
        for unit in [WishDurationUnit.year, .month, .week] where safe.isMultiple(of: unit.rawValue) {
            return (safe / unit.rawValue, unit)
        }
        return (safe, .day)
    }
}

enum WishExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case food = "food"
    case transport = "transport"
    case shopping = "shopping"
    case entertainment = "fun"
    case housing = "housing"
    case other = "other"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: "Food"
        case .transport: "Transport"
        case .shopping: "Shopping"
        case .entertainment: "Fun"
        case .housing: "Housing"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .food: "fork.knife"
        case .transport: "tram.fill"
        case .shopping: "bag.fill"
        case .entertainment: "sparkles"
        case .housing: "house.fill"
        case .other: "ellipsis.circle.fill"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let match = Self(rawValue: raw) ?? Self.legacy[raw] {
            self = match
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown expense category \(raw)")
    }

    private static let legacy: [String: WishExpenseCategory] = [
        "餐饮": .food,
        "交通": .transport,
        "购物": .shopping,
        "娱乐": .entertainment,
        "居住": .housing,
        "其他": .other
    ]
}

struct WishExpenseSlice: Codable, Identifiable, Hashable {
    var id: UUID
    var category: WishExpenseCategory
    var amount: Double

    init(id: UUID = UUID(), category: WishExpenseCategory, amount: Double) {
        self.id = id
        self.category = category
        self.amount = amount
    }
}

struct WishDeposit: Codable, Identifiable, Hashable {
    var id: UUID
    var amount: Double
    var date: Date

    init(id: UUID = UUID(), amount: Double, date: Date = .now) {
        self.id = id
        self.amount = amount
        self.date = date
    }
}

struct Wish: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var nameCategory: WishNameCategory?
    var targetAmount: Double
    var estimatedDays: Int
    var dailySaving: Double
    var expenses: [WishExpenseSlice]
    var createdAt: Date
    var deposits: [WishDeposit]
    /// Lower numbers appear first. Missing values in older files are filled in on load.
    var sortIndex: Int

    init(
        id: UUID = UUID(),
        name: String,
        nameCategory: WishNameCategory? = nil,
        targetAmount: Double,
        estimatedDays: Int,
        dailySaving: Double,
        expenses: [WishExpenseSlice],
        createdAt: Date = .now,
        deposits: [WishDeposit] = [],
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.nameCategory = nameCategory
        self.targetAmount = targetAmount
        self.estimatedDays = estimatedDays
        self.dailySaving = dailySaving
        self.expenses = expenses
        self.createdAt = createdAt
        self.deposits = deposits
        self.sortIndex = sortIndex
    }

    enum CodingKeys: String, CodingKey {
        case id, name, nameCategory, targetAmount, estimatedDays, dailySaving, expenses, createdAt, deposits, sortIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        nameCategory = try container.decodeIfPresent(WishNameCategory.self, forKey: .nameCategory)
        targetAmount = try container.decode(Double.self, forKey: .targetAmount)
        estimatedDays = try container.decode(Int.self, forKey: .estimatedDays)
        dailySaving = try container.decode(Double.self, forKey: .dailySaving)
        expenses = try container.decode([WishExpenseSlice].self, forKey: .expenses)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        deposits = try container.decodeIfPresent([WishDeposit].self, forKey: .deposits) ?? []
        sortIndex = try container.decodeIfPresent(Int.self, forKey: .sortIndex) ?? Int.max
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(nameCategory, forKey: .nameCategory)
        try container.encode(targetAmount, forKey: .targetAmount)
        try container.encode(estimatedDays, forKey: .estimatedDays)
        try container.encode(dailySaving, forKey: .dailySaving)
        try container.encode(expenses, forKey: .expenses)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(deposits, forKey: .deposits)
        try container.encode(sortIndex, forKey: .sortIndex)
    }

    var dailyExpense: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    var savedAmount: Double {
        deposits.reduce(0) { $0 + $1.amount }
    }

    var remaining: Double {
        max(targetAmount - savedAmount, 0)
    }

    var isComplete: Bool {
        targetAmount > 0 && savedAmount + 0.009 >= targetAmount
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(savedAmount / targetAmount, 1)
    }

    /// The creation day counts as day 1.
    var daysElapsed: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: createdAt)
        let today = calendar.startOfDay(for: .now)
        let gap = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        return max(gap, 0) + 1
    }

    var savedToday: Double {
        let start = Calendar.current.startOfDay(for: .now)
        return deposits.filter { $0.date >= start }.reduce(0) { $0 + $1.amount }
    }

    var forecastDate: Date? {
        if isComplete {
            return deposits.max(by: { $0.date < $1.date })?.date ?? createdAt
        }
        guard dailySaving > 0, remaining > 0 else { return nil }
        let days = WishPlanAdvice.daysNeeded(for: remaining, daily: dailySaving)
        guard days <= 10_000 else { return nil }
        return Calendar.current.date(byAdding: .day, value: days, to: .now)
    }

    /// Amount that should already be saved if the target is spread evenly over the estimated days.
    var expectedSaved: Double {
        guard estimatedDays > 0, targetAmount > 0 else { return 0 }
        let ratio = min(Double(daysElapsed) / Double(estimatedDays), 1)
        return targetAmount * ratio
    }

    /// 1 means the savings match the estimated-day pace. Above 1 means ahead of that pace.
    var achievementRate: Double {
        let expected = expectedSaved
        guard expected > 0 else { return 0 }
        return savedAmount / expected
    }

    var isPastEstimate: Bool {
        estimatedDays > 0 && daysElapsed > estimatedDays && !isComplete
    }
}

struct WishDayTotal: Identifiable, Hashable {
    var day: Date
    var amount: Double
    var share: Double
    var id: Date { day }
}

struct WishPlanAdvice: Equatable {
    enum WishTone: Equatable {
        case incomplete
        case ready
        case short
    }

    struct WishTip: Identifiable, Equatable {
        let id: String
        let title: String
        let detail: String
    }

    var tone: WishTone
    var conclusion: String
    var tips: [WishTip]

    static func evaluate(
        name: String,
        target: Double?,
        days: Int?,
        daily: Double?,
        expenses: [(category: WishExpenseCategory, amount: Double)]
    ) -> WishPlanAdvice {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = trimmed.isEmpty ? "This wish" : "\"\(trimmed)\""

        guard let target, target > 0 else {
            return WishPlanAdvice(
                tone: .incomplete,
                conclusion: "Enter a target amount first. The days and the daily amount need a number to compare against.",
                tips: []
            )
        }
        guard let days, days > 0 else {
            return WishPlanAdvice(
                tone: .incomplete,
                conclusion: "\(subject) targets \(WishFormat.money(target)). Add the estimated days to see how much to save each day.",
                tips: []
            )
        }
        guard let daily else {
            return WishPlanAdvice(
                tone: .incomplete,
                conclusion: "\(subject) plans to save \(WishFormat.money(target)) in \(dayCount(days)). Add the daily amount to see if that pace is enough.",
                tips: []
            )
        }

        let ranked = expenses
            .map { (category: $0.category, amount: max($0.amount, 0)) }
            .filter { $0.amount > 0.009 }
            .sorted { $0.amount > $1.amount }
        let expenseTotal = ranked.reduce(0) { $0 + $1.amount }

        guard daily > 0 else {
            let needed = target / Double(days)
            var tips = [
                WishTip(
                    id: "need",
                    title: "Set a daily amount",
                    detail: "Spread over \(dayCount(days)), \(WishFormat.money(needed)) a day reaches \(WishFormat.money(target))."
                )
            ]
            if let top = ranked.first {
                tips.append(categoryTip(
                    top: top,
                    expenseTotal: expenseTotal,
                    second: ranked.dropFirst().first,
                    extraDaily: needed,
                    fasterTarget: target,
                    baseDaily: 0,
                    shortfall: true
                ))
            }
            return WishPlanAdvice(
                tone: .short,
                conclusion: "The daily amount is \(WishFormat.money(0)), so after \(dayCount(days)) there is still no progress. To reach \(subject) in that time, save at least \(WishFormat.money(needed)) a day.",
                tips: tips
            )
        }

        let planned = daily * Double(days)
        let gap = target - planned
        let neededDaily = target / Double(days)
        let finishDays = daysNeeded(for: target, daily: daily)
        let tone: WishTone = planned + 0.009 >= target ? .ready : .short
        var conclusion: String

        if tone == .ready {
            let extra = max(planned - target, 0)
            if finishDays <= 10_000, finishDays < days {
                conclusion = "\(subject) saves \(WishFormat.money(daily)) a day and can reach \(WishFormat.money(target)) in about \(dayCount(finishDays)), \(dayCount(days - finishDays)) sooner than the \(dayCount(days)) plan. Saving for the full estimate leaves \(WishFormat.money(extra)) extra."
            } else if extra < 0.5 {
                conclusion = "\(subject) saves \(WishFormat.money(daily)) a day and hits \(WishFormat.money(target)) in exactly \(dayCount(days))."
            } else {
                conclusion = "\(subject) saves \(WishFormat.money(daily)) a day and would have \(WishFormat.money(planned)) after \(dayCount(days)), past the \(WishFormat.money(target)) target."
            }
        } else {
            let extraDaily = max(neededDaily - daily, 0)
            let pace: String
            if finishDays > 10_000 {
                pace = "At this pace it would take more than 10,000 days."
            } else {
                pace = "At this pace it takes \(dayCount(finishDays))."
            }
            conclusion = "\(subject) saves \(WishFormat.money(daily)) a day, which is \(WishFormat.money(planned)) after \(dayCount(days)) and \(WishFormat.money(gap)) short of \(WishFormat.money(target)). To finish in \(dayCount(days)), save \(WishFormat.money(neededDaily)) a day, \(WishFormat.money(extraDaily)) more. \(pace)"
        }

        if expenseTotal > 0 {
            let savingsRate = daily / (daily + expenseTotal)
            conclusion += " Daily spending is \(WishFormat.money(expenseTotal)), and the savings rate is \(WishFormat.percent(savingsRate))."
        } else {
            conclusion += " Spending is not broken down by category yet."
        }

        var tips: [WishTip] = []
        if tone == .short {
            let extraDaily = max(neededDaily - daily, 0)
            let detail: String
            if finishDays > 10_000 {
                detail = "Save \(WishFormat.money(extraDaily)) more each day to match the target in \(dayCount(days)). At \(WishFormat.money(daily)) a day, even 10,000 days is not enough. Raise the daily amount first."
            } else {
                detail = "Save \(WishFormat.money(extraDaily)) more each day and the target lines up in \(dayCount(days)). If the daily amount cannot go up yet, change the estimate to \(dayCount(finishDays)) and \(WishFormat.money(daily)) a day still gets there."
            }
            tips.append(WishTip(id: "gap", title: "Close the daily gap", detail: detail))
        } else if finishDays <= 10_000, finishDays < days {
            tips.append(WishTip(
                id: "early",
                title: "The plan is ahead of the calendar",
                detail: "Keep saving \(WishFormat.money(daily)) a day and it lands in about \(dayCount(finishDays)), \(dayCount(days - finishDays)) before the \(dayCount(days)) you set aside. The extra days do not need a higher amount."
            ))
        } else {
            tips.append(WishTip(
                id: "exact",
                title: "The days match. Don't lower the daily amount",
                detail: "\(WishFormat.money(daily)) times \(dayCount(days)) is exactly the target. Miss one day and you have to make up the same amount later."
            ))
        }

        if let top = ranked.first {
            let extraDaily = tone == .short ? max(neededDaily - daily, 0) : top.amount * 0.1
            tips.append(categoryTip(
                top: top,
                expenseTotal: expenseTotal,
                second: ranked.dropFirst().first,
                extraDaily: extraDaily,
                fasterTarget: target,
                baseDaily: daily,
                shortfall: tone == .short
            ))
        } else {
            tips.append(WishTip(
                id: "expenses",
                title: "Break spending into categories",
                detail: "It is not clear where the money goes yet. Enter a daily amount for Food, Transport, Shopping, Fun, Housing, and Other. The largest one is used in the tip."
            ))
        }

        if expenseTotal > 0 {
            let savingsRate = daily / (daily + expenseTotal)
            tips.append(WishTip(
                id: "order",
                title: "Save before you spend",
                detail: "Spending \(WishFormat.money(expenseTotal)) and saving \(WishFormat.money(daily)) each day is a \(WishFormat.percent(savingsRate)) savings rate. Move \(WishFormat.money(max(daily, 0))) out before spending. What is left is what you can use today."
            ))
        }

        return WishPlanAdvice(tone: tone, conclusion: conclusion, tips: tips)
    }

    private static func dayCount(_ days: Int) -> String {
        days == 1 ? "1 day" : "\(days) days"
    }

    static func daysNeeded(for target: Double, daily: Double) -> Int {
        guard daily > 0, target > 0, target.isFinite, daily.isFinite else { return 10_001 }
        let raw = target / daily
        if !raw.isFinite || raw > 100_000 {
            return 100_001
        }
        let adjusted = (raw - 0.0001).rounded(.up)
        return max(Int(adjusted), 1)
    }

    private static func categoryTip(
        top: (category: WishExpenseCategory, amount: Double),
        expenseTotal: Double,
        second: (category: WishExpenseCategory, amount: Double)?,
        extraDaily: Double,
        fasterTarget: Double,
        baseDaily: Double,
        shortfall: Bool
    ) -> WishTip {
        let share = expenseTotal > 0 ? top.amount / expenseTotal : 0
        let tactic = tacticLine(for: top.category)
        if shortfall {
            if top.amount + 0.009 >= extraDaily, extraDaily > 0 {
                let portion = extraDaily / top.amount
                return WishTip(
                    id: "cut",
                    title: "Move it from \(top.category.title)",
                    detail: "\(top.category.title) is the largest category, \(WishFormat.money(top.amount)) a day and \(WishFormat.percent(share)) of spending. Spending \(WishFormat.money(extraDaily)) less each day closes the gap, about \(WishFormat.percent(portion)) of this category. \(tactic)"
                )
            }
            if let second, top.amount > 0 {
                let fromTop = top.amount * 0.2
                let rest = max(extraDaily - fromTop, 0)
                return WishTip(
                    id: "cut",
                    title: "One category is not enough, so split it",
                    detail: "\(top.category.title) is \(WishFormat.money(top.amount)) a day. Cut 20% first and that frees \(WishFormat.money(fromTop)), leaving \(WishFormat.money(rest)) a day. \(second.category.title) is \(WishFormat.money(second.amount)) a day, so the rest can come from there. \(tactic)"
                )
            }
            return WishTip(
                id: "cut",
                title: "\(top.category.title) cannot cover this gap",
                detail: "This category is \(WishFormat.money(top.amount)) a day. Even if all of it went to savings, it would not cover the \(WishFormat.money(extraDaily)) still needed each day. Lengthen the estimate, or raise the daily amount. \(tactic)"
            )
        }

        let shift = top.amount * 0.1
        let fasterDaily = baseDaily + shift
        let fasterDays = daysNeeded(for: fasterTarget, daily: fasterDaily)
        let fasterText = fasterDays > 10_000 ? "it is still a long way off" : "it lands in about \(dayCount(fasterDays))"
        return WishTip(
            id: "cut",
            title: "Move another 10% from \(top.category.title)",
            detail: "\(top.category.title) is \(WishFormat.money(top.amount)) a day, \(WishFormat.percent(share)) of spending. Ten percent is \(WishFormat.money(shift)), which makes the daily save \(WishFormat.money(fasterDaily)), and \(fasterText). \(tactic)"
        )
    }

    private static func tacticLine(for category: WishExpenseCategory) -> String {
        switch category {
        case .food:
            "Skip one weekday delivery and save the difference into the wish the same day."
        case .transport:
            "Walk, bike, or use a pass when you can. Don't add a last-minute ride."
        case .shopping:
            "Leave a purchase until the next day. If you still want it, pay then. If you drop it, save that amount."
        case .entertainment:
            "Set a weekly cap for fun. Don't add more once it's reached. Put the difference toward the wish."
        case .housing:
            "Cancel renewals you don't use. A fixed bill you drop is the easiest amount to save every day."
        case .other:
            "Write down Other for a full week. Spending you can't name is usually what you can cut."
        }
    }
}
