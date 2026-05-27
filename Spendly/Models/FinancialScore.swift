import Foundation
import SwiftUI

// MARK: - Score Breakdown

struct ScoreBreakdown: Codable, Hashable, Sendable {
    var budgetAdherence: Int       // 0-100: staying within budgets
    var savingsRate: Int           // 0-100: savings vs income ratio
    var debtManagement: Int        // 0-100: debt reduction progress
    var transactionConsistency: Int // 0-100: regular tracking habit
    var goalProgress: Int          // 0-100: savings goals progress
    var spendingDiversity: Int     // 0-100: balanced spending across categories

    var overall: Int {
        let total = budgetAdherence + savingsRate + debtManagement + transactionConsistency + goalProgress + spendingDiversity
        return total / 6
    }

    enum CodingKeys: String, CodingKey {
        case budgetAdherence = "budget_adherence"
        case savingsRate = "savings_rate"
        case debtManagement = "debt_management"
        case transactionConsistency = "transaction_consistency"
        case goalProgress = "goal_progress"
        case spendingDiversity = "spending_diversity"
    }
}

// MARK: - Score Trend

enum ScoreTrend: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case up
    case stable
    case down

    var id: Self { self }

    var arrow: String {
        switch self {
        case .up: return "↑"
        case .stable: return "→"
        case .down: return "↓"
        }
    }

    var iconName: String {
        switch self {
        case .up: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .down: return "arrow.down.right"
        }
    }

    var color: Color {
        switch self {
        case .up: return Color.fingetherForest
        case .stable: return Color.fingetherAmber     // stable = amber (not expense slate via honey alias)
        case .down: return Color.fingetherDanger
        }
    }
}

// MARK: - Financial Score

struct FinancialScore: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var coupleId: UUID
    var score: Int
    var breakdown: ScoreBreakdown
    var trend: ScoreTrend
    var tips: [String]
    var calculatedAt: Date

    var scoreColor: Color {
        switch score {
        case 75...100: return Color.fingetherForest      // Excelente
        case 60..<75: return Color.fingetherAmber      // Bien (amber, no honey alias)
        case 40..<60: return Color.fingetherWarning    // Regular (orange warning, NOT expense slate)
        default: return Color.fingetherDanger           // Bajo (deep pink)
        }
    }

    var scoreLabel: String {
        switch score {
        case 85...100: return "Excelente"
        case 75..<85: return "Muy bien"
        case 60..<75: return "Bien"
        case 40..<60: return "Regular"
        case 20..<40: return "Necesita mejora"
        default: return "Critico"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, score, breakdown, trend, tips
        case coupleId = "couple_id"
        case calculatedAt = "calculated_at"
    }
}
