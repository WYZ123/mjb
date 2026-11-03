import SwiftUI
import UIKit

struct WishEditorSheet: View {
    @EnvironmentObject private var store: WishStore
    @Environment(\.dismiss) private var dismiss
    let wishID: UUID

    @State private var category: WishNameCategory?
    @State private var customName = ""
    @State private var targetText = ""
    @State private var durationCount = 1
    @State private var durationUnit: WishDurationUnit?
    @State private var dailyText = ""
    @State private var drafts: [WishExpenseDraft] = WishExpenseCategory.allCases.map {
        WishExpenseDraft(category: $0, amountText: "")
    }
    @State private var backfillDate = Date()
    @State private var backfillText = ""
    @State private var didSave = false
    @State private var pendingDeposit: WishDeposit?
    @FocusState private var focused: WishEditorField?

    private enum WishEditorField: Hashable {
        case name
        case target
        case days
        case daily
        case expense(String)
        case backfill
    }

    private var wish: Wish? {
        store.wish(wishID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let wish {
                        planSection(wish)
                        historySection(wish)
                    }
                }
                .padding(20)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(WishTheme.background.ignoresSafeArea())
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focused = nil
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }
        .onAppear(perform: load)
        .confirmationDialog(
            "Delete this deposit?",
            isPresented: deletePresented,
            titleVisibility: .visible,
            presenting: pendingDeposit
        ) { deposit in
            Button("Delete \(WishFormat.money(deposit.amount))", role: .destructive) {
                store.deleteDeposit(wishID: wishID, depositID: deposit.id)
                WishHaptics.warning()
            }
            Button("Cancel", role: .cancel) {}
        } message: { deposit in
            Text("\(WishFormat.money(deposit.amount)) from \(WishFormat.fullDate(deposit.date)) will be removed from progress.")
        }
    }

    private var deletePresented: Binding<Bool> {
        Binding(
            get: { pendingDeposit != nil },
            set: { if !$0 { pendingDeposit = nil } }
        )
    }

    private func planSection(_ wish: Wish) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            WishSectionHeading(title: "Plan", subtitle: "Changing the target or daily amount does not change deposits already logged.")
            WishSurfaceCard {
                VStack(alignment: .leading, spacing: 16) {
                    WishNameCategoryPicker(category: $category)
                        .onChange(of: category) { _, _ in
                            didSave = false
                        }
                    if category != nil {
                        editorField("Name", "For example: noise-canceling headphones", text: $customName, field: .name, keyboard: .default)
                    }
                    editorField("Amount", "Target amount", text: $targetText, field: .target, keyboard: .decimalPad)
                    WishDurationPicker(count: $durationCount, unit: $durationUnit)
                        .onChange(of: durationCount) { _, _ in didSave = false }
                        .onChange(of: durationUnit) { _, _ in didSave = false }
                    editorField("Daily amount", "Amount saved each day", text: $dailyText, field: .daily, keyboard: .decimalPad)

                    Text("Daily spending")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(WishTheme.secondary)
                    ForEach($drafts) { $draft in
                        expenseRow($draft)
                    }
                    HStack {
                        Text("Daily spending")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(WishTheme.ink)
                        Spacer()
                        Text(WishFormat.money(expenseTotal))
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(WishTheme.ink)
                            .monospacedDigit()
                    }
                }
            }

            if let target = WishFormat.parseAmount(targetText), target > 0, wish.savedAmount + 0.009 >= target {
                Text("Saved money already covers this target. Saving will mark it complete.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(WishTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let reason = blockReason {
                Text(reason)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(WishTheme.secondary)
            }
            if didSave {
                Text("Plan updated.")
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(WishTheme.sage)
            }
            WishPrimaryButton(title: "Save changes", enabled: blockReason == nil) {
                savePlan()
            }
        }
    }

    private func historySection(_ wish: Wish) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            WishSectionHeading(
                title: "Deposits",
                subtitle: orderedDeposits(wish).isEmpty ? "No deposits yet." : "\(orderedDeposits(wish).count) deposits. Delete a wrong one, or add a missing day."
            )
            if !orderedDeposits(wish).isEmpty {
                WishSurfaceCard {
                    VStack(spacing: 12) {
                        ForEach(orderedDeposits(wish)) { deposit in
                            HStack {
                                Text(WishFormat.fullDate(deposit.date))
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(WishTheme.ink)
                                Spacer()
                                Text(WishFormat.money(deposit.amount))
                                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                                    .foregroundStyle(WishTheme.ink)
                                    .monospacedDigit()
                                Button {
                                    pendingDeposit = deposit
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(WishTheme.danger)
                                        .frame(width: 32, height: 32)
                                }
                                .buttonStyle(.plain)
                            }
                            if deposit.id != orderedDeposits(wish).last?.id {
                                Divider().overlay(WishTheme.line)
                            }
                        }
                    }
                }
            }

            if !wish.isComplete {
                WishSurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add a past deposit")
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundStyle(WishTheme.secondary)
                        DatePicker(
                            "Date",
                            selection: $backfillDate,
                            in: backfillRange(for: wish),
                            displayedComponents: .date
                        )
                        .font(.system(.body, design: .rounded))
                        .tint(WishTheme.seal)
                        editorField("Amount", "Deposit amount", text: $backfillText, field: .backfill, keyboard: .decimalPad)
                        WishPrimaryButton(title: "Add this deposit", enabled: backfillAmount != nil) {
                            guard let backfillAmount else { return }
                            store.deposit(wishID: wishID, amount: backfillAmount, on: backfillDate)
                            WishHaptics.success()
                        }
                    }
                }
            }
        }
    }

    private func expenseRow(_ draft: Binding<WishExpenseDraft>) -> some View {
        let amount = WishFormat.parseAmount(draft.wrappedValue.amountText) ?? 0
        let share = expenseTotal > 0 && amount > 0 ? amount / expenseTotal : 0
        return HStack(spacing: 8) {
            Image(systemName: draft.wrappedValue.category.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WishTheme.categoryColor(draft.wrappedValue.category))
                .frame(width: 20)
            Text(draft.wrappedValue.category.title)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(WishTheme.ink)
                .frame(width: 36, alignment: .leading)
            TextField("0", text: draft.amountText)
                .focused($focused, equals: .expense(draft.wrappedValue.category.id))
                .keyboardType(.decimalPad)
                .font(.system(.body, design: .rounded))
                .monospacedDigit()
                .padding(10)
                .background(WishTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(WishFormat.percent(share))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(WishTheme.secondary)
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)
        }
    }

    private func editorField(
        _ title: String,
        _ placeholder: String,
        text: Binding<String>,
        field: WishEditorField,
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
        .onChange(of: text.wrappedValue) { _, _ in
            didSave = false
        }
    }

    private var expenseTotal: Double {
        drafts.reduce(0) { $0 + (WishFormat.parseAmount($1.amountText) ?? 0) }
    }

    private var trimmedName: String {
        category?.resolvedName(custom: customName) ?? ""
    }

    private var estimatedDays: Int? {
        durationUnit?.days(count: durationCount)
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

    private var backfillAmount: Double? {
        guard let value = WishFormat.parseAmount(backfillText), value > 0 else { return nil }
        return value
    }

    private func orderedDeposits(_ wish: Wish) -> [WishDeposit] {
        wish.deposits.sorted { $0.date > $1.date }
    }

    private func backfillRange(for wish: Wish) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: wish.createdAt)
        let end = Date()
        if start <= end {
            return start...end
        }
        return end...end
    }

    private func load() {
        guard let wish else { return }
        if let nameCategory = wish.nameCategory {
            category = nameCategory
            customName = wish.name
        } else {
            let stored = WishNameCategory.stored(name: wish.name)
            category = stored.category
            customName = stored.custom.isEmpty ? wish.name : stored.custom
        }
        targetText = WishFormat.editable(wish.targetAmount)
        let duration = WishDurationUnit.split(wish.estimatedDays)
        durationCount = duration.count
        durationUnit = duration.unit
        dailyText = WishFormat.editable(wish.dailySaving)
        drafts = WishExpenseCategory.allCases.map { category in
            let amount = wish.expenses.first { $0.category == category }?.amount ?? 0
            let text = amount > 0 ? WishFormat.editable(amount) : ""
            return WishExpenseDraft(category: category, amountText: text)
        }
        backfillDate = Date()
        backfillText = WishFormat.editable(wish.dailySaving)
    }

    private func savePlan() {
        guard
            blockReason == nil,
            let target = WishFormat.parseAmount(targetText),
            let days = estimatedDays,
            let daily = WishFormat.parseAmount(dailyText)
        else { return }
        let expenses = drafts.compactMap { draft -> WishExpenseSlice? in
            guard let amount = WishFormat.parseAmount(draft.amountText), amount > 0 else { return nil }
            return WishExpenseSlice(category: draft.category, amount: amount)
        }
        store.updateWish(
            id: wishID,
            name: trimmedName,
            nameCategory: category,
            targetAmount: target,
            estimatedDays: days,
            dailySaving: daily,
            expenses: expenses
        )
        didSave = true
        WishHaptics.success()
    }
}
