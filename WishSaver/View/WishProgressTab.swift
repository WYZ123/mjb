import Charts
import SwiftUI

struct WishProgressTab: View {
    @EnvironmentObject private var store: WishStore
    @Binding var tab: WishAppTab
    @AppStorage(WishPreferenceKey.hideCompleted) private var hideCompleted = false
    @State private var query = ""
    @State private var activeSheet: WishListSheet?
    @State private var pendingDelete: Wish?
    @State private var showOverviewChart = false
    @State private var dropTarget: UUID?
    @AppStorage(WishPreferenceKey.streakProtection) private var streakProtection = false

    var body: some View {
        WishTabScreen {
            WishPageHeader(
                eyebrow: todayLine,
                tab: .progress,
                title: "Wishes",
                detail: "See how far each wish has come, and how long is left."
            )

            sampleDataButton

            WishDailyCheckInCard(
                wishes: store.wishes,
                makeupDays: store.makeupDaySet,
                grantMonths: store.makeupGrantMonths,
                protectionEnabled: streakProtection
            ) { day in
                WishHaptics.success()
                store.useMakeup(on: day)
            }

            if store.wishes.isEmpty {
                emptyState
            } else {
                overview
                wishList
            }
        }
        .sheet(isPresented: $showOverviewChart) {
            WishOverviewLineSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .detail(let id):
                WishDetailSheet(wishID: id) {
                    activeSheet = .deposit(id)
                } onEdit: {
                    activeSheet = .edit(id)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .deposit(let id):
                WishDepositSheet(wishID: id)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            case .edit(let id):
                WishEditorSheet(wishID: id)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .confirmationDialog(
            "Delete this wish?",
            isPresented: deletePresented,
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { wish in
            Button("Delete \"\(wish.name)\"", role: .destructive) {
                withAnimation {
                    store.deleteWish(wish.id)
                }
                WishHaptics.warning()
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This wish's spending and deposits will be removed too.")
        }
    }

    private var todayLine: String {
        "\(WishFormat.monthDay(.now)) · \(WishFormat.weekday(.now))"
    }

    private var deletePresented: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )
    }

    private var sampleDataButton: some View {
        Button {
            WishHaptics.tap()
            withAnimation {
                store.addSampleData()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(WishTheme.onSeal)
                    .frame(width: 36, height: 36)
                    .background(WishTheme.seal, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add sample data")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(WishTheme.ink)
                    Text("Adds five wishes with deposits and spending, so the charts have something to show.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(WishTheme.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WishTheme.seal)
            }
        }
        .buttonStyle(WishPressableStyle())
        .padding(16)
        .background(WishTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(WishTheme.line, lineWidth: 1)
        }
        .accessibilityHint("Adds sample wishes without removing the ones already saved")
    }

    private var emptyState: some View {
        WishSurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                WishSealMark(size: 56)
                Text("No wishes yet")
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(WishTheme.ink)
                Text("Write down what you want, then split it into a daily amount. Progress, the expected date, and how long you've been saving show up here.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(WishTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                WishPrimaryButton(title: "Add one") {
                    WishHaptics.tap()
                    tab = .add
                }
            }
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 14) {
            WishSectionHeading(
                title: "Overview",
                subtitle: pieSubtitle
            )
            Button {
                WishHaptics.tap()
                showOverviewChart = true
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        WishStatTile(title: "Wishes", value: "\(store.wishes.count)")
                        WishStatTile(title: "Saved", value: WishFormat.money(store.totalSaved))
                        WishStatTile(title: "Left", value: WishFormat.money(store.totalRemaining))
                        WishStatTile(title: "Overall", value: WishFormat.percent(store.overallProgress))
                    }
                    pieCard
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(WishPressableStyle())
            .accessibilityHint("Open the cumulative line chart")
        }
    }

    private var pieSubtitle: String {
        if store.wishes.contains(where: { $0.savedAmount > 0.009 }) {
            return "Shares use the amount already saved for each wish. Tap here for the cumulative line."
        }
        return "No deposits yet. Shares use the target amounts. Tap here for the line."
    }

    private var pieCard: some View {
        WishSurfaceCard {
            if pieSlices.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("After you write a wish, this pie splits the amounts.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(WishTheme.secondary)
                    overviewChartLink
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Chart(pieSlices) { slice in
                        SectorMark(
                            angle: .value("Amount", slice.amount),
                            innerRadius: .ratio(0.62),
                            angularInset: pieSlices.count > 1 ? 1.6 : 0
                        )
                        .cornerRadius(6)
                        .foregroundStyle(slice.color)
                    }
                    .frame(height: 220)
                    .allowsHitTesting(false)
                    .overlay {
                        VStack(spacing: 2) {
                            Text(pieCenterCaption)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(WishTheme.secondary)
                            Text(WishFormat.money(pieCenterAmount))
                                .font(.system(.title3, design: .rounded).weight(.semibold))
                                .foregroundStyle(WishTheme.ink)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(width: 120)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(pieCenterCaption)
                    .accessibilityValue(pieVoice)

                    ForEach(pieSlices) { slice in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(slice.color)
                                .frame(width: 10, height: 10)
                            Text(slice.name)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(WishTheme.ink)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(WishFormat.money(slice.amount))
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                                .foregroundStyle(WishTheme.ink)
                                .monospacedDigit()
                            Text(WishFormat.percent(slice.share))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(WishTheme.secondary)
                                .frame(width: 52, alignment: .trailing)
                                .monospacedDigit()
                        }
                    }

                    if hiddenWishCount > 0 {
                        Text("\(hiddenWishCount) wishes have not started saving, so they are not in this chart.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(WishTheme.secondary)
                    }
                    overviewChartLink
                }
            }
        }
    }

    private var overviewChartLink: some View {
        HStack(spacing: 6) {
            Text("Line chart")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(WishTheme.seal)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WishTheme.secondary)
        }
    }

    private var keyword: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var listedWishes: [Wish] {
        store.orderedWishes.filter { wish in
            if hideCompleted, wish.isComplete { return false }
            if keyword.isEmpty { return true }
            return wish.name.localizedStandardContains(keyword)
                || (wish.nameCategory?.title.localizedStandardContains(keyword) ?? false)
        }
    }

    private var wishList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Wishes")
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(WishTheme.ink)
                Spacer(minLength: 12)
                Button {
                    WishHaptics.tap()
                    tab = .add
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(WishTheme.seal)
                }
                .buttonStyle(WishPressableStyle())
            }
            Text(listSubtitle)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(WishTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)

            WishListSearch(text: $query)

            if listedWishes.isEmpty {
                Text(emptyListText)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(WishTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(listedWishes) { wish in
                    WishCard(wish: wish, canReorder: canReorder) {
                        activeSheet = .detail(wish.id)
                    } onDeposit: {
                        activeSheet = .deposit(wish.id)
                    } onEdit: {
                        activeSheet = .edit(wish.id)
                    } onDelete: {
                        pendingDelete = wish
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(WishTheme.seal, lineWidth: dropTarget == wish.id ? 2 : 0)
                    }
                    .dropDestination(for: String.self) { items, _ in
                        guard canReorder, let raw = items.first, let id = UUID(uuidString: raw), id != wish.id else {
                            return false
                        }
                        withAnimation(.spring(duration: 0.28)) {
                            store.reorderWish(id, before: wish.id)
                        }
                        dropTarget = nil
                        WishHaptics.tap()
                        return true
                    } isTargeted: { targeted in
                        dropTarget = targeted ? wish.id : (dropTarget == wish.id ? nil : dropTarget)
                    }
                }
            }
        }
    }

