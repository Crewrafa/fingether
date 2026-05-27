import Foundation

// MARK: - Trip Expense

struct TripExpense: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var tripId: UUID
    var userId: UUID
    var amount: Decimal
    var currency: String
    var categoryId: UUID
    var merchant: String
    var notes: String?
    var date: Date
    var splitType: SplitType?
    var splitUser1Amount: Decimal?
    var splitUser2Amount: Decimal?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, amount, currency, merchant, notes, date
        case tripId = "trip_id"
        case userId = "user_id"
        case categoryId = "category_id"
        case splitType = "split_type"
        case splitUser1Amount = "split_user1_amount"
        case splitUser2Amount = "split_user2_amount"
        case createdAt = "created_at"
    }
}
