import Foundation
import Supabase

// MARK: - Pet Service

enum PetService {

    private static var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    // MARK: - Get Pet State

    /// Obtiene el estado actual de la mascota de la pareja
    static func getPetState(coupleId: UUID) async throws -> PetState? {
        if MockDataService.shared.isEnabled {
            return MockDataService.shared.getMockPetState(coupleId: coupleId)
        }

        let results: [PetState] = try await client
            .from("pet_state")
            .select()
            .eq("couple_id", value: coupleId.uuidString)
            .limit(1)
            .execute()
            .value

        return results.first
    }

    // MARK: - Refresh Pet Health

    /// Recalcula la salud, humor y evolución de la mascota basado en datos financieros
    static func refreshPetHealth(coupleId: UUID) async throws {
        if MockDataService.shared.isEnabled {
            MockDataService.shared.refreshMockPetHealth()
            return
        }

        let params: [String: AnyJSON] = [
            "p_couple_id": .string(coupleId.uuidString)
        ]

        try await client
            .rpc("refresh_pet_state", params: params)
            .execute()
    }

    // MARK: - Update Pet Name

    /// Cambia el nombre de la mascota
    static func updatePetName(coupleId: UUID, name: String) async throws {
        if MockDataService.shared.isEnabled {
            MockDataService.shared.updateMockPetName(name: name)
            return
        }

        try await client
            .from("pet_state")
            .update(["name": name])
            .eq("couple_id", value: coupleId.uuidString)
            .execute()
    }

    // MARK: - Equip Accessory

    /// Equipa o desequipa un accesorio en la mascota
    static func equipAccessory(coupleId: UUID, accessory: String?) async throws {
        if MockDataService.shared.isEnabled {
            MockDataService.shared.equipMockAccessory(accessory: accessory)
            return
        }

        let value: AnyJSON = accessory.map { .string($0) } ?? .null

        try await client
            .from("pet_state")
            .update(["equipped_accessory": value])
            .eq("couple_id", value: coupleId.uuidString)
            .execute()
    }

    // MARK: - Award XP

    /// Otorga puntos de experiencia a la mascota
    static func awardXP(coupleId: UUID, xp: Int) async throws {
        if MockDataService.shared.isEnabled {
            MockDataService.shared.awardMockXP(xp: xp)
            return
        }

        let params: [String: AnyJSON] = [
            "p_couple_id": .string(coupleId.uuidString),
            "p_xp": .integer(xp)
        ]

        try await client
            .rpc("award_pet_xp", params: params)
            .execute()
    }
}
