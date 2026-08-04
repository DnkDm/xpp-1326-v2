import SwiftData
import SwiftUI

struct RootView: View {
    @AppStorage(StorageKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            MainTabView()
                .transition(.opacity)
        } else {
            OnboardingView { withAnimation(.snappy) { hasCompletedOnboarding = true } }
        }
    }
}

struct MainTabView: View {
    @Query private var plants: [Plant]
    @State private var selection: Tab = .today

    enum Tab: Hashable {
        case today, plants, calendar, journal, settings
    }

    var body: some View {
        TabView(selection: $selection) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(Tab.today)

            PlantListView()
                .tabItem { Label("Plants", systemImage: "leaf.fill") }
                .tag(Tab.plants)

            CareCalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(Tab.calendar)

            JournalView()
                .tabItem { Label("Journal", systemImage: "photo.stack.fill") }
                .tag(Tab.journal)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .task {
            // Pending notifications drift out of date whenever the app was closed while
            // reminders fired, so refresh the whole set once per launch.
            await NotificationService.shared.reschedule(for: plants)
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(PreviewData.container)
}
