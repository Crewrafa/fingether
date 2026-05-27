import Foundation

// MARK: - Transaction Type

enum TransactionType: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case income
    case expense

    var id: Self { self }

    var displayName: String {
        switch self {
        case .income: return "Ingreso"
        case .expense: return "Gasto"
        }
    }

    var iconName: String {
        switch self {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        }
    }
}

// MARK: - Transaction Category

enum TransactionCategory: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case food
    case transport
    case housing
    case utilities
    case entertainment
    case health
    case education
    case shopping
    case travel
    case gifts
    case savings
    case debt
    case investments
    case salary
    case freelance
    case other

    var id: Self { self }

    var displayName: String {
        switch self {
        case .food: return "Comida"
        case .transport: return "Transporte"
        case .housing: return "Vivienda"
        case .utilities: return "Servicios"
        case .entertainment: return "Entretenimiento"
        case .health: return "Salud"
        case .education: return "Educación"
        case .shopping: return "Compras"
        case .travel: return "Viajes"
        case .gifts: return "Regalos"
        case .savings: return "Ahorro"
        case .debt: return "Deudas"
        case .investments: return "Inversiones"
        case .salary: return "Salario"
        case .freelance: return "Freelance"
        case .other: return "Otro"
        }
    }

    var iconName: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .housing: return "house.fill"
        case .utilities: return "bolt.fill"
        case .entertainment: return "gamecontroller.fill"
        case .health: return "heart.fill"
        case .education: return "book.fill"
        case .shopping: return "bag.fill"
        case .travel: return "airplane"
        case .gifts: return "gift.fill"
        case .savings: return "banknote.fill"
        case .debt: return "creditcard.fill"
        case .investments: return "chart.line.uptrend.xyaxis"
        case .salary: return "briefcase.fill"
        case .freelance: return "laptopcomputer"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var emoji: String {
        switch self {
        case .food: return "🍔"
        case .transport: return "🚗"
        case .housing: return "🏠"
        case .utilities: return "💡"
        case .entertainment: return "🎮"
        case .health: return "❤️"
        case .education: return "📚"
        case .shopping: return "🛍️"
        case .travel: return "✈️"
        case .gifts: return "🎁"
        case .savings: return "💰"
        case .debt: return "💳"
        case .investments: return "📈"
        case .salary: return "💼"
        case .freelance: return "💻"
        case .other: return "📌"
        }
    }

    var colorName: String {
        switch self {
        case .food: return "orange"
        case .transport: return "blue"
        case .housing: return "brown"
        case .utilities: return "yellow"
        case .entertainment: return "purple"
        case .health: return "red"
        case .education: return "indigo"
        case .shopping: return "pink"
        case .travel: return "cyan"
        case .gifts: return "mint"
        case .savings: return "green"
        case .debt: return "red"
        case .investments: return "teal"
        case .salary: return "gray"
        case .freelance: return "orange"
        case .other: return "secondary"
        }
    }
}

// MARK: - Recurring Frequency

enum RecurringFrequency: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case daily
    case weekly
    case biweekly
    case monthly
    case yearly

    var id: Self { self }

    var displayName: String {
        switch self {
        case .daily: return "Diario"
        case .weekly: return "Semanal"
        case .biweekly: return "Quincenal"
        case .monthly: return "Mensual"
        case .yearly: return "Anual"
        }
    }

    var iconName: String {
        switch self {
        case .daily: return "clock.fill"
        case .weekly: return "calendar.badge.clock"
        case .biweekly: return "calendar"
        case .monthly: return "calendar.circle.fill"
        case .yearly: return "calendar.badge.exclamationmark"
        }
    }
}

// MARK: - Split Type

enum SplitType: Codable, Hashable, Sendable {
    case equal                    // 50/50
    case proportional             // Based on income ratio
    case custom(Int)              // Custom percentage for user1 (e.g., 70 means 70/30)
    case onePays(UUID)            // One person pays all

    var displayName: String {
        switch self {
        case .equal: return "50/50"
        case .proportional: return "Proporcional"
        case .custom(let pct): return "\(pct)/\(100-pct)"
        case .onePays: return "Uno paga"
        }
    }

    var emoji: String {
        switch self {
        case .equal: return "⚖️"
        case .proportional: return "📊"
        case .custom: return "✂️"
        case .onePays: return "💳"
        }
    }
}

// MARK: - Transaction

struct Transaction: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let userId: UUID
    var coupleId: UUID?
    var type: TransactionType
    var category: TransactionCategory
    var amount: Decimal
    var description: String
    var notes: String?
    var date: Date
    var isRecurring: Bool
    var recurringFrequency: RecurringFrequency?
    var isShared: Bool
    var splitType: SplitType?
    var splitUser1Amount: Decimal?
    var splitUser2Amount: Decimal?
    /// C3: Emoji reactions from couple members. Key = userId string, value = emoji.
    var reactions: [String: String]?
    let createdAt: Date
    var updatedAt: Date

    /// Available reaction emojis (C3).
    static let reactionEmojis = ["👍", "❓", "😱", "💕", "🎉"]

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case coupleId = "couple_id"
        case type
        case category
        case amount
        case description
        case notes
        case date
        case isRecurring = "is_recurring"
        case recurringFrequency = "recurring_frequency"
        case isShared = "is_shared"
        case splitType = "split_type"
        case splitUser1Amount = "split_user1_amount"
        case splitUser2Amount = "split_user2_amount"
        case reactions
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(id: UUID, userId: UUID, coupleId: UUID?, type: TransactionType, category: TransactionCategory, amount: Decimal, description: String, notes: String?, date: Date, isRecurring: Bool, recurringFrequency: RecurringFrequency?, isShared: Bool = false, splitType: SplitType? = nil, splitUser1Amount: Decimal? = nil, splitUser2Amount: Decimal? = nil, reactions: [String: String]? = nil, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.userId = userId
        self.coupleId = coupleId
        self.type = type
        self.category = category
        self.amount = amount
        self.description = description
        self.notes = notes
        self.date = date
        self.isRecurring = isRecurring
        self.recurringFrequency = recurringFrequency
        self.isShared = isShared
        // Default to .equal when shared but no splitType specified
        self.splitType = isShared && splitType == nil ? .equal : splitType
        self.splitUser1Amount = splitUser1Amount
        self.splitUser2Amount = splitUser2Amount
        self.reactions = reactions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
