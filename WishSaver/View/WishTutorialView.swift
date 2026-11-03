import SwiftUI

struct WishTutorialPage: Identifiable {
    let id: Int
    let symbol: String
    let title: String
    let detail: String
}

struct WishTutorialView: View {
    var onFinish: () -> Void

    @State private var page = 0

    private let pages: [WishTutorialPage] = [
        WishTutorialPage(
            id: 0,
            symbol: "plus.circle.fill",
            title: "Write down a wish",
            detail: "On New, pick a category and enter a name. Set the target, how long it should take, and how much to save each day. Time can be days, weeks, months, or years, or you can type the number of days."
        ),
        WishTutorialPage(
            id: 1,
            symbol: "banknote.fill",
            title: "Log each day",
            detail: "Back on Wishes, log a deposit. Meet today's save goal to light the badge. Hold a wish and drag it to change the order."
        ),
        WishTutorialPage(
            id: 2,
            symbol: "chart.bar.fill",
            title: "Spending and pace",
            detail: "Log today's spending by Food, Transport, and the other categories. Pace adds a check-in heatmap and a monthly report that compares last month."
        ),
        WishTutorialPage(
            id: 3,
            symbol: "iphone",
            title: "The ledger stays on this phone",
            detail: "More can share the achievement wall and turn on one makeup day each month. These records are not uploaded."
        )
    ]

    private var isLastPage: Bool {
        page == pages.count - 1
    }

    var body: some View {
        ZStack {
            WishTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip", action: onFinish)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .foregroundStyle(isLastPage ? .clear : WishTheme.secondary)
                        .disabled(isLastPage)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                }

                TabView(selection: $page) {
                    ForEach(pages) { item in
                        pageContent(item)
                            .tag(item.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(pages) { item in
                        Capsule()
                            .fill(item.id == page ? WishTheme.seal : WishTheme.track)
                            .frame(width: item.id == page ? 18 : 7, height: 7)
                    }
                }
                .animation(.spring(duration: 0.3), value: page)
                .padding(.bottom, 22)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Page \(page + 1) of \(pages.count)")

                WishPrimaryButton(title: isLastPage ? "Get started" : "Next") {
                    if isLastPage {
                        onFinish()
                    } else {
                        withAnimation {
                            page += 1
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }

    private func pageContent(_ item: WishTutorialPage) -> some View {
        VStack(spacing: 22) {
            Spacer(minLength: 12)
            ZStack {
                if item.id == 0 {
                    WishSealMark(size: 96)
                } else {
                    Image(systemName: item.symbol)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(WishTheme.seal)
                        .frame(width: 96, height: 96)
                        .background(WishTheme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(WishTheme.line, lineWidth: 1)
                        }
                }
            }
            .accessibilityHidden(true)

            Text(item.title)
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .foregroundStyle(WishTheme.ink)
                .multilineTextAlignment(.center)

            Text(item.detail)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(WishTheme.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
