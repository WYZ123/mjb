import Foundation

@MainActor
final class WishStore: ObservableObject {
    @Published private(set) var wishes: [Wish] = []
    @Published private(set) var makeupDays: [Date] = []
    @Published private(set) var makeupGrantMonths: [String] = []

    private let persistenceEnabled: Bool
    private let fileURL: URL
    private let checkInURL: URL

    init(previewWishes: [Wish]? = nil) {
        if let previewWishes {
            wishes = previewWishes
            persistenceEnabled = false
            fileURL = URL(fileURLWithPath: "/dev/null")
            checkInURL = URL(fileURLWithPath: "/dev/null")
            return
        }
        persistenceEnabled = true
        fileURL = Self.makeURL()
        checkInURL = fileURL.deletingLastPathComponent().appendingPathComponent("checkin.json")
        load()
    }

    var makeupDaySet: Set<Date> {
        Set(makeupDays)
    }

    var totalSaved: Double {
        wishes.reduce(0) { $0 + $1.savedAmount }
    }

    var totalTarget: Double {
        wishes.reduce(0) { $0 + $1.targetAmount }
    }

    var totalRemaining: Double {
        wishes.reduce(0) { $0 + $1.remaining }
    }

    var overallProgress: Double {
        guard totalTarget > 0 else { return 0 }
        return min(totalSaved / totalTarget, 1)
    }

