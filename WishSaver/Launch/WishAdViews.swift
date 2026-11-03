import SwiftUI
import UIKit

struct WishTabAdView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            WishLaunchLoadingView()
                .allowsHitTesting(false)

            VStack {
                HStack {
                    Spacer()
                    WishAdSkipControl(onSkip: onContinue)
                }
                Spacer()
            }
            .padding(.trailing, 20)
            .padding(.top, 8)
            .safeAreaPadding(.top)
            .zIndex(999)
        }
    }
}

struct WishRemoteAdView: View {
    let imageURL: String
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geometry in
                AsyncImage(url: URL(string: imageURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    case .failure:
                        WishLaunchLoadingView()
                    default:
                        ZStack {
                            WishTheme.background
                            ProgressView().tint(WishTheme.seal)
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                HStack {
                    Spacer()
                    WishAdSkipControl(onSkip: onContinue, onDark: true)
                }
                Spacer()
            }
            .padding(.trailing, 20)
            .padding(.top, 8)
            .safeAreaPadding(.top)
            .zIndex(999)
        }
    }
}

private struct WishAdSkipControl: View {
    let onSkip: () -> Void
    var onDark = false
    @State private var remainingSeconds = 5
    @State private var didSkip = false

    var body: some View {
        WishAdSkipButton(
            title: "Skip \(remainingSeconds)s",
            onDark: onDark,
            onTap: skip
        )
        .frame(width: 108, height: 40)
        .task(id: "ad-skip-countdown") {
            await runCountdown()
        }
    }

    private func skip() {
        guard !didSkip else { return }
        didSkip = true
        onSkip()
    }

    private func runCountdown() async {
        for _ in 0..<5 {
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled || didSkip { return }
            remainingSeconds = max(remainingSeconds - 1, 0)
        }
        skip()
    }
}

private struct WishAdSkipButton: UIViewRepresentable {
    var title: String
    var onDark: Bool
    var onTap: () -> Void

    func makeCoordinator() -> WishAdSkipCoordinator {
        WishAdSkipCoordinator(onTap: onTap)
    }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .custom)
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.addTarget(context.coordinator, action: #selector(WishAdSkipCoordinator.handleTap), for: .touchDown)
        applyStyle(button)
        button.setTitle(title, for: .normal)
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {
        applyStyle(uiView)
        uiView.setTitle(title, for: .normal)
        context.coordinator.onTap = onTap
    }

    private func applyStyle(_ button: UIButton) {
        if onDark {
            button.backgroundColor = UIColor.white.withAlphaComponent(0.16)
            button.layer.borderColor = UIColor.white.withAlphaComponent(0.7).cgColor
            button.setTitleColor(.white, for: .normal)
        } else {
            button.backgroundColor = UIColor(red: 0.620, green: 0.239, blue: 0.133, alpha: 0.92)
            button.layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor
            button.setTitleColor(.white, for: .normal)
        }
    }
}

private final class WishAdSkipCoordinator: NSObject {
    var onTap: () -> Void

    init(onTap: @escaping () -> Void) {
        self.onTap = onTap
    }

    @objc func handleTap() {
        onTap()
    }
}
