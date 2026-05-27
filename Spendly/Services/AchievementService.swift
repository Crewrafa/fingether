import Foundation
import Supabase

// MARK: - Achievement Service

enum AchievementService {

    private static var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    // MARK: - Get Achievements

    /// Obtiene todos los logros de la pareja
    static func getAchievements(coupleId: UUID) async throws -> [Achievement] {
        if MockDataService.shared.isEnabled {
            return MockDataService.shared.getMockAchievements(coupleId: coupleId)
        }

        let achievements: [Achievement] = try await client
            .from("achievements")
            .select()
            .eq("couple_id", value: coupleId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value

        return achievements
    }

    // MARK: - Check Achievements

    /// Verifica y desbloquea logros pendientes. Retorna las keys de los logros recién desbloqueados.
    static func checkAchievements(coupleId: UUID) async throws -> [String] {
        if MockDataService.shared.isEnabled {
            return MockDataService.shared.checkMockAchievements(coupleId: coupleId)
        }
        struct AchievementCheckResponse: Decodable {
            let newlyUnlocked: [String]

            enum CodingKeys: String, CodingKey {
                case newlyUnlocked = "newly_unlocked"
            }
        }

        let params: [String: AnyJSON] = [
            "p_couple_id": .string(coupleId.uuidString)
        ]

        let response: [AchievementCheckResponse] = try await client
            .rpc("check_achievements", params: params)
            .execute()
            .value

        return response.first?.newlyUnlocked ?? []
    }
}
