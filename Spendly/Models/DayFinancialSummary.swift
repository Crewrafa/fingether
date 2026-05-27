import Foundation
import SwiftUI

// MARK: - Heat Level

enum HeatLevel: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case none       // No transactions
    case low        // Low spending
    case medium     // Moderate spending
    case high       // High spending
    case extreme    // Over-budget spending

    var id: Self { self }

    var color: Color {
        switch self {
        case .none: return Color(.systemGray5)
        case .low: return Color.fingetherPrimary.opacity(0.3)
        case .medium: return Color.fingetherWarning.opacity(0.5)
        case .high: return Color.fingetherWarning.opacity(0.6)
        case .extreme: return Color.fingetherDanger.opacity(0.8)
        }
    }

    var displayName: String {
        switch self {
        case .none: return "Sin actividad"
        case .low: return "Bajo"
        case .medium: return "Moderado"
        case .high: return "Alto"
        case .extreme: return "Excesivo"
        }
    }
}

// MARK: - Day Financial Summary

struct DayFinancialSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    var date: Date
    var totalIncome: Decimal
    var totalExpenses: Decimal
    var transactionCount: Int
    var heatLevel: HeatLevel
    var topCategory: TransactionCategory?
    var transactions: [Transaction]

    var netBalance: Decimal {
        totalIncome - totalExpenses
    }

    var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }
}
