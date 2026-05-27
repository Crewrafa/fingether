import Foundation

// MARK: - Savings Goal Status

enum SavingsGoalStatus: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case active
    case completed
    case cancelled

    var id: Self { self }

    var displayName: String {
        switch self {
        case .active: return "Activa"
        case .completed: return "Completada"
        case .cancelled: return "Cancelada"
        }
    }

    var iconName: String {
        switch self {
        case .active: return "target"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

// MARK: - Savings Goal

struct SavingsGoal: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let coupleId: UUID
    var name: String
    var description: String?
    var targetAmount: Decimal
    var currentAmount: Decimal
    var targetDate: Date?
    var emoji: String
    var status: SavingsGoalStatus
    var isShared: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case coupleId = "couple_id"
        case name
        case description
        case targetAmount = "target_amount"
        case currentAmount = "current_amount"
        case targetDate = "target_date"
        case emoji
        case status
        case isShared = "is_shared"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(id: UUID, coupleId: UUID, name: String, description: String?, targetAmount: Decimal, currentAmount: Decimal, targetDate: Date?, emoji: String, status: SavingsGoalStatus, isShared: Bool = true, createdAt: Date, updatedAt: Date) {
        self.id = id; self.coupleId = coupleId; self.name = name; self.description = description
        self.targetAmount = targetAmount; self.currentAmount = currentAmount; self.targetDate = targetDate
        self.emoji = emoji; self.status = status; self.isShared = isShared
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }

    /// Porcentaje de progreso hacia la meta (0.0 a 1.0+)
    var progressPercentage: Decimal {
        guard targetAmount > 0 else { return 0 }
        return currentAmount / targetAmount
    }

    /// Progreso como Double para ProgressView (0.0 a 1.0)
    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(NSDecimalNumber(decimal: currentAmount / targetAmount).doubleValue, 1.0)
    }

    /// Monto restante para alcanzar la meta
    var remainingAmount: Decimal {
        max(targetAmount - currentAmount, 0)
    }

    /// Si la meta fue alcanzada
    var isCompleted: Bool {
        currentAmount >= targetAmount
    }
}