    private var emptyListText: String {
        if !keyword.isEmpty {
            return "No wishes match \"\(keyword)\"."
        }
        return "Completed wishes are hidden. Show them again in More."
    }

    private var listSubtitle: String {
        if !keyword.isEmpty {
            return listedWishes.isEmpty ? "Try another name, or tap Add." : "\(listedWishes.count) wishes. Tap View for the full record."
        }
        return "Hold a wish and drag it to set the order. The bar is saved amount divided by the target."
    }

    private var canReorder: Bool {
        keyword.isEmpty && listedWishes.count > 1
    }

    private struct WishPieSlice: Identifiable {
        let id: UUID
        let name: String
        let amount: Double
        let share: Double
        let color: Color
    }

    private var usesSavedPie: Bool {
        store.wishes.contains { $0.savedAmount > 0.009 }
    }

    private var pieCenterCaption: String {
        usesSavedPie ? "Saved" : "Target"
    }

    private var pieCenterAmount: Double {
        pieSlices.reduce(0) { $0 + $1.amount }
    }

    private var pieSlices: [WishPieSlice] {
        let source: [(Wish, Double)]
        if usesSavedPie {
            source = store.orderedWishes.compactMap { wish in
                wish.savedAmount > 0.009 ? (wish, wish.savedAmount) : nil
            }
        } else {
            source = store.orderedWishes.compactMap { wish in
                wish.targetAmount > 0 ? (wish, wish.targetAmount) : nil
            }
        }
        let total = source.reduce(0) { $0 + $1.1 }
        return source.enumerated().map { index, item in
            WishPieSlice(
                id: item.0.id,
                name: item.0.name,
                amount: item.1,
                share: total > 0 ? item.1 / total : 0,
                color: WishTheme.chartPalette[index % WishTheme.chartPalette.count]
            )
        }
    }

