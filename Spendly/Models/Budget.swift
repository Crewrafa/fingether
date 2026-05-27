import Foundation

// MARK: - Budget Period

enum BudgetPeriod: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case weekly
    case biweekly
    case monthly

    var id: Self { self }

    var displayName: String {
        switch self {
        case .weekly: return "Semanal"
        case .biweekly: return "Quincenal"
        case .monthly: return "Mensual"
        }
    }

    var iconName: String {
        switch self {
        case .weekly: return "calendar.badge.clock"
        case .biweekly: return "calendar"
        case .monthly: return "calendar.circle.fill"
        }
    }
}

// MARK: - Budget

struct Budget: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let coupleId: UUID
    var category: TransactionCategory
    var amountLimit: Decimal
    var period: BudgetPeriod
    var currentSpent: Decimal
    var alertThreshold: Decimal
    var isActive: Bool
    var startDate: Date
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case coupleId = "couple_id"
        case category
        case amountLimit = "amount_limit"
        case period
        case currentSpent = "current_spent"
        case alertThreshold = "alert_threshold"
        case isActive = "is_active"
        case startDate = "start_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Porcentaje del presupuesto utilizado (0.0 a 1.0+)
    var usagePercentage: Decimal {
        guard amountLimit > 0 else { return 0 }
        return currentSpent / amountLimit
    }

    /// Monto restante del presupuesto
    var remainingAmount: Decimal {
        amountLimit - currentSpent
    }

    /// Si el gasto actual supera el umbral de alerta
    var isOverThreshold: Bool {
        guard amountLimit > 0 else { return false }
        return currentSpent / amountLimit >= alertThreshold
    }

    /// Si el presupuesto fue excedido
    var isOverBudget: Bool {
        currentSpent > amountLimit
    }
}
