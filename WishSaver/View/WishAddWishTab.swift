import SwiftUI
import UIKit

struct WishAddWishTab: View {
    @EnvironmentObject private var store: WishStore
    @Binding var tab: WishAppTab

    @State private var category: WishNameCategory?
    @State private var customName = ""
    @State private var targetText = ""
    @State private var durationCount = 1
    @State private var durationUnit: WishDurationUnit?
    @State private var dailyText = ""
    @State private var drafts: [WishExpenseDraft] = WishExpenseCategory.allCases.map {
        WishExpenseDraft(category: $0, amountText: "")
    }
    @State private var logToday = true
    @FocusState private var focused: WishField?

    enum WishField: Hashable {
        case name
        case target
        case days
        case daily
        case expense(String)
    }

    var body: some View {
        WishTabScreen {
            WishPageHeader(
                tab: .add,
                title: "New",
                detail: "Write down a wish, then see which daily spending can move toward it."
            )
            planFields
            expenseFields
            conclusionCard
            if !advice.tips.isEmpty {
                tipsCard
            }
            if canSave {
                Toggle(isOn: $logToday) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Log today's amount")
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .foregroundStyle(WishTheme.ink)
                        Text("Save today's deposit using the daily amount.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(WishTheme.secondary)
                    }
                }
                .tint(WishTheme.seal)
                .padding(16)
                .background(WishTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(WishTheme.line, lineWidth: 1)
                }
            }
            if hasStarted, let reason = blockReason {
                Text(reason)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(WishTheme.secondary)
            }
            WishPrimaryButton(title: "Save wish", enabled: canSave) {
                save()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focused = nil
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }

    private var planFields: some View {
        WishSurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                WishNameCategoryPicker(category: $category)
                    .onChange(of: category) { _, newValue in
                        if newValue != nil {
                            focused = .name
                        }
                    }
                if category != nil {
                    labeledField(
                        title: "Name",
                        placeholder: "For example: noise-canceling headphones",
                        text: $customName,
                        field: .name,
                        keyboard: .default
                    )
                }
                labeledField(
                    title: "Amount",
                    placeholder: "For example: 1299",
                    text: $targetText,
                    field: .target,
                    keyboard: .decimalPad
                )
                WishDurationPicker(count: $durationCount, unit: $durationUnit)
                labeledField(
                    title: "Daily amount",
                    placeholder: "For example: 20",
                    text: $dailyText,
                    field: .daily,
                    keyboard: .decimalPad
                )
            }
        }
    }

    private var expenseFields: some View {
        WishSurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                WishSectionHeading(
                    title: "Daily spending",
                    subtitle: "Enter each category. The total is what you spend in a day. The right side is that category's share."
                )
                ForEach($drafts) { $draft in
                    WishExpenseEditorRow(
                        draft: $draft,
                        share: share(of: draft),
                        focused: $focused,
                        focusValue: .expense(draft.category.id)
                    )
                }
                Divider().overlay(WishTheme.line)
                HStack {
                    Text("Daily spending")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(WishTheme.ink)
                    Spacer()
                    Text(WishFormat.money(expenseTotal))
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(WishTheme.ink)
                        .monospacedDigit()
                }
            }
        }
    }

    private var conclusionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            WishSectionHeading(title: "Conclusion")
            WishSurfaceCard {
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(toneColor)
                        .frame(width: 4)
                    Text(advice.conclusion)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(WishTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            WishSectionHeading(title: "Ways to save", subtitle: "Calculated from the numbers you entered above.")
            VStack(spacing: 12) {
                ForEach(Array(advice.tips.enumerated()), id: \.element.id) { index, tip in
                    WishSurfaceCard {
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(WishTheme.onSeal)
                                .frame(width: 26, height: 26)
                                .background(WishTheme.seal, in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tip.title)
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                                    .foregroundStyle(WishTheme.ink)
                                Text(tip.detail)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(WishTheme.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    private func labeledField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: WishField,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(WishTheme.secondary)
            TextField(placeholder, text: text)
                .focused($focused, equals: field)
                .keyboardType(keyboard)
                .font(.system(.body, design: .rounded))
                .padding(14)
                .background(WishTheme.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(WishTheme.line, lineWidth: 1)
                }
        }
    }

    private var expenseTotal: Double {
        drafts.reduce(0) { partial, draft in
            partial + (WishFormat.parseAmount(draft.amountText) ?? 0)
        }
    }

    private func share(of draft: WishExpenseDraft) -> Double {
        guard expenseTotal > 0, let amount = WishFormat.parseAmount(draft.amountText), amount > 0 else { return 0 }
        return amount / expenseTotal
    }

    private var advice: WishPlanAdvice {
        WishPlanAdvice.evaluate(
            name: trimmedName,
            target: WishFormat.parseAmount(targetText),
            days: estimatedDays,
            daily: dailyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : WishFormat.parseAmount(dailyText),
            expenses: drafts.map { draft in
                (category: draft.category, amount: WishFormat.parseAmount(draft.amountText) ?? 0)
            }
        )
    }

    private var toneColor: Color {
        switch advice.tone {
        case .incomplete: WishTheme.secondary
        case .ready: WishTheme.sage
        case .short: WishTheme.seal
        }
    }

    private var trimmedName: String {
        category?.resolvedName(custom: customName) ?? ""
    }

    private var estimatedDays: Int? {
        durationUnit?.days(count: durationCount)
    }

    private var hasStarted: Bool {
        category != nil || !customName.isEmpty || durationUnit != nil || durationCount != 1 || !targetText.isEmpty || !dailyText.isEmpty
            || drafts.contains { !$0.amountText.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var canSave: Bool {
        blockReason == nil
    }

    private var blockReason: String? {
        if category == nil { return "Pick a category first." }
        if trimmedName.isEmpty { return "Enter a name for this wish." }
        guard let target = WishFormat.parseAmount(targetText), target > 0 else {
            return "The target amount must be greater than 0."
        }
        if durationUnit == nil { return "Choose day, week, month, or year." }
        guard estimatedDays != nil else {
            return "That duration is too long. Shorten it."
        }
        guard let daily = WishFormat.parseAmount(dailyText), daily > 0 else {
            return "The daily amount must be greater than 0."
        }
        return nil
    }

    private func save() {
        guard
            canSave,
            let target = WishFormat.parseAmount(targetText),
            let days = estimatedDays,
            let daily = WishFormat.parseAmount(dailyText)
        else { return }

        let expenses = drafts.compactMap { draft -> WishExpenseSlice? in
            guard let amount = WishFormat.parseAmount(draft.amountText), amount > 0 else { return nil }
            return WishExpenseSlice(category: draft.category, amount: amount)
        }
        store.addWish(
            name: trimmedName,
            nameCategory: category,
            targetAmount: target,
            estimatedDays: days,
            dailySaving: daily,
            expenses: expenses,
            depositToday: logToday
        )
        reset()
        WishHaptics.success()
        tab = .progress
    }

    private func reset() {
        category = nil
        customName = ""
        targetText = ""
        durationCount = 1
        durationUnit = nil
        dailyText = ""
        drafts = WishExpenseCategory.allCases.map { WishExpenseDraft(category: $0, amountText: "") }
        logToday = true
        focused = nil
    }
}

struct WishNameCategoryPicker: View {
    @Binding var category: WishNameCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(WishTheme.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(WishNameCategory.allCases) { item in
                    let selected = category == item
                    Button {
                        category = item
                    } label: {
                        Text(item.title)
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundStyle(selected ? WishTheme.onSeal : WishTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                selected ? WishTheme.seal : WishTheme.background,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                    .buttonStyle(WishPressableStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}

struct WishDurationPicker: View {
    @Binding var count: Int
    @Binding var unit: WishDurationUnit?
    @State private var dayText = ""
    @FocusState private var dayFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estimated time")
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(WishTheme.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(WishDurationUnit.allCases) { item in
                    let selected = unit == item
                    Button {
                        unit = item
                    } label: {
                        Text(item.title)
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundStyle(selected ? WishTheme.onSeal : WishTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                selected ? WishTheme.seal : WishTheme.background,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                    .buttonStyle(WishPressableStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Number of days")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(WishTheme.secondary)
                TextField("For example: 90", text: $dayText)
                    .keyboardType(.numberPad)
                    .focused($dayFocused)
                    .font(.system(.body, design: .rounded))
                    .monospacedDigit()
                    .padding(14)
                    .background(WishTheme.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(WishTheme.line, lineWidth: 1)
                    }
            }
            HStack {
                Text("Count")
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(WishTheme.ink)
                Spacer()
                Button {
                    count = max(1, count - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(count > 1 ? WishTheme.ink : WishTheme.secondary)
                        .frame(width: 36, height: 36)
                        .background(WishTheme.background, in: Circle())
                }
                .buttonStyle(WishPressableStyle())
                .disabled(count <= 1)
                Text("\(count)")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(WishTheme.ink)
                    .monospacedDigit()
                    .frame(minWidth: 36)
                Button {
                    count = min(countLimit, count + 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(count < countLimit ? WishTheme.ink : WishTheme.secondary)
                        .frame(width: 36, height: 36)
                        .background(WishTheme.background, in: Circle())
                }
                .buttonStyle(WishPressableStyle())
                .disabled(count >= countLimit)
            }
            Text(summary)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(WishTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear(perform: syncDayText)
        .onChange(of: count) { _, _ in syncDayText() }
        .onChange(of: unit) { _, _ in syncDayText() }
        .onChange(of: dayText) { _, newValue in applyDayText(newValue) }
    }

    private var countLimit: Int {
        guard let unit else { return 99_999 }
        return max(1, (100_000 - 1) / unit.rawValue)
    }

    private func syncDayText() {
        guard !dayFocused else { return }
        guard let unit, let days = unit.days(count: count) else { return }
        let text = String(days)
        if dayText != text {
            dayText = text
        }
    }

    private func applyDayText(_ raw: String) {
        let digits = raw.filter(\.isNumber)
        if digits != raw {
            dayText = digits
            return
        }
        guard dayFocused, let days = Int(digits), days > 0, days < 100_000 else { return }
        if unit != .day {
            unit = .day
        }
        if count != days {
            count = days
        }
    }

    private var summary: String {
        guard let unit, let days = unit.days(count: count) else {
            if unit != nil {
                return "That duration is too long. A week is 7 days, a month is 30 days, and a year is 365 days."
            }
            return "Choose day, week, month, or year. A week is 7 days, a month is 30 days, and a year is 365 days."
        }
        if unit == .day {
            return days == 1 ? "1 day." : "\(days) days."
        }
        let unitName = count == 1 ? unit.title.lowercased() : "\(unit.title.lowercased())s"
        return "\(count) \(unitName), \(days) days."
    }
}

struct WishExpenseDraft: Identifiable {
    let category: WishExpenseCategory
    var amountText: String
    var id: String { category.id }
}

private struct WishExpenseEditorRow: View {
    @Binding var draft: WishExpenseDraft
    let share: Double
    var focused: FocusState<WishAddWishTab.WishField?>.Binding
    let focusValue: WishAddWishTab.WishField

    var body: some View {
        let amount = WishFormat.parseAmount(draft.amountText) ?? 0
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: draft.category.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WishTheme.categoryColor(draft.category))
                    .frame(width: 20)
                Text(draft.category.title)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(WishTheme.ink)
                Spacer(minLength: 8)
                Text(WishFormat.percent(share))
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(WishTheme.secondary)
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }
            TextField("0", text: $draft.amountText)
                .focused(focused, equals: focusValue)
                .keyboardType(.decimalPad)
                .font(.system(.body, design: .rounded))
                .monospacedDigit()
                .padding(12)
                .background(WishTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(WishTheme.line, lineWidth: 1)
                }
            WishProgressTrack(progress: share, tint: WishTheme.categoryColor(draft.category), height: 6)
                .opacity(amount > 0 ? 1 : 0.45)
        }
    }
}
