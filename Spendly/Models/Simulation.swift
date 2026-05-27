import Foundation

// MARK: - Simulation Type

enum SimulationType: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case debtPayoff = "debt_payoff"
    case savingsProjection = "savings_projection"
    case expenseReduction = "expense_reduction"
    case incomeIncrease = "income_increase"
    case emergencyFund = "emergency_fund"

    var id: Self { self }

    var displayName: String {
        switch self {
        case .debtPayoff: return "Pago de deuda"
        case .savingsProjection: return "Proyeccion de ahorro"
        case .expenseReduction: return "Reduccion de gastos"
        case .incomeIncrease: return "Aumento de ingresos"
        case .emergencyFund: return "Fondo de emergencia"
        }
    }

    var emoji: String {
        switch self {
        case .debtPayoff: return "💳"
        case .savingsProjection: return "📈"
        case .expenseReduction: return "✂️"
        case .incomeIncrease: return "💰"
        case .emergencyFund: return "🛡️"
        }
    }
}

// MARK: - Simulation Params

struct SimulationParams: Codable, Hashable, Sendable {
    var monthlyAmount: Decimal
    var targetAmount: Decimal?
    var interestRate: Decimal?
    var months: Int
    var category: TransactionCategory?

    enum CodingKeys: String, CodingKey {
        case months, category
        case monthlyAmount = "monthly_amount"
        case targetAmount = "target_amount"
        case interestRate = "interest_rate"
    }
}

// MARK: - Simulation Result

struct SimulationResult: Codable, Hashable, Sendable {
    var projectedTotal: Decimal
    var monthlyBreakdown: [Decimal]
    var savingsGain: Decimal
    var timeToGoalMonths: Int?
    var summary: String

    enum CodingKeys: String, CodingKey {
        case summary
        case projectedTotal = "projected_total"
        case monthlyBreakdown = "monthly_breakdown"
        case savingsGain = "savings_gain"
        case timeToGoalMonths = "time_to_goal_months"
    }
}

// MARK: - Risk Level

enum RiskLevel: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case low
    case medium
    case high

    var id: Self { self }

    var displayName: String {
        switch self {
        case .low: return "Bajo"
        case .medium: return "Medio"
        case .high: return "Alto"
        }
    }

    var emoji: String {
        switch self {
        case .low: return "🟢"
        case .medium: return "🟡"
        case .high: return "🔴"
        }
    }
}

// MARK: - Simulation

struct Simulation: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var coupleId: UUID
    var name: String
    var type: SimulationType
    var params: SimulationParams
    var result: SimulationResult?
    var riskLevel: RiskLevel
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, type, params, result
        case coupleId = "couple_id"
        case riskLevel = "risk_level"
        case createdAt = "created_at"
    }
}
