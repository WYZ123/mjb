import SwiftUI
import WebKit

private final class WishWebNavigationBridge {
    weak var webView: WKWebView?

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }
}

private struct WishWebLayoutMetrics: Equatable {
    let safeAreaInsets: EdgeInsets
    let contentSize: CGSize

    static let zero = WishWebLayoutMetrics(
        safeAreaInsets: EdgeInsets(),
        contentSize: .zero
    )
}

struct WishEmbeddedBrowserView: View {
    let urlString: String
    var showsToolbar: Bool = true
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isPageLoading = true
    @State private var bridge = WishWebNavigationBridge()
    @State private var payFieldStore = WishPayFieldStore()

    private let toolbarMinHeight: CGFloat = 48

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                WishWebViewRepresentable(
                    urlString: urlString,
                    bridge: bridge,
                    payFieldStore: payFieldStore,
                    showsToolbar: showsToolbar,
                    layoutMetrics: WishWebLayoutMetrics(
                        safeAreaInsets: EdgeInsets(
                            top: geometry.safeAreaInsets.top,
                            leading: geometry.safeAreaInsets.leading,
                            bottom: showsToolbar ? geometry.safeAreaInsets.bottom : 0,
                            trailing: geometry.safeAreaInsets.trailing
                        ),
                        contentSize: geometry.size
                    ),
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    isPageLoading: $isPageLoading
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .background(Color.white)
            .ignoresSafeArea(edges: showsToolbar ? [] : .bottom)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showsToolbar {
                    webToolbar
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .task {
            await payFieldStore.load()
        }
    }

    private var webToolbar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 0) {
                toolbarButton(systemImage: "chevron.backward", enabled: canGoBack) {
                    bridge.goBack()
                }

                Divider().frame(height: 28)

                toolbarButton(systemImage: "chevron.forward", enabled: canGoForward) {
                    bridge.goForward()
                }

                Divider().frame(height: 28)

                toolbarButton(systemImage: "arrow.clockwise", enabled: true) {
                    bridge.reload()
                }
            }
            .frame(minHeight: toolbarMinHeight)
        }
        .background {
            Color(.systemBackground)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func toolbarButton(
        systemImage: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: toolbarMinHeight)
                .contentShape(Rectangle())
                .foregroundStyle(enabled ? Color.primary : Color.secondary)
        }
        .disabled(!enabled)
    }
}

