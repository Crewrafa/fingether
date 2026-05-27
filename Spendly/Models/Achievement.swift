import Foundation

// MARK: - Achievement Category

enum AchievementCategory: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case savings
    case budget
    case streak
    case social
    case pet
    case milestone

    var id: Self { self }

    var displayName: String {
        switch self {
        case .savings: return "Ahorro"
        case .budget: return "Presupuesto"
        case .streak: return "Racha"
        case .social: return "Social"
        case .pet: return "Mascota"
        case .milestone: return "Hito"
        }
    }

    var iconName: String {
        switch self {
        case .savings: return "banknote.fill"
        case .budget: return "chart.pie.fill"
        case .streak: return "flame.fill"
        case .social: return "person.2.fill"
        case .pet: return "pawprint.fill"
        case .milestone: return "flag.fill"
        }
    }
}

// MARK: - Achievement

struct Achievement: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let coupleId: UUID
    let key: String
    let title: String
    let description: String
    let category: AchievementCategory
    let icon: String
    var unlockedAt: Date?
    var rewardAccessory: String?
    var progress: Int
    let target: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case coupleId = "couple_id"
        case key
        case title
        case description
        case category
        case icon
        case unlockedAt = "unlocked_at"
        case rewardAccessory = "reward_accessory"
        case progress
        case target
        case createdAt = "created_at"
    }

    /// Si el logro fue desbloqueado
    var isUnlocked: Bool {
        unlockedAt != nil
    }

    /// Porcentaje de progreso (0.0 a 1.0)
    var progressPercentage: Double {
        guard target > 0 else { return 0 }
        return min(Double(progress) / Double(target), 1.0)
    }
}
