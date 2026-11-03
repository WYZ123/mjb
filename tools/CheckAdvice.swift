import Foundation

@main
struct CheckAdvice {
    static func main() {
        let ready = WishPlanAdvice.evaluate(
            name: "Noise-canceling headphones",
            target: 3000,
            days: 100,
            daily: 30,
            expenses: [(category: .food, amount: 80), (category: .transport, amount: 20)]
        )
        precondition(ready.tone == .ready, ready.conclusion)
        precondition(ready.conclusion.contains("exactly"), ready.conclusion)
        precondition(ready.conclusion.contains("savings rate"), ready.conclusion)
        precondition(ready.tips.contains { $0.detail.contains("79") }, ready.tips.map(\.detail).joined(separator: "\n"))
        print("READY:", ready.conclusion)
        for tip in ready.tips { print("-", tip.title, tip.detail) }

        let short = WishPlanAdvice.evaluate(
            name: "Camera",
            target: 3000,
            days: 100,
            daily: 20,
            expenses: [(category: .food, amount: 80)]
        )
        precondition(short.tone == .short, short.conclusion)
        precondition(short.conclusion.contains("short of"), short.conclusion)
        precondition(short.tips.contains { $0.id == "gap" && $0.detail.contains("10") }, short.tips.map(\.detail).joined())
        precondition(short.tips.contains { $0.detail.contains("12.5%") }, short.tips.map(\.detail).joined())
        print("SHORT:", short.conclusion)

        let early = WishPlanAdvice.evaluate(
            name: "Running shoes",
            target: 1000,
            days: 10,
            daily: 200,
            expenses: []
        )
        precondition(early.tone == .ready, early.conclusion)
        precondition(early.conclusion.contains("5 days sooner"), early.conclusion)
        print("EARLY:", early.conclusion)

        let missing = WishPlanAdvice.evaluate(name: "", target: nil, days: nil, daily: nil, expenses: [])
        precondition(missing.tone == .incomplete)
        precondition(missing.tips.isEmpty)

        let calendar = Calendar.current
        let created = calendar.date(byAdding: .day, value: -9, to: Date())!
        let wish = Wish(
            name: "Headphones",
            targetAmount: 100,
            estimatedDays: 10,
            dailySaving: 10,
            expenses: [],
            createdAt: created,
            deposits: [WishDeposit(amount: 50, date: Date())]
        )
        precondition(wish.daysElapsed == 10, "elapsed \(wish.daysElapsed)")
        precondition(abs(wish.expectedSaved - 100) < 0.001, "expected \(wish.expectedSaved)")
        precondition(abs(wish.achievementRate - 0.5) < 0.001, "rate \(wish.achievementRate)")

        let fresh = Wish(
            name: "Today",
            targetAmount: 300,
            estimatedDays: 30,
            dailySaving: 10,
            expenses: [],
            deposits: [WishDeposit(amount: 10, date: Date())]
        )
        precondition(fresh.daysElapsed == 1, "fresh elapsed \(fresh.daysElapsed)")
        precondition(abs(fresh.expectedSaved - 10) < 0.001, "fresh expected \(fresh.expectedSaved)")
        precondition(abs(fresh.achievementRate - 1) < 0.001, "fresh rate \(fresh.achievementRate)")

        let money = WishFormat.money(1000)
        print("MONEY:", money)
        precondition(money.contains("$") && money.contains("1") && money.contains("000"), money)
        print("OK")
    }
}