private final class WishWebViewContainer: UIView {
    let webView: WKWebView

    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)
        backgroundColor = .white
        addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset = .zero
        webView.scrollView.verticalScrollIndicatorInsets = .zero
        webView.scrollView.keyboardDismissMode = .interactive
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.showsHorizontalScrollIndicator = false
    }

    func applyShowsToolbar(_ showsToolbar: Bool) {
        webView.scrollView.contentInsetAdjustmentBehavior = showsToolbar ? .automatic : .never
        if !showsToolbar {
            webView.scrollView.contentInset = .zero
            webView.scrollView.scrollIndicatorInsets = .zero
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct WishWebViewRepresentable: UIViewRepresentable {
    let urlString: String
    let bridge: WishWebNavigationBridge
    let payFieldStore: WishPayFieldStore
    let showsToolbar: Bool
    let layoutMetrics: WishWebLayoutMetrics
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isPageLoading: Bool

    func makeCoordinator() -> WishWebCoordinator {
        WishWebCoordinator(
            bridge: bridge,
            payFieldStore: payFieldStore,
            canGoBack: $canGoBack,
            canGoForward: $canGoForward,
            isPageLoading: $isPageLoading
        )
    }

    func makeUIView(context: Context) -> WishWebViewContainer {
        let config = WKWebViewConfiguration()
        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences = preferences
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.defaultWebpagePreferences.preferredContentMode = .mobile

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = true
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 5.0

        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        let container = WishWebViewContainer(webView: webView)
        container.applyShowsToolbar(showsToolbar)
        bridge.webView = webView
        context.coordinator.webView = webView
        context.coordinator.lastLoadedURLString = urlString
        context.coordinator.applyLayoutMetrics(layoutMetrics)
        load(urlString, in: webView)
        return container
    }

    func updateUIView(_ container: WishWebViewContainer, context: Context) {
        let webView = container.webView
        context.coordinator.webView = webView
        bridge.webView = webView
        context.coordinator.applyLayoutMetrics(layoutMetrics)
        container.applyShowsToolbar(showsToolbar)

        if context.coordinator.lastLoadedURLString != urlString {
            context.coordinator.lastLoadedURLString = urlString
            isPageLoading = true
            load(urlString, in: webView)
        }
    }

    private func load(_ urlString: String, in webView: WKWebView) {
        guard let url = URL(string: urlString) else {
            print("[WebView] Invalid URL: \(urlString)")
            return
        }
        print("[WebView] Loading URL: \(url.absoluteString)")
        webView.load(URLRequest(url: url))
    }
}

private final class WishWebCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    let bridge: WishWebNavigationBridge
    let payFieldStore: WishPayFieldStore
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isPageLoading: Bool
    weak var webView: WKWebView?
    var lastLoadedURLString: String?
    private var lastAppliedMetrics = WishWebLayoutMetrics.zero

    init(
        bridge: WishWebNavigationBridge,
        payFieldStore: WishPayFieldStore,
        canGoBack: Binding<Bool>,
        canGoForward: Binding<Bool>,
        isPageLoading: Binding<Bool>
    ) {
        self.bridge = bridge
        self.payFieldStore = payFieldStore
        _canGoBack = canGoBack
        _canGoForward = canGoForward
        _isPageLoading = isPageLoading
    }

    func applyLayoutMetrics(_ metrics: WishWebLayoutMetrics) {
        guard metrics.contentSize.width > 0, metrics.contentSize.height > 0 else { return }
        guard metrics != lastAppliedMetrics else { return }
        lastAppliedMetrics = metrics
        guard let webView else { return }

        let script = WishWebViewportAdapter.layoutScript(for: metrics)
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        preferences.allowsContentJavaScript = true
        preferences.preferredContentMode = .mobile

        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel, preferences)
            return
        }

        if payFieldStore.openExternalIfMatched(url) {
            decisionHandler(.cancel, preferences)
            return
        }

        decisionHandler(.allow, preferences)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil,
              let url = navigationAction.request.url else {
            return nil
        }

        switch navigationAction.navigationType {
        case .linkActivated, .other:
            if payFieldStore.openExternalIfMatched(url) {
                return nil
            }
            openInSafari(url)
        default:
            break
        }

        return nil
    }

    private func openInSafari(_ url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        applyLayoutMetrics(lastAppliedMetrics)
        syncNavigationState(for: webView)
        setPageLoading(false)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        setPageLoading(false)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        setPageLoading(false)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        syncNavigationState(for: webView)
    }

    private func setPageLoading(_ loading: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isPageLoading = loading
        }
    }

    private func syncNavigationState(for webView: WKWebView) {
        let back = webView.canGoBack
        let forward = webView.canGoForward
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.canGoBack = back
            self.canGoForward = forward
        }
    }
}

private enum WishWebViewportAdapter {
    static func layoutScript(for metrics: WishWebLayoutMetrics) -> String {
        let width = formatted(metrics.contentSize.width)
        let height = formatted(metrics.contentSize.height)
        let top = formatted(metrics.safeAreaInsets.top)
        let bottom = formatted(metrics.safeAreaInsets.bottom)
        let left = formatted(metrics.safeAreaInsets.leading)
        let right = formatted(metrics.safeAreaInsets.trailing)

        return """
        (function() {
            var meta = document.querySelector('meta[name="viewport"]');
            if (!meta) {
                meta = document.createElement('meta');
                meta.name = 'viewport';
                document.head.appendChild(meta);
            }
            meta.content = 'width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=5.0, viewport-fit=cover';

            var style = document.getElementById('wishsaver-layout-style');
            if (!style) {
                style = document.createElement('style');
                style.id = 'wishsaver-layout-style';
                document.head.appendChild(style);
            }

            style.textContent = `
                :root {
                    --device-width: \(width)px;
                    --device-height: \(height)px;
                    --safe-top: \(top)px;
                    --safe-bottom: \(bottom)px;
                    --safe-left: \(left)px;
                    --safe-right: \(right)px;
                }
                html {
                    width: 100%;
                    height: -webkit-fill-available;
                    -webkit-text-size-adjust: 100%;
                }
                body {
                    width: 100%;
                    min-height: 100%;
                    min-height: -webkit-fill-available;
                    margin: 0;
                    overflow-x: hidden;
                    -webkit-overflow-scrolling: touch;
                    -webkit-text-size-adjust: 100%;
                }
                img, video, canvas, iframe {
                    max-width: 100%;
                }
            `;
        })();
        """
    }

    private static func formatted(_ value: CGFloat) -> String {
        String(format: "%.2f", value)
    }
}
