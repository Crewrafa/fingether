import Foundation

// MARK: - Subscription Tier

enum SubscriptionTier: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case free
    case premium

    var id: Self { self }

    var displayName: String {
        switch self {
        case .free: return "Gratis"
        case .premium: return "Premium"
        }
    }

    var iconName: String {
        switch self {
        case .free: return "star"
        case .premium: return "star.fill"
        }
    }
}

// MARK: - Profile

struct Profile: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let email: String
    var displayName: String
    var avatarUrl: String?
    var coupleId: UUID?
    var subscriptionTier: SubscriptionTier
    var monthlyIncome: Decimal
    var currency: String
    var streakDays: Int
    var lastTransactionDate: Date?
    var onboardingCompleted: Bool
    var notificationToken: String?
    var dateOfBirth: Date?
    var gender: String?
    var city: String?
    var country: String?
    var relationshipStatus: String?  // "soltero", "en_relacion", "casado", "otro"
    var relationshipStartDate: Date?
    var occupation: String?
    var employmentType: String?
    var industry: String?
    var housingType: String?
    var hasChildren: Int?
    var hasCreditCards: Bool?
    var creditCardCount: Int?
    var hasSavings: Bool?
    var financialGoal: String?
    var liveTogether: Bool?
    var relationshipLength: String?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case coupleId = "couple_id"
        case subscriptionTier = "subscription_tier"
        case monthlyIncome = "monthly_income"
        case currency
        case streakDays = "streak_days"
        case lastTransactionDate = "last_transaction_date"
        case onboardingCompleted = "onboarding_completed"
        case notificationToken = "notification_token"
        case dateOfBirth = "date_of_birth"
        case gender
        case city
        case country
        case relationshipStatus = "relationship_status"
        case relationshipStartDate = "relationship_start_date"
        case occupation
        case employmentType = "employment_type"
        case industry
        case housingType = "housing_type"
        case hasChildren = "has_children"
        case hasCreditCards = "has_credit_cards"
        case creditCardCount = "credit_card_count"
        case hasSavings = "has_savings"
        case financialGoal = "financial_goal"
        case liveTogether = "live_together"
        case relationshipLength = "relationship_length"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