    var orderedWishes: [Wish] {
        wishes.sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex {
                return lhs.sortIndex < rhs.sortIndex
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    var ledgerText: String {
        var lines = ["Wish Saver", WishFormat.fullDate(.now), ""]
        guard !wishes.isEmpty else {
            lines.append("No wishes yet.")
            return lines.joined(separator: "\n")
        }
        lines.append("\(wishes.count) wishes. Saved \(WishFormat.money(totalSaved)). Remaining \(WishFormat.money(totalRemaining)). Overall \(WishFormat.percent(overallProgress)).")
        lines.append("")
        for wish in orderedWishes {
            if let category = wish.nameCategory?.title {
                lines.append("\(category) · \(wish.name)")
            } else {
                lines.append(wish.name)
            }
            lines.append("Target \(WishFormat.money(wish.targetAmount)). Saved \(WishFormat.money(wish.savedAmount)). Progress \(WishFormat.percent(wish.progress)).")
            if wish.isComplete, let date = wish.forecastDate {
                lines.append("Reached on \(WishFormat.fullDate(date)).")
            } else if let date = wish.forecastDate {
                lines.append("Expected on \(WishFormat.fullDate(date)).")
            }
            lines.append("\(wish.daysElapsed) days in / \(wish.estimatedDays) days planned. Achievement \(WishFormat.percent(wish.achievementRate)).")
            lines.append("Save \(WishFormat.money(wish.dailySaving)) a day. Spend \(WishFormat.money(wish.dailyExpense)) a day.")
            if !wish.expenses.isEmpty {
                let breakdown = wish.expenses
                    .sorted { $0.amount > $1.amount }
                    .map { "\($0.category.title) \(WishFormat.money($0.amount))" }
                    .joined(separator: ", ")
                lines.append(breakdown + ".")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    func wish(_ id: UUID) -> Wish? {
        wishes.first { $0.id == id }
    }

    func addWish(
        name: String,
        nameCategory: WishNameCategory?,
        targetAmount: Double,
        estimatedDays: Int,
        dailySaving: Double,
        expenses: [WishExpenseSlice],
        depositToday: Bool
    ) {
        var deposits: [WishDeposit] = []
        if depositToday, dailySaving > 0 {
            deposits.append(WishDeposit(amount: dailySaving, date: .now))
        }
        let nextIndex = (wishes.map(\.sortIndex).max() ?? -1) + 1
        let wish = Wish(
            name: name,
            nameCategory: nameCategory,
            targetAmount: targetAmount,
            estimatedDays: estimatedDays,
            dailySaving: dailySaving,
            expenses: expenses,
            deposits: deposits,
            sortIndex: nextIndex
        )
        wishes.append(wish)
        persist()
    }

    func updateWish(
        id: UUID,
        name: String,
        nameCategory: WishNameCategory?,
        targetAmount: Double,
        estimatedDays: Int,
        dailySaving: Double,
        expenses: [WishExpenseSlice]
    ) {
        guard let index = wishes.firstIndex(where: { $0.id == id }) else { return }
        var wish = wishes[index]
        wish.name = name
        wish.nameCategory = nameCategory
        wish.targetAmount = targetAmount
        wish.estimatedDays = estimatedDays
        wish.dailySaving = dailySaving
        wish.expenses = expenses
        wishes[index] = wish
        persist()
    }

    func deposit(wishID: UUID, amount: Double, on date: Date = .now) {
        guard amount > 0, let index = wishes.firstIndex(where: { $0.id == wishID }) else { return }
        var wish = wishes[index]
        guard !wish.isComplete else { return }
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        guard day <= calendar.startOfDay(for: .now) else { return }
        wish.deposits.append(WishDeposit(amount: amount, date: day))
        wishes[index] = wish
        persist()
    }

    func deleteDeposit(wishID: UUID, depositID: UUID) {
        guard let index = wishes.firstIndex(where: { $0.id == wishID }) else { return }
        var wish = wishes[index]
        wish.deposits.removeAll { $0.id == depositID }
        wishes[index] = wish
        persist()
    }

    func deleteWish(_ id: UUID) {
        wishes.removeAll { $0.id == id }
        persist()
    }

    func addSampleData() {
        var samples = WishSamples.make()
        let start = (wishes.map(\.sortIndex).max() ?? -1) + 1
        for index in samples.indices {
            samples[index].sortIndex = start + index
        }
        wishes.append(contentsOf: samples)
        persist()
    }

    func reorderWish(_ id: UUID, before targetID: UUID) {
        guard id != targetID else { return }
        var ordered = orderedWishes
        guard let from = ordered.firstIndex(where: { $0.id == id }),
              ordered.contains(where: { $0.id == targetID }) else { return }
        let item = ordered.remove(at: from)
        guard let destination = ordered.firstIndex(where: { $0.id == targetID }) else { return }
        ordered.insert(item, at: destination)
        for (index, wish) in ordered.enumerated() {
            guard let stored = wishes.firstIndex(where: { $0.id == wish.id }) else { continue }
            wishes[stored].sortIndex = index
        }
        persist()
    }

    func useMakeup(on date: Date) {
        let enabled = UserDefaults.standard.bool(forKey: WishPreferenceKey.streakProtection)
        guard let candidate = WishCheckIn.makeupCandidate(
            wishes: wishes,
            makeupDays: makeupDaySet,
            grantMonths: makeupGrantMonths,
            now: .now,
            protectionEnabled: enabled
        ) else { return }
        let day = Calendar.current.startOfDay(for: date)
        guard day == candidate else { return }
        makeupDays.append(day)
        makeupDays.sort()
        makeupGrantMonths.append(WishCheckIn.monthKey())
        persistCheckIn()
    }

    func deleteAll() {
        wishes = []
        makeupDays = []
        makeupGrantMonths = []
        persist()
        persistCheckIn()
    }

    func recentDays(count: Int) -> [WishDayTotal] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let total = totalSaved
        var buckets: [Date: Double] = [:]
        for wish in wishes {
            for deposit in wish.deposits {
                let day = calendar.startOfDay(for: deposit.date)
                buckets[day, default: 0] += deposit.amount
            }
        }
        let span = max(count, 1)
        return (0..<span).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset - (span - 1), to: today) else {
                return nil
            }
            let amount = buckets[day] ?? 0
            return WishDayTotal(day: day, amount: amount, share: total > 0 ? amount / total : 0)
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            wishes = WishSamples.make()
            persist()
            return
        }
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([Wish].self, from: data) else { return }
        wishes = decoded
        if normalizeOrder() {
            persist()
        }
        loadCheckIn()
    }

    private func persist() {
        guard persistenceEnabled else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(wishes) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    private func normalizeOrder() -> Bool {
        guard wishes.contains(where: { $0.sortIndex == Int.max }) else { return false }
        let ranked = wishes.enumerated().sorted { lhs, rhs in
            let left = lhs.element
            let right = rhs.element
            if left.sortIndex != right.sortIndex {
                return left.sortIndex < right.sortIndex
            }
            if left.isComplete != right.isComplete {
                return !left.isComplete
            }
            if abs(left.progress - right.progress) > 0.0001 {
                return left.progress < right.progress
            }
            if left.createdAt != right.createdAt {
                return left.createdAt > right.createdAt
            }
            return lhs.offset < rhs.offset
        }
        for (order, item) in ranked.enumerated() {
            wishes[item.offset].sortIndex = order
        }
        return true
    }

    private func loadCheckIn() {
        guard let data = try? Data(contentsOf: checkInURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode(WishCheckInFile.self, from: data) else { return }
        let calendar = Calendar.current
        makeupDays = decoded.makeupDays.map { calendar.startOfDay(for: $0) }.sorted()
        makeupGrantMonths = decoded.grantMonths
    }

    private func persistCheckIn() {
        guard persistenceEnabled else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(WishCheckInFile(makeupDays: makeupDays, grantMonths: makeupGrantMonths)) else { return }
        try? data.write(to: checkInURL, options: [.atomic])
    }

    private static func makeURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("WishSaver", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("wishes.json")
    }
}

private struct WishCheckInFile: Codable {
    var makeupDays: [Date]
    var grantMonths: [String]

    private enum CodingKeys: String, CodingKey {
        case makeupDays, grantMonths
    }

    init(makeupDays: [Date], grantMonths: [String]) {
        self.makeupDays = makeupDays
        self.grantMonths = grantMonths
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        makeupDays = try container.decodeIfPresent([Date].self, forKey: .makeupDays) ?? []
        grantMonths = try container.decodeIfPresent([String].self, forKey: .grantMonths) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(makeupDays, forKey: .makeupDays)
        try container.encode(grantMonths, forKey: .grantMonths)
    }
}
