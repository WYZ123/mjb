import SwiftUI
import UIKit

enum WishAppTab: String, CaseIterable, Identifiable, Hashable {
    case progress
    case add
    case data
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .progress: "Wishes"
        case .add: "New"
        case .data: "Pace"
        case .settings: "More"
        }
    }

    var symbol: String {
        switch self {
        case .progress: "star"
        case .add: "plus.circle"
        case .data: "chart.bar"
        case .settings: "gearshape"
        }
    }
}

struct WishRootTabView: View {
    @AppStorage(WishPreferenceKey.appearance) private var appearanceRaw = WishAppearance.system.rawValue
    @AppStorage(WishPreferenceKey.tutorialSeen) private var tutorialSeen = false
    @State private var tab: WishAppTab = .progress
    @State private var showTutorial = false

    private var appearance: WishAppearance {
        WishAppearance(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        TabView(selection: $tab) {
            WishProgressTab(tab: $tab)
                .tabItem { Label(WishAppTab.progress.title, systemImage: WishAppTab.progress.symbol) }
                .tag(WishAppTab.progress)
            WishAddWishTab(tab: $tab)
                .tabItem { Label(WishAppTab.add.title, systemImage: WishAppTab.add.symbol) }
                .tag(WishAppTab.add)
            WishDataTab()
                .tabItem { Label(WishAppTab.data.title, systemImage: WishAppTab.data.symbol) }
                .tag(WishAppTab.data)
            WishSettingsTab()
                .tabItem { Label(WishAppTab.settings.title, systemImage: WishAppTab.settings.symbol) }
                .tag(WishAppTab.settings)
        }
        .tint(WishTheme.seal)
        .preferredColorScheme(appearance.colorScheme)
        .task {
            await WishReminder.refreshSaved()
        }
        .onAppear {
            if !tutorialSeen {
                showTutorial = true
            }
        }
        .onChange(of: tab) { _, _ in
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .fullScreenCover(isPresented: $showTutorial) {
            WishTutorialView {
                tutorialSeen = true
                showTutorial = false
            }
        }
    }
}

