import Foundation

// MARK: - Subscription

struct Subscription: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let userId: UUID
    let productId: String
    var tier: SubscriptionTier
    var isActive: Bool
    let originalTransactionId: String?
    let purchaseDate: Date
    var expirationDate: Date?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case productId = "product_id"
        case tier
        case isActive = "is_active"
        case originalTransactionId = "original_transaction_id"
        case purchaseDate = "purchase_date"
        case expirationDate = "expiration_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Si la suscripción ha expirado
    var isExpired: Bool {
        guard let expirationDate else { return false }
        return expirationDate < Date()
    }

    /// Si la suscripción es premium y está activa
    var isPremiumActive: Bool {
        tier == .premium && isActive && !isExpired
    }
}
