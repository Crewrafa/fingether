import Foundation

// MARK: - Notification Type

enum NotificationType: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case budgetAlert = "budget_alert"
    case achievement
    case partnerActivity = "partner_activity"
    case petStatus = "pet_status"
    case insight
    case savingsMilestone = "savings_milestone"

    var id: Self { self }

    var displayName: String {
        switch self {
        case .budgetAlert: return "Alerta de presupuesto"
        case .achievement: return "Logro"
        case .partnerActivity: return "Actividad de pareja"
        case .petStatus: return "Estado de mascota"
        case .insight: return "Consejo"
        case .savingsMilestone: return "Meta de ahorro"
        }
    }

    var iconName: String {
        switch self {
        case .budgetAlert: return "exclamationmark.triangle.fill"
        case .achievement: return "trophy.fill"
        case .partnerActivity: return "person.2.fill"
        case .petStatus: return "pawprint.fill"
        case .insight: return "lightbulb.fill"
        case .savingsMilestone: return "star.fill"
        }
    }
}

// MARK: - App Notification

struct AppNotification: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let userId: UUID
    var coupleId: UUID?
    let type: NotificationType
    let title: String
    let body: String
    let data: JSONValue?
    var isRead: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case coupleId = "couple_id"
        case type
        case title
        case body
        case data
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

// MARK: - JSONValue (for arbitrary JSON data)

enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }
        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
            return
        }
        if let numberValue = try? container.decode(Double.self) {
            self = .number(numberValue)
            return
        }
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }
        if let arrayValue = try? container.decode([JSONValue].self) {
            self = .array(arrayValue)
            return
        }
        if let objectValue = try? container.decode([String: JSONValue].self) {
            self = .object(objectValue)
            return
        }

        throw DecodingError.typeMismatch(
            JSONValue.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unable to decode JSONValue"
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}
