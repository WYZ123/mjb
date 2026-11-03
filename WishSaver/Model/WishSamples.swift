import Foundation

enum WishSamples {
    /// First-launch ledger. Dates are relative to today so the charts stay current.
    static func make(now: Date = .now) -> [Wish] {
        [
            headphones(now: now),
            weekendTrip(now: now),
            runningShoes(now: now),
            lens(now: now),
            oakDesk(now: now)
        ].enumerated().map { index, wish in
            var copy = wish
            copy.sortIndex = index
            return copy
        }
    }

    private static func headphones(now: Date) -> Wish {
        Wish(
            name: "Noise-canceling headphones",
            nameCategory: .digital,
            targetAmount: 1299,
            estimatedDays: 90,
            dailySaving: 20,
            expenses: slices([
                (.food, 42),
                (.transport, 8),
                (.shopping, 15),
                (.entertainment, 12)
            ]),
            createdAt: day(-17, now: now),
            deposits: saving(daily: 20, from: -17, through: 0, skip: [-11, -5], extra: [-3: 20], now: now)
        )
    }

    private static func weekendTrip(now: Date) -> Wish {
        Wish(
            name: "Weekend trip",
            nameCategory: .travel,
            targetAmount: 1600,
            estimatedDays: 50,
            dailySaving: 25,
            expenses: slices([
                (.food, 55),
                (.transport, 28),
                (.entertainment, 36)
            ]),
            createdAt: day(-20, now: now),
            deposits: saving(daily: 25, on: [-20, -16, -12, -9, -6, -2], now: now)
        )
    }

    private static func runningShoes(now: Date) -> Wish {
        Wish(
            name: "Running shoes",
            nameCategory: .sport,
            targetAmount: 699,
            estimatedDays: 40,
            dailySaving: 25,
            expenses: slices([
                (.shopping, 20),
                (.transport, 6)
            ]),
            createdAt: day(-34, now: now),
            deposits: saving(daily: 25, from: -34, through: -7, now: now)
        )
    }

    private static func lens(now: Date) -> Wish {
        Wish(
            name: "Prime lens",
            nameCategory: .digital,
            targetAmount: 4800,
            estimatedDays: 120,
            dailySaving: 40,
            expenses: slices([
                (.food, 48),
                (.housing, 70),
                (.other, 12)
            ]),
            createdAt: day(-2, now: now),
            deposits: saving(daily: 40, from: -2, through: 0, now: now)
        )
    }

    private static func oakDesk(now: Date) -> Wish {
        Wish(
            name: "Oak desk",
            nameCategory: .home,
            targetAmount: 2400,
            estimatedDays: 30,
            dailySaving: 40,
            expenses: slices([
                (.shopping, 30),
                (.other, 18)
            ]),
            createdAt: day(-40, now: now),
            deposits: saving(daily: 40, from: -40, through: -26, now: now)
        )
    }

    private static func slices(_ pairs: [(WishExpenseCategory, Double)]) -> [WishExpenseSlice] {
        pairs.map { WishExpenseSlice(category: $0.0, amount: $0.1) }
    }

    private static func saving(
        daily: Double,
        from start: Int,
        through end: Int,
        skip: Set<Int> = [],
        extra: [Int: Double] = [:],
        now: Date
    ) -> [WishDeposit] {
        (start...end).compactMap { offset in
            guard !skip.contains(offset) else { return nil }
            return WishDeposit(amount: daily + (extra[offset] ?? 0), date: day(offset, now: now))
        }
    }

    private static func saving(daily: Double, on offsets: [Int], now: Date) -> [WishDeposit] {
        offsets.map { WishDeposit(amount: daily, date: day($0, now: now)) }
    }

    private static func day(_ offset: Int, now: Date) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: offset, to: today) ?? today
    }
}