    private var hiddenWishCount: Int {
        guard usesSavedPie else { return 0 }
        return store.wishes.filter { $0.savedAmount <= 0.009 }.count
    }

    private var pieVoice: String {
        pieSlices.map { "\($0.name) \(WishFormat.money($0.amount)), \(WishFormat.percent($0.share))" }
            .joined(separator: "，")
    }
}

private enum WishListSheet: Identifiable {
    case detail(UUID)
    case deposit(UUID)
    case edit(UUID)

    var id: String {
        switch self {
        case .detail(let id): "detail-\(id.uuidString)"
        case .deposit(let id): "deposit-\(id.uuidString)"
        case .edit(let id): "edit-\(id.uuidString)"
        }
    }
}

private struct WishListSearch: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(WishTheme.secondary)
            TextField("Search wish names", text: $text)
                .font(.system(.body, design: .rounded))
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(WishTheme.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(WishTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(WishTheme.line, lineWidth: 1)
        }
    }
}

private struct WishCard: View {
    let wish: Wish
    var canReorder: Bool = false
    let onOpen: () -> Void
    let onDeposit: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        WishSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                if canReorder {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal")
                        Text("Hold and drag")
                        Spacer(minLength: 0)
                    }
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(WishTheme.secondary)
                    .contentShape(Rectangle())
                    .draggable(wish.id.uuidString) {
                        Text(wish.name)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(WishTheme.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(WishTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .accessibilityLabel("Reorder \(wish.name)")
                    .accessibilityHint("Hold and drag to change the order")
                }
                Button(action: onOpen) {
                    cardSummary
                }
                .buttonStyle(WishPressableStyle())
                .accessibilityHint("View this wish")

                HStack(spacing: 8) {
                    WishCardAction(title: "View", action: onOpen)
                    WishCardAction(title: "Edit", action: onEdit)
                    WishCardAction(title: "Delete", role: .danger, action: onDelete)
                }

                if wish.isComplete {
                    Text("This wish is fully saved.")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(WishTheme.sage)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        if wish.savedToday > 0 {
                            Text("Saved today \(WishFormat.money(wish.savedToday))")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(WishTheme.secondary)
                        }
                        WishPrimaryButton(title: wish.savedToday > 0 ? "Log another" : "Log today", action: onDeposit)
                    }
                }
            }
        }
    }

    private var cardSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if let category = wish.nameCategory?.title {
                        Text(category)
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(WishTheme.seal)
                    }
                    Text(wish.name)
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundStyle(WishTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Save \(WishFormat.money(wish.dailySaving)) a day · spend \(WishFormat.money(wish.dailyExpense)) a day")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(WishTheme.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                statusChip
            }

            HStack(alignment: .firstTextBaseline) {
                Text("\(WishFormat.money(wish.savedAmount)) / \(WishFormat.money(wish.targetAmount))")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(WishTheme.ink)
                    .monospacedDigit()
                Spacer()
                Text(WishFormat.percent(wish.progress))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(wish.isComplete ? WishTheme.sage : WishTheme.seal)
                    .monospacedDigit()
            }

            WishProgressTrack(progress: wish.progress, tint: wish.isComplete ? WishTheme.sage : WishTheme.seal)

            VStack(alignment: .leading, spacing: 6) {
                Label(forecastText, systemImage: "calendar")
                Label(elapsedText, systemImage: "clock")
            }
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(WishTheme.ink)
            .labelStyle(WishLabelStyle())

            if !wish.expenses.isEmpty {
                Text(expenseLine)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(WishTheme.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusChip: some View {
        Text(wish.isComplete ? "Done" : "In progress")
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .foregroundStyle(wish.isComplete ? WishTheme.sage : WishTheme.seal)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                (wish.isComplete ? WishTheme.sage : WishTheme.seal).opacity(0.12),
                in: Capsule()
            )
    }

    private var forecastText: String {
        if wish.isComplete, let date = wish.forecastDate {
            return "Reached on \(WishFormat.fullDate(date))"
        }
        if let date = wish.forecastDate {
            return "Expected on \(WishFormat.fullDate(date))"
        }
        return "The current daily amount is too small to estimate a date"
    }

    private var elapsedText: String {
        if wish.isPastEstimate {
            return "\(wish.daysElapsed) days in / \(wish.estimatedDays) planned, \(wish.daysElapsed - wish.estimatedDays) days past"
        }
        return "\(wish.daysElapsed) days in / \(wish.estimatedDays) planned"
    }

    private var expenseLine: String {
        wish.expenses
            .sorted { $0.amount > $1.amount }
            .map { "\($0.category.title) \(WishFormat.money($0.amount))" }
            .joined(separator: "  ·  ")
    }
}

