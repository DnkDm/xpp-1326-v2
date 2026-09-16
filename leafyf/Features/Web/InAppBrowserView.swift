import SwiftUI
import UIKit
import WebKit

// MARK: - Browser state

/// Owns the `WKWebView` and mirrors the few properties SwiftUI needs to draw chrome.
///
/// The web view is created once and kept here rather than in `makeUIView`, because
/// `UIViewRepresentable` may rebuild its view and a fresh `WKWebView` would drop the
/// back/forward history the toolbar is showing.
///
/// Building one is expensive — a web content process and a request — so `InAppBrowserView`
/// is careful to build it exactly once, off the view-update path.
@MainActor
@Observable
final class BrowserState {
    let webView: WKWebView

    var progress: Double = 0
    var isLoading = false
    var canGoBack = false
    var canGoForward = false
    var pageTitle = ""
    var currentURL: URL?

    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    init(url: URL?) {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        // Article pages only — no reason to keep cookies or storage around afterwards.
        configuration.websiteDataStore = .nonPersistent()

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        currentURL = url

        observe()

        if let url {
            webView.load(URLRequest(url: url))
        }
    }

    // MARK: Actions

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }

    func reloadOrStop() {
        if isLoading {
            webView.stopLoading()
        } else {
            webView.reload()
        }
    }

    // MARK: Observation

    /// KVO rather than a navigation delegate: these properties cover everything the
    /// chrome shows, and they update during a load instead of only at its end.
    private func observe() {
        observations = [
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] webView, _ in
                MainActor.assumeIsolated { self?.progress = webView.estimatedProgress }
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] webView, _ in
                MainActor.assumeIsolated { self?.isLoading = webView.isLoading }
            },
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, _ in
                MainActor.assumeIsolated { self?.canGoBack = webView.canGoBack }
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] webView, _ in
                MainActor.assumeIsolated { self?.canGoForward = webView.canGoForward }
            },
            webView.observe(\.title, options: [.initial, .new]) { [weak self] webView, _ in
                MainActor.assumeIsolated { self?.pageTitle = webView.title ?? "" }
            },
            webView.observe(\.url, options: [.initial, .new]) { [weak self] webView, _ in
                MainActor.assumeIsolated { self?.currentURL = webView.url }
            },
        ]
    }
}

// MARK: - Web view

/// The bare `WKWebView`, with no chrome of its own.
private struct WebViewRepresentable: UIViewRepresentable {
    let state: BrowserState

    func makeUIView(context: Context) -> WKWebView {
        state.webView.backgroundColor = UIColor(Color.surface)
        state.webView.isOpaque = false
        return state.webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

// MARK: - Browser

/// An article reader: the page itself, a hairline progress bar, and a bottom bar with
/// history, share and "Open in Safari".
///
/// Pushed onto a stack, or wrapped in `BrowserScreen` when it is presented as a sheet.
struct InAppBrowserView: View {
    let url: URL

    /// Built on first appearance rather than in `init`. A parent's body can be evaluated any
    /// number of times, and a `BrowserState` built there would spin up a `WKWebView` and fire
    /// its own request every time, before `@State` threw all but the first one away.
    @State private var state: BrowserState?

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()

            if let state {
                BrowserBody(state: state, requestedURL: url)
            }
        }
        .navigationTitle("Loading…")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard state == nil else { return }
            state = BrowserState(url: url)
        }
    }
}

/// The page and its chrome, once there is a web view to show.
private struct BrowserBody: View {
    let state: BrowserState
    /// Stood in for sharing until the web view reports a URL of its own.
    let requestedURL: URL

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            progressBar
            WebViewRepresentable(state: state)
        }
        .navigationTitle(state.pageTitle.isEmpty ? "Loading…" : state.pageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { bottomBar }
        .toolbarBackground(.visible, for: .bottomBar)
    }

    // MARK: - Chrome

    /// Only drawn mid-load, so a finished page is not left with a stray full-width line.
    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Color.hairline
            GeometryReader { proxy in
                Color.leafGreen
                    .frame(width: proxy.size.width * state.progress)
            }
        }
        .frame(height: 2)
        .opacity(state.isLoading ? 1 : 0)
        .animation(.snappy(duration: 0.25), value: state.progress)
        .animation(.snappy, value: state.isLoading)
        .accessibilityHidden(true)
    }

    @ToolbarContentBuilder
    private var bottomBar: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Button {
                state.goBack()
            } label: {
                Label("Back", systemImage: "chevron.backward")
            }
            .disabled(!state.canGoBack)

            Spacer()

            Button {
                state.goForward()
            } label: {
                Label("Forward", systemImage: "chevron.forward")
            }
            .disabled(!state.canGoForward)

            Spacer()

            ShareLink(item: shareURL) {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Spacer()

            Button {
                openURL(shareURL)
            } label: {
                Label("Open in Safari", systemImage: "safari")
            }

            Spacer()

            Button {
                state.reloadOrStop()
            } label: {
                Label(
                    state.isLoading ? "Stop" : "Reload",
                    systemImage: state.isLoading ? "xmark" : "arrow.clockwise"
                )
            }
        }
    }

    /// Share whatever the reader is actually looking at, not where they started.
    private var shareURL: URL { state.currentURL ?? requestedURL }
}

// MARK: - Sheet wrapper

/// `InAppBrowserView` with the stack and Done button a sheet needs.
struct BrowserScreen: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            InAppBrowserView(url: url)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

// MARK: - Sheet item

/// A `URL` that can drive `.sheet(item:)`, which needs an `Identifiable`.
struct BrowserLink: Identifiable, Hashable {
    let url: URL

    var id: String { url.absoluteString }
}

#Preview("Browser") {
    BrowserScreen(url: URL(string: "https://en.wikipedia.org/wiki/Monstera_deliciosa")!)
}
