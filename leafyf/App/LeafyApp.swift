import MyLibrary
import SwiftData
import SwiftUI

@main
struct LeafyApp: App {
    @UIApplicationDelegateAdaptor(MAppDelegators.self) private var appDelegate
    @AppStorage(StorageKey.appearance) private var appearance: Appearance = .system

    var body: some Scene {
        WindowGroup {
            GScreen {
                RootView()
                    .preferredColorScheme(appearance.colorScheme)
                    .tint(.leafGreen)
            }
        }
        .modelContainer(for: [Plant.self, CareLogEntry.self, JournalEntry.self])
    }
}
