import Foundation

// MARK: - Pet Mood

enum PetMood: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case ecstatic
    case happy
    case neutral
    case sad
    case critical

    var id: Self { self }

    var displayName: String {
        switch self {
        case .ecstatic: return "Eufórico"
        case .happy: return "Feliz"
        case .neutral: return "Neutral"
        case .sad: return "Triste"
        case .critical: return "Crítico"
        }
    }

    var iconName: String {
        switch self {
        case .ecstatic: return "face.smiling.inverse"
        case .happy: return "face.smiling"
        case .neutral: return "face.dashed"
        case .sad: return "cloud.rain.fill"
        case .critical: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Pet Evolution

enum PetEvolution: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case egg
    case baby
    case teen
    case adult
    case legendary

    var id: Self { self }

    var displayName: String {
        switch self {
        case .egg: return "Huevo"
        case .baby: return "Bebé"
        case .teen: return "Joven"
        case .adult: return "Adulto"
        case .legendary: return "Legendario"
        }
    }

    var iconName: String {
        switch self {
        case .egg: return "oval.fill"
        case .baby: return "hare.fill"
        case .teen: return "pawprint.fill"
        case .adult: return "tortoise.fill"
        case .legendary: return "crown.fill"
        }
    }
}

// MARK: - Pet State

struct PetState: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let coupleId: UUID
    var name: String
    var health: Int
    var mood: PetMood
    var evolution: PetEvolution
    var experiencePoints: Int
    var daysAlive: Int
    var accessories: [String]
    var equippedAccessory: String?
    var lastFed: Date
    var lastHealthUpdate: Date
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case coupleId = "couple_id"
        case name
        case health
        case mood
        case evolution
        case experiencePoints = "experience_points"
        case daysAlive = "days_alive"
        case accessories
        case equippedAccessory = "equipped_accessory"
        case lastFed = "last_fed"
        case lastHealthUpdate = "last_health_update"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Si la salud de la mascota está en zona de peligro (0-25)
    var isHealthCritical: Bool {
        health <= 25
    }

    /// Si la salud de la mascota está en zona de advertencia (26-50)
    var isHealthWarning: Bool {
        health > 25 && health <= 50
    }

    /// Si la salud de la mascota está bien (51-100)
    var isHealthGood: Bool {
        health > 50
    }
}
