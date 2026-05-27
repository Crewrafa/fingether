import Foundation

// MARK: - Trip Status

enum TripStatus: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case planning
    case active
    case completed

    var id: Self { self }

    var displayName: String {
        switch self {
        case .planning: return "Planeando"
        case .active: return "En curso"
        case .completed: return "Completado"
        }
    }
}

// MARK: - Savings Mode

enum TripSavingsMode: String, Codable, Hashable, Sendable {
    case monthly     // Aporte mensual fijo → crea gasto recurrente
    case freeForm    // Aportes libres manuales
    case alreadyHave // Ya tiene el dinero
}

// MARK: - Trip Budget Category

struct TripBudgetCategory: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var emoji: String
    var budgetAmount: Decimal
    var spentAmount: Decimal

    var remainingAmount: Decimal {
        budgetAmount - spentAmount
    }

    var usagePercentage: Double {
        guard budgetAmount > 0 else { return 0 }
        return min(NSDecimalNumber(decimal: spentAmount / budgetAmount).doubleValue, 1.0)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, emoji
        case budgetAmount = "budget_amount"
        case spentAmount = "spent_amount"
    }
}

// MARK: - Trip

struct Trip: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var coupleId: UUID
    var name: String
    var emoji: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var totalBudget: Decimal
    var currency: String
    var status: TripStatus
    var categories: [TripBudgetCategory]
    var isShared: Bool
    var savingsMode: TripSavingsMode
    var monthlySavingsAmount: Decimal
    var currentSaved: Decimal
    var linkedTransactionId: UUID?
    var createdAt: Date

    var totalSpent: Decimal {
        categories.reduce(Decimal.zero) { $0 + $1.spentAmount }
    }

    var remainingBudget: Decimal {
        totalBudget - totalSpent
    }

    var savingsProgress: Double {
        guard totalBudget > 0 else { return 0 }
        return min(NSDecimalNumber(decimal: currentSaved / totalBudget).doubleValue, 1.0)
    }

    var monthsToGoal: Int? {
        guard monthlySavingsAmount > 0 else { return nil }
        let remaining = totalBudget - currentSaved
        guard remaining > 0 else { return 0 }
        return Int(ceil(NSDecimalNumber(decimal: remaining / monthlySavingsAmount).doubleValue))
    }

    var daysRemaining: Int {
        max(Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0, 0)
    }

    var isFunded: Bool {
        currentSaved >= totalBudget
    }

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, destination, currency, status, categories
        case coupleId = "couple_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case totalBudget = "total_budget"
        case isShared = "is_shared"
        case savingsMode = "savings_mode"
        case monthlySavingsAmount = "monthly_savings_amount"
        case currentSaved = "current_saved"
        case linkedTransactionId = "linked_transaction_id"
        case createdAt = "created_at"
    }
}
