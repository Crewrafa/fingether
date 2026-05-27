import Foundation

// MARK: - Challenge Type

enum ChallengeType: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case noSpend = "no_spend"
    case savingsSprint = "savings_sprint"
    case budgetStreak = "budget_streak"
    case categoryLimit = "category_limit"
    case incomeBoost = "income_boost"

    var id: Self { self }

    var displayName: String {
        switch self {
        case .noSpend: return "Sin gastar"
        case .savingsSprint: return "Sprint de ahorro"
        case .budgetStreak: return "Racha de presupuesto"
        case .categoryLimit: return "Limite por categoria"
        case .incomeBoost: return "Impulso de ingresos"
        }
    }

    var emoji: String {
        switch self {
        case .noSpend: return "🚫"
        case .savingsSprint: return "🏃"
        case .budgetStreak: return "🔥"
        case .categoryLimit: return "📊"
        case .incomeBoost: return "💪"
        }
    }
}

// MARK: - Challenge Metric

enum ChallengeMetric: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case amount
    case count
    case days
    case percentage

    var id: Self { self }

    var displayName: String {
        switch self {
        case .amount: return "Monto"
        case .count: return "Cantidad"
        case .days: return "Dias"
        case .percentage: return "Porcentaje"
        }
    }
}

// MARK: - Challenge Status

enum ChallengeStatus: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case active
    case completed
    case failed
    case cancelled

    var id: Self { self }

    var displayName: String {
        switch self {
        case .active: return "Activo"
        case .completed: return "Completado"
        case .failed: return "Fallido"
        case .cancelled: return "Cancelado"
        }
    }

    var emoji: String {
        switch self {
        case .active: return "⚡"
        case .completed: return "✅"
        case .failed: return "❌"
        case .cancelled: return "🚫"
        }
    }
}

// MARK: - Challenge Difficulty

enum ChallengeDifficulty: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case easy
    case medium
    case hard
    case extreme

    var id: Self { self }

    var displayName: String {
        switch self {
        case .easy: return "Facil"
        case .medium: return "Medio"
        case .hard: return "Dificil"
        case .extreme: return "Extremo"
        }
    }

    var emoji: String {
        switch self {
        case .easy: return "🌱"
        case .medium: return "🌿"
        case .hard: return "🔥"
        case .extreme: return "💀"
        }
    }

    var xpReward: Int {
        switch self {
        case .easy: return 50
        case .medium: return 100
        case .hard: return 200
        case .extreme: return 500
        }
    }
}

// MARK: - Financial Challenge

struct FinancialChallenge: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var coupleId: UUID
    var name: String
    var description: String
    var type: ChallengeType
    var metric: ChallengeMetric
    var targetValue: Decimal
    var currentValue: Decimal
    var difficulty: ChallengeDifficulty
    var status: ChallengeStatus
    var startDate: Date
    var endDate: Date
    var category: TransactionCategory?
    var xpReward: Int
    var createdAt: Date

    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(NSDecimalNumber(decimal: currentValue / targetValue).doubleValue, 1.0)
    }

    var isExpired: Bool {
        Date() > endDate && status == .active
    }

    var daysRemaining: Int {
        max(Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0, 0)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, type, metric, status, category, difficulty
        case coupleId = "couple_id"
        case targetValue = "target_value"
        case currentValue = "current_value"
        case startDate = "start_date"
        case endDate = "end_date"
        case xpReward = "xp_reward"
        case createdAt = "created_at"
    }
}
