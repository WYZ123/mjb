import CoreTelephony
import Foundation
import SwiftUI
import UIKit

@MainActor
final class WishLaunchRouter: ObservableObject {
    enum Route: Equatable {
        case loading
        case enterCode
        case webView(url: String, showsToolbar: Bool)
        case tabAd
        case remoteAd(imageURL: String)
        case mainApp
    }

    @Published private(set) var route: Route = .loading
    @Published private(set) var webViewLoadToken = UUID()

    private var hasChecked = false
    private let networkSignal = WishNetworkSignal()
    private var cellularData: CTCellularData?
    private var activeObserver: NSObjectProtocol?

    func checkVersionIfNeeded() async {
        guard !hasChecked else { return }
        hasChecked = true

        if WishLaunchConfig.forceMainApp {
            route = .mainApp
            return
        }

        route = .loading
        let startedAt = Date()

        let firstFetch: Result<WishVersionResult, Error>?
        if WishLaunchDateGate.shouldEnterMainAppDirectly {
            firstFetch = nil
        } else {
            firstFetch = await fetchVersionResult()
        }

        let remaining = 3 - Date().timeIntervalSince(startedAt)
        if remaining > 0 {
            try? await Task.sleep(for: .seconds(remaining))
        }

        if WishLaunchDateGate.shouldEnterMainAppDirectly {
            route = .mainApp
            return
        }

        switch firstFetch {
        case .success(let version):
            applyVersion(version)
        case .failure:
            await enterWebViewAfterFailedRequest()
        case nil:
            route = .mainApp
        }
    }

    func finishAd() {
        route = .mainApp
    }

    func submitAccessCode(_ raw: String) async -> String? {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return "Enter a code" }

        do {
            let result = try await WishCodeClient.fetch(code: code, udid: WishDeviceIdentity.getUniqueID())
            guard result.code == 1 else {
                return result.msg?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Invalid code"
            }
            let url = result.data?.url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !url.isEmpty else {
                return result.msg?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Invalid code"
            }
            openWebView(url: url, showsToolbar: result.data?.isTabbar == 1)
            return nil
        } catch {
            WishNetworkLogger.logError(tag: "CodeAPI", error: error)
            return "Couldn't verify the code"
        }
    }

    private func applyVersion(_ version: WishVersionResult?) {
        guard let version, version.code == 1, let data = version.data else {
            route = .mainApp
            return
        }

        if data.status == 1 {
            route = .mainApp
            return
        }

        if data.status == 2 {
            if data.isCode == 1 {
                route = .enterCode
                return
            }
            let url = data.url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !url.isEmpty {
                openWebView(url: url, showsToolbar: data.isTabbar == 1)
                return
            }
        }

        route = .mainApp
    }

    /// The first `get_version` often fails while the system wireless-data alert is up.
    /// Stay off the savings app, retry after the choice, and open the web view when a URL comes back.
    private func enterWebViewAfterFailedRequest() async {
        beginWatchingNetworkChoice()
        defer { endWatchingNetworkChoice() }

        if let version = await fetchVersionSafely() {
            applyVersion(version)
            return
        }

        for _ in 0..<4 {
            await networkSignal.wait(timeout: .seconds(8))
            if let version = await fetchVersionSafely() {
                applyVersion(version)
                return
            }
        }
    }

    private func beginWatchingNetworkChoice() {
        if cellularData == nil {
            let cellular = CTCellularData()
            cellular.cellularDataRestrictionDidUpdateNotifier = { [weak self] state in
                guard state != .restrictedStateUnknown else { return }
                Task { @MainActor in
                    self?.networkSignal.signal()
                }
            }
            cellularData = cellular
        }

        if activeObserver == nil {
            activeObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.networkSignal.signal()
                }
            }
        }
    }

    private func endWatchingNetworkChoice() {
        cellularData?.cellularDataRestrictionDidUpdateNotifier = nil
        cellularData = nil
        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
            self.activeObserver = nil
        }
    }

    private func openWebView(url: String, showsToolbar: Bool) {
        webViewLoadToken = UUID()
        route = .webView(url: url, showsToolbar: showsToolbar)
    }

    private func fetchVersionResult() async -> Result<WishVersionResult, Error> {
        do {
            let version = try await WishVersionClient.fetchVersion(
                appVersion: WishAppMetadata.appVersion,
                udid: WishDeviceIdentity.getUniqueID()
            )
            return .success(version)
        } catch {
            WishNetworkLogger.logError(tag: "VersionAPI", error: error)
            return .failure(error)
        }
    }

    private func fetchVersionSafely() async -> WishVersionResult? {
        switch await fetchVersionResult() {
        case .success(let version):
            return version
        case .failure:
            return nil
        }
    }
}

@MainActor
private final class WishNetworkSignal {
    private var continuation: CheckedContinuation<Void, Never>?
    private var generation = 0

    func wait(timeout: Duration) async {
        generation += 1
        let generation = generation
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.continuation = continuation
            Task { @MainActor in
                try? await Task.sleep(for: timeout)
                self.signal(generation: generation)
            }
        }
    }

    func signal() {
        signal(generation: generation)
    }

    private func signal(generation: Int) {
        guard generation == self.generation else { return }
        continuation?.resume()
        continuation = nil
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
