import SwiftUI

struct WishLaunchRootView: View {
    @EnvironmentObject private var launchRouter: WishLaunchRouter

    var body: some View {
        Group {
            switch launchRouter.route {
            case .loading:
                WishLaunchLoadingView()
            case .enterCode:
                WishCodeEntryView()
            case .webView(let url, let showsToolbar):
                WishEmbeddedBrowserView(urlString: url, showsToolbar: showsToolbar)
                    .id("\(url)-\(launchRouter.webViewLoadToken.uuidString)")
            case .tabAd:
                WishTabAdView {
                    launchRouter.finishAd()
                }
            case .remoteAd(let imageURL):
                WishRemoteAdView(imageURL: imageURL) {
                    launchRouter.finishAd()
                }
            case .mainApp:
                WishRootTabView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Task {
                await launchRouter.checkVersionIfNeeded()
            }
        }
    }
}

struct WishLaunchLoadingView: View {
    var body: some View {
        ZStack {
            WishTheme.background.ignoresSafeArea()
            VStack(spacing: 18) {
                WishSealMark(size: 88)
                Text("Wish Saver")
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                    .foregroundStyle(WishTheme.ink)
                Text("Turn a wish into a daily amount")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(WishTheme.secondary)
                    .multilineTextAlignment(.center)
                ProgressView()
                    .tint(WishTheme.seal)
                    .padding(.top, 8)
            }
        }
    }
}
