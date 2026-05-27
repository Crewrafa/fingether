import Foundation

struct Debt: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let coupleId: UUID
    let fromUserId: UUID    // who owes
    let toUserId: UUID      // who is owed
    var concept: String
    var amount: Decimal
    var isPaid: Bool
    var paidAt: Date?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, concept, amount
        case coupleId = "couple_id"
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case isPaid = "is_paid"
        case paidAt = "paid_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
