import Foundation
import SwiftUI
import UIKit

/// Every `UserDefaults` key the app uses, in one place so they cannot drift apart.
enum StorageKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let appearance = "appearance"
    static let reminderTime = "reminderTime"
}

// MARK: - Appearance

enum Appearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light garden"
        case .dark: "Dark greenhouse"
        }
    }

    var symbolName: String {
        switch self {
        case .system: UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        case .light: "sun.max"
        case .dark: "moon.stars"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

// MARK: - Reminder time

/// Time of day at which care reminders are delivered.
struct ReminderTime: RawRepresentable, Equatable, Sendable {
    var hour: Int
    var minute: Int

    static let `default` = ReminderTime(hour: 9, minute: 0)

    init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    init?(rawValue: String) {
        let parts = rawValue.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        self.init(hour: parts[0], minute: parts[1])
    }

    var rawValue: String { "\(hour):\(minute)" }

    /// The stored preference. Services read this directly so callers never have to pass it around.
    static var current: ReminderTime {
        guard let raw = UserDefaults.standard.string(forKey: StorageKey.reminderTime),
              let time = ReminderTime(rawValue: raw)
        else { return .default }
        return time
    }

    func applied(to day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    init(from date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: parts.hour ?? 9, minute: parts.minute ?? 0)
    }
}