private struct WishLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon
                .foregroundStyle(WishTheme.seal)
                .frame(width: 16)
            configuration.title
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct WishCardAction: View {
    enum Role {
        case normal
        case danger
    }

    let title: String
    var role: Role = .normal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(role == .danger ? WishTheme.danger : WishTheme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(WishTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(WishPressableStyle())
    }
}

struct WishDetailSheet: View {
    @EnvironmentObject private var store: WishStore
    @Environment(\.dismiss) private var dismiss
    let wishID: UUID
    let onDeposit: () -> Void
    let onEdit: () -> Void

    @State private var confirmDelete = false

    private var wish: Wish? {
        store.wish(wishID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let wish {
                    VStack(alignment: .leading, spacing: 18) {
                        header(wish)
                        stats(wish)
                        plan(wish)
                        history(wish)
                        actions(wish)
                    }
                    .padding(20)
                    .padding(.bottom, 12)
                }
            }
            .background(WishTheme.background.ignoresSafeArea())
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .confirmationDialog("Delete this wish?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete \"\(wish?.name ?? "")\"", role: .destructive) {
                store.deleteWish(wishID)
                WishHaptics.warning()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This wish's spending and deposits will be removed too.")
        }
    }

    private func header(_ wish: Wish) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let category = wish.nameCategory?.title {
                Text(category)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(WishTheme.seal)
            }
            Text(wish.name)
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(WishTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(wish.isComplete ? "Done" : "In progress")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(wish.isComplete ? WishTheme.sage : WishTheme.seal)
        }
    }

    private func stats(_ wish: Wish) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            WishStatTile(title: "Saved", value: WishFormat.money(wish.savedAmount))
            WishStatTile(title: "Left", value: WishFormat.money(wish.remaining))
            WishStatTile(title: "Progress", value: WishFormat.percent(wish.progress))
            WishStatTile(title: "Pace", value: WishFormat.percent(wish.achievementRate))
        }
    }

    private func plan(_ wish: Wish) -> some View {
        WishSurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                detailLine("Target", WishFormat.money(wish.targetAmount))
                detailLine("Daily save", WishFormat.money(wish.dailySaving))
                detailLine("Daily spend", WishFormat.money(wish.dailyExpense))
                detailLine("Estimated days", "\(wish.estimatedDays) days")
                detailLine("Days so far", "\(wish.daysElapsed) days")
                detailLine("Started", WishFormat.fullDate(wish.createdAt))
                if wish.isComplete, let date = wish.forecastDate {
                    detailLine("Reached", WishFormat.fullDate(date))
                } else if let date = wish.forecastDate {
                    detailLine("Expected", WishFormat.fullDate(date))
                }
                if !wish.expenses.isEmpty {
                    Divider().overlay(WishTheme.line)
                    ForEach(wish.expenses.sorted { $0.amount > $1.amount }) { slice in
                        detailLine(slice.category.title, WishFormat.money(slice.amount))
                    }
                }
            }
        }
    }

    private func history(_ wish: Wish) -> some View {
        let rows = wish.deposits.sorted { $0.date > $1.date }
        return VStack(alignment: .leading, spacing: 10) {
            WishSectionHeading(title: "Deposits", subtitle: rows.isEmpty ? "No deposits yet." : "\(rows.count) deposits. Edit the wish to change one.")
            if !rows.isEmpty {
                WishSurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(rows) { deposit in
                            HStack {
                                Text(WishFormat.fullDate(deposit.date))
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(WishTheme.secondary)
                                Spacer()
                                Text(WishFormat.money(deposit.amount))
                                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                                    .foregroundStyle(WishTheme.ink)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
    }

    private func actions(_ wish: Wish) -> some View {
        VStack(spacing: 10) {
            if !wish.isComplete {
                WishPrimaryButton(title: "Log a deposit", action: onDeposit)
            }
            Button(action: onEdit) {
                Text("Edit")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(WishTheme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(WishTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(WishTheme.line, lineWidth: 1)
                    }
            }
            .buttonStyle(WishPressableStyle())
            Button {
                confirmDelete = true
            } label: {
                Text("Delete")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(WishTheme.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(WishPressableStyle())
        }
    }

    private func detailLine(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(WishTheme.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(WishTheme.ink)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct WishDepositSheet: View {
    @EnvironmentObject private var store: WishStore
    @Environment(\.dismiss) private var dismiss
    let wishID: UUID

    @State private var amountText = ""
    @FocusState private var amountFocused: Bool

    private var wish: Wish? {
        store.wish(wishID)
    }

    private var amount: Double? {
        guard let value = WishFormat.parseAmount(amountText), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let wish {
                        Text(wish.name)
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .foregroundStyle(WishTheme.ink)
                        Text("\(WishFormat.money(wish.remaining)) left · plan \(WishFormat.money(wish.dailySaving)) a day")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(WishTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("This deposit")
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                                .foregroundStyle(WishTheme.secondary)
                            TextField("0", text: $amountText)
                                .keyboardType(.decimalPad)
                                .focused($amountFocused)
                                .font(.system(.title2, design: .rounded).weight(.semibold))
                                .monospacedDigit()
                                .padding(14)
                                .background(WishTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(WishTheme.line, lineWidth: 1)
                                }
                        }

                        if let amount, wish.targetAmount > 0 {
                            let next = min((wish.savedAmount + amount) / wish.targetAmount, 1)
                            Text("After this, progress is \(WishFormat.percent(next)), with \(WishFormat.money(max(wish.remaining - amount, 0))) left.")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(WishTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        WishPrimaryButton(title: "Save deposit", enabled: amount != nil) {
                            guard let amount else { return }
                            store.deposit(wishID: wishID, amount: amount)
                            WishHaptics.success()
                            dismiss()
                        }
                    }
                }
                .padding(20)
            }
            .background(WishTheme.background.ignoresSafeArea())
            .navigationTitle("Log a deposit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { amountFocused = false }
                }
            }
        }
        .onAppear {
            guard amountText.isEmpty, let wish else { return }
            let suggested = wish.remaining > 0 ? min(wish.dailySaving, wish.remaining) : wish.dailySaving
            if suggested > 0 {
                amountText = WishFormat.editable(suggested)
            }
        }
    }
}

private struct WishTrendPoint: Identifiable {
    let day: Date
    let cumulative: Double
    let added: Double
    var id: Date { day }
}

private enum WishTrendSpan: Int, CaseIterable, Identifiable {
    case week = 7
    case month = 30
    case all = 0

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .week: "7 days"
        case .month: "30 days"
        case .all: "All"
        }
    }
}

private struct WishOverviewLineSheet: View {
    @EnvironmentObject private var store: WishStore
    @Environment(\.dismiss) private var dismiss
    @State private var span: WishTrendSpan = .all
    @State private var selectedDate: Date?

    private var points: [WishTrendPoint] {
        Self.points(in: store.wishes, span: span)
    }

    private var selectedPoint: WishTrendPoint? {
        guard let selectedDate, !points.isEmpty else { return nil }
        return points.min {
            abs($0.day.timeIntervalSince(selectedDate)) < abs($1.day.timeIntervalSince(selectedDate))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Each step is money saved that day. The height is the total saved through that day.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(WishTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Picker("Range", selection: $span) {
                        ForEach(WishTrendSpan.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    WishSurfaceCard {
                        VStack(alignment: .leading, spacing: 16) {
                            lineChart
                            Text(summaryText)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(WishTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            depositDays
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 12)
            }
            .background(WishTheme.background.ignoresSafeArea())
            .navigationTitle("Line chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onChange(of: span) { _, _ in
            selectedDate = nil
        }
    }

    private var lineChart: some View {
        let peak = points.map(\.cumulative).max() ?? 0
        let ceiling = max(peak * 1.18, 1)
        let strideDays = points.count > 21 ? 7 : (points.count > 10 ? 3 : 1)
        return Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Date", point.day, unit: .day),
                    y: .value("Total", point.cumulative)
                )
                .foregroundStyle(WishTheme.seal.opacity(0.16))
                .interpolationMethod(.stepEnd)

                LineMark(
                    x: .value("Date", point.day, unit: .day),
                    y: .value("Total", point.cumulative)
                )
                .foregroundStyle(WishTheme.seal)
                .interpolationMethod(.stepEnd)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineJoin: .round))

                if point.added > 0.009 {
                    PointMark(
                        x: .value("Date", point.day, unit: .day),
                        y: .value("Total", point.cumulative)
                    )
                    .foregroundStyle(WishTheme.seal)
                    .symbolSize(points.count > 21 ? 18 : 36)
                }
            }
            if let selectedPoint {
                RuleMark(x: .value("Date", selectedPoint.day, unit: .day))
                    .foregroundStyle(WishTheme.line)
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit, y: .disabled)) {
                        Text("\(WishFormat.monthDay(selectedPoint.day))  +\(WishFormat.money(selectedPoint.added))")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(WishTheme.ink)
                            .monospacedDigit()
                    }
            }
        }
        .chartYScale(domain: 0...ceiling)
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: strideDays)) { value in
                AxisGridLine().foregroundStyle(Color.clear)
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(axisLabel(date))
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
        .frame(height: 240)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cumulative savings chart")
        .accessibilityValue(summaryText)
    }

    private var summaryText: String {
        guard let first = points.first, let last = points.last else {
            return "After the first deposit, this draws the cumulative line."
        }
        let gained = last.cumulative - (first.cumulative - first.added)
        if last.cumulative <= 0.009 {
            return "No deposits yet, so the line stays at $0."
        }
        if let selectedPoint {
            return "\(WishFormat.fullDate(selectedPoint.day)): saved \(WishFormat.money(selectedPoint.added)), total \(WishFormat.money(selectedPoint.cumulative))."
        }
        return "From \(WishFormat.monthDay(first.day)) to today, saved \(WishFormat.money(gained)). Total \(WishFormat.money(last.cumulative))."
    }

    private var depositDays: some View {
        let recorded = points.filter { $0.added > 0.009 }.reversed()
        return VStack(alignment: .leading, spacing: 10) {
            if recorded.isEmpty {
                Text("No new deposits in this range.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(WishTheme.secondary)
            } else {
                ForEach(Array(recorded)) { point in
                    HStack {
                        Text(WishFormat.monthDay(point.day))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(WishTheme.ink)
                        Spacer()
                        Text("+\(WishFormat.money(point.added))")
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundStyle(WishTheme.seal)
                            .monospacedDigit()
                        Text(WishFormat.money(point.cumulative))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(WishTheme.secondary)
                            .frame(width: 72, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private func axisLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = points.count > 10 ? "M/d" : "d"
        return formatter.string(from: date)
    }

    private static func points(in wishes: [Wish], span: WishTrendSpan) -> [WishTrendPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var addedByDay: [Date: Double] = [:]
        var firstDeposit: Date?
        for wish in wishes {
            for deposit in wish.deposits {
                let day = min(calendar.startOfDay(for: deposit.date), today)
                addedByDay[day, default: 0] += deposit.amount
                if let current = firstDeposit {
                    if day < current { firstDeposit = day }
                } else {
                    firstDeposit = day
                }
            }
        }

        let start: Date
        switch span {
        case .week:
            start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        case .month:
            start = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        case .all:
            if let firstDeposit, let before = calendar.date(byAdding: .day, value: -1, to: firstDeposit) {
                start = before
            } else {
                start = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            }
        }

        let prior = addedByDay.reduce(0) { partial, item in
            item.key < start ? partial + item.value : partial
        }
        var series: [WishTrendPoint] = []
        var running = prior
        var cursor = start
        while cursor <= today {
            let added = addedByDay[cursor] ?? 0
            running += added
            series.append(WishTrendPoint(day: cursor, cumulative: running, added: added))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return series
    }
}
