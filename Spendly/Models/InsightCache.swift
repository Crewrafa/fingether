import Foundation

// MARK: - Insight Cache

struct InsightCache: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let coupleId: UUID
    let insightType: String
    let content: String
    let metadata: [String: String]?
    let generatedAt: Date
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case coupleId = "couple_id"
        case insightType = "insight_type"
        case content
        case metadata
        case generatedAt = "generated_at"
        case expiresAt = "expires_at"
    }

    /// Si el insight ha expirado
    var isExpired: Bool {
        expiresAt < Date()
    }
}
