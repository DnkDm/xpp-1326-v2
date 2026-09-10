import AppsFlyerLib
import Foundation

// MARK: - Attribution Manager

/// Thin wrapper around the AppsFlyer SDK. Starts the SDK once and exposes the
/// first conversion data payload as a JSON string for the compatibility check.
@MainActor
public final class AttributionManager: NSObject {

    public static let shared = AttributionManager()

    private var conversionData: String?
    private var isConfigured = false

    private override init() {
        super.init()
    }

    /// AppsFlyer UID, empty until the SDK has been started.
    public var appsFlyerID: String {
        isConfigured ? AppsFlyerLib.shared().getAppsFlyerUID() : ""
    }

    /// Starts the SDK. With an empty dev key the SDK stays off and
    /// conversion data resolves to `disabled` immediately.
    public func configure() {
        guard !isConfigured else { return }
        guard !CompatibilityConfig.appsFlyerDevKey.isEmpty else {
            resolve("disabled")
            return
        }
        isConfigured = true
        let lib = AppsFlyerLib.shared()
        lib.initialize(devKey: CompatibilityConfig.appsFlyerDevKey, appId: CompatibilityConfig.appleAppID)
        lib.delegate = self
        lib.start()
    }

    /// Waits for the first conversion data callback, or returns `timeout`.
    public func awaitConversionData(timeout: Duration) async -> String {
        let deadline = ContinuousClock.now + timeout
        while conversionData == nil, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(200))
        }
        return conversionData ?? "timeout"
    }

    private func resolve(_ value: String) {
        guard conversionData == nil else { return }
        conversionData = value
    }
}

// MARK: - AppsFlyerLibDelegate

// AppsFlyer invokes its delegate on the main thread, so the main-actor
// isolated methods below are safe under a `@preconcurrency` conformance.
extension AttributionManager: @preconcurrency AppsFlyerLibDelegate {

    public func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        let json = (try? JSONSerialization.data(withJSONObject: data))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        resolve(json)
    }

    public func onConversionDataFail(_ error: Error) {
        resolve("error")
    }
}
