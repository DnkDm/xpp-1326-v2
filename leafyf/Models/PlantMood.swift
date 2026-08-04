import SwiftUI

/// A one-glance summary of how a plant is doing, derived from its care schedule.
enum PlantMood: String, CaseIterable, Sendable {
    case overdue
    case dueToday
    case settlingIn
    case thriving

    var title: String {
        switch self {
        case .overdue: "Overdue"
        case .dueToday: "Due today"
        case .settlingIn: "Settling in"
        case .thriving: "Thriving"
        }
    }

    var emoji: String {
        switch self {
        case .overdue: "⚠️"
        case .dueToday: "💧"
        case .settlingIn: "🌱"
        case .thriving: "😊"
        }
    }

    var tint: Color {
        switch self {
        case .overdue: .leafClay
        case .dueToday: .leafGold
        case .settlingIn: .leafMint
        case .thriving: .leafGreen
        }
    }
}
