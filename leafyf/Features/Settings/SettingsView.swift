import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Query private var plants: [Plant]
    @Environment(\.openURL) private var openURL

    @AppStorage(StorageKey.appearance) private var appearance: Appearance = .system
    @AppStorage(StorageKey.reminderTime) private var reminderTimeRaw = ReminderTime.default.rawValue
    @AppStorage(StorageKey.hasCompletedOnboarding) private var hasCompletedOnboarding = true

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isShowingLibrary = false

    private var reminderTime: ReminderTime {
        ReminderTime(rawValue: reminderTimeRaw) ?? .default
    }

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                remindersSection
                librarySection
                aboutSection
            }
            .canvasBackground()
            .navigationTitle("Settings")
            .sheet(isPresented: $isShowingLibrary) {
                PlantLibraryView()
            }
            .task { notificationStatus = await NotificationService.shared.authorizationStatus() }
            .onChange(of: reminderTimeRaw) {
                Task { await NotificationService.shared.reschedule(for: plants) }
            }
        }
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $appearance) {
                ForEach(Appearance.allCases) { option in
                    Label(option.title, systemImage: option.symbolName)
                        .tag(option)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }

    private var remindersSection: some View {
        Section {
            DatePicker(
                "Reminder time",
                selection: Binding(
                    get: { reminderTime.applied(to: .now) },
                    set: { reminderTimeRaw = ReminderTime(from: $0).rawValue }
                ),
                displayedComponents: .hourAndMinute
            )

            switch notificationStatus {
            case .authorized, .provisional, .ephemeral:
                Label("Notifications are on", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.leafGreen)

            case .denied:
                Button("Turn on notifications in Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }

            default:
                Button("Allow notifications") {
                    Task {
                        await NotificationService.shared.requestAuthorization()
                        notificationStatus = await NotificationService.shared.authorizationStatus()
                        await NotificationService.shared.reschedule(for: plants)
                    }
                }
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("Care reminders arrive at this time on the day a task falls due. Turn them off per plant when editing it.")
        }
    }

    private var librarySection: some View {
        Section("Plants") {
            Button("Browse plant library") { isShowingLibrary = true }

            LabeledContent("Tracked plants", value: Format.plants(plants.count))
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Bundle.main.shortVersion)

            Button("Replay onboarding") { hasCompletedOnboarding = false }
        }
    }
}

extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.container)
}
