import Foundation

// MARK: - Couple

struct Couple: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var inviteCode: String
    var inviteExpiration: Date?
    let partner1Id: UUID
    var partner2Id: UUID?
    var user1Name: String
    var user2Name: String?
    var user1Income: Decimal
    var user2Income: Decimal?
    var combinedMonthlyIncome: Decimal
    var coupleMonthlyBudget: Decimal?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case inviteCode = "invite_code"
        case inviteExpiration = "invite_expiration"
        case partner1Id = "partner_1_id"
        case partner2Id = "partner_2_id"
        case user1Name = "user_1_name"
        case user2Name = "user_2_name"
        case user1Income = "user_1_income"
        case user2Income = "user_2_income"
        case combinedMonthlyIncome = "combined_monthly_income"
        case coupleMonthlyBudget = "couple_monthly_budget"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Whether the couple has both partners linked
    var isLinked: Bool {
        partner2Id != nil
    }

    /// Whether the invite code is still valid
    var isInviteValid: Bool {
        guard let exp = inviteExpiration else { return false }
        return exp > Date()
    }
}
