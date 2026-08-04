import SwiftUI

/// The recurring care activities Leafy tracks for every plant.
enum CareKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case watering
    case fertilizing
    case repotting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .watering: "Watering"
        case .fertilizing: "Fertilizing"
        case .repotting: "Repotting"
        }
    }

    /// Label for the button that logs a finished task.
    var actionTitle: String {
        switch self {
        case .watering: "Water"
        case .fertilizing: "Feed"
        case .repotting: "Repot"
        }
    }

    /// Past-tense label used in history rows.
    var completedTitle: String {
        switch self {
        case .watering: "Watered"
        case .fertilizing: "Fertilized"
        case .repotting: "Repotted"
        }
    }

    var symbolName: String {
        switch self {
        case .watering: "drop.fill"
        case .fertilizing: "leaf.fill"
        case .repotting: "arrow.up.bin.fill"
        }
    }

    var tint: Color {
        switch self {
        case .watering: .leafWater
        case .fertilizing: .leafGold
        case .repotting: .leafClay
        }
    }

    var defaultIntervalDays: Int {
        switch self {
        case .watering: 7
        case .fertilizing: 30
        case .repotting: 365
        }
    }

    /// Bounds the schedule pickers so a task can never be set to an impossible cadence.
    var intervalRange: ClosedRange<Int> {
        switch self {
        case .watering: 1...60
        case .fertilizing: 7...180
        case .repotting: 30...1095
        }
    }
}
