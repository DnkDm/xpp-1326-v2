import SwiftData
import SwiftUI

struct RootView: View {
    @AppStorage(StorageKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var context

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainView()
                    .transition(.opacity)
            } else {
                OnboardingView { withAnimation(.snappy) { hasCompletedOnboarding = true } }
            }
        }
        .task { SampleData.seedIfNeeded(context) }
    }
}

// MARK: - Sections

/// The top-level destinations. The iPad sidebar lists all of them; the phone tab bar shows
/// the five in `tabBarSections` and reaches Insights and Settings from the Today toolbar,
/// so a tab bar never overflows into a "More" tab.
enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case today, plants, explore, calendar, journal, insights, settings

    var id: String { rawValue }

    /// Tabs the phone shows, in order.
    static let tabBarSections: [AppSection] = [.today, .plants, .explore, .calendar, .journal]

    var title: String {
        switch self {
        case .today: "Today"
        case .plants: "Plants"
        case .explore: "Explore"
        case .calendar: "Calendar"
        case .journal: "Journal"
        case .insights: "Insights"
        case .settings: "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .today: "sun.max.fill"
        case .plants: "leaf.fill"
        case .explore: "globe.europe.africa.fill"
        case .calendar: "calendar"
        case .journal: "photo.stack.fill"
        case .insights: "chart.bar.xaxis"
        case .settings: "gearshape.fill"
        }
    }

    @ViewBuilder
    var content: some View {
        switch self {
        case .today: TodayView()
        case .plants: PlantListView()
        case .explore: ExploreView()
        case .calendar: CareCalendarView()
        case .journal: JournalView()
        case .insights: InsightsView()
        case .settings: SettingsView()
        }
    }
}

// MARK: - Container

struct MainView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query private var plants: [Plant]

    @State private var selection: AppSection = .today

    var body: some View {
        Group {
            if sizeClass.usesPadLayout {
                SidebarLayout(selection: $selection)
            } else {
                TabLayout(selection: $selection)
            }
        }
        .task {
            // Pending notifications drift out of date whenever the app was closed while
            // reminders fired, so refresh the whole set once per launch.
            await NotificationService.shared.reschedule(for: plants)
        }
    }
}

// MARK: - iPhone

private struct TabLayout: View {
    @Binding var selection: AppSection

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppSection.tabBarSections) { section in
                NavigationStack {
                    section.content
                        .toolbar {
                            if section == .today {
                                todayToolbar
                            }
                        }
                }
                .tabItem { Label(section.title, systemImage: section.symbolName) }
                .tag(section)
            }
        }
    }

    /// Insights and Settings live behind the Today screen on the phone, where a sixth and
    /// seventh tab would have been folded into a "More" list.
    private var todayToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            NavigationLink {
                InsightsView()
            } label: {
                Label(AppSection.insights.title, systemImage: AppSection.insights.symbolName)
            }

            NavigationLink {
                SettingsView()
            } label: {
                Label(AppSection.settings.title, systemImage: AppSection.settings.symbolName)
            }
        }
    }
}

// MARK: - iPad

private struct SidebarLayout: View {
    @Binding var selection: AppSection

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $selection)
        } detail: {
            // A fresh stack per section, so a plant pushed in one section does not
            // linger behind another when the user comes back to it.
            NavigationStack {
                selection.content
            }
            .id(selection)
        }
        // Alongside the content in landscape, over it in portrait — which keeps the
        // detail column at full width, wide enough for the two-column layouts.
        .navigationSplitViewStyle(.automatic)
    }
}

private struct Sidebar: View {
    @Binding var selection: AppSection

    @Query private var plants: [Plant]

    var body: some View {
        List(selection: selectedSection) {
            Section("Garden") {
                ForEach([AppSection.today, .plants, .calendar, .journal]) { section in
                    Label(section.title, systemImage: section.symbolName)
                        .tag(section)
                }
            }

            Section("Discover") {
                ForEach([AppSection.explore, .insights]) { section in
                    Label(section.title, systemImage: section.symbolName)
                        .tag(section)
                }
            }

            Section {
                Label(AppSection.settings.title, systemImage: AppSection.settings.symbolName)
                    .tag(AppSection.settings)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Leafy")
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        .safeAreaInset(edge: .bottom) {
            Label(Format.plants(plants.count), systemImage: "leaf.fill")
                .font(.caption)
                .foregroundStyle(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
    }

    /// `List` hands back an optional selection; the app always has one section showing,
    /// so a deselect is ignored rather than emptying the detail column.
    private var selectedSection: Binding<AppSection?> {
        Binding(
            get: { selection },
            set: { if let new = $0 { selection = new } }
        )
    }
}

#Preview {
    MainView()
        .modelContainer(PreviewData.container)
}
