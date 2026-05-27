import Foundation
import Supabase

// MARK: - Couple Service

enum CoupleService {

    private static var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    // MARK: - Create Couple

    /// Crea una nueva pareja y retorna el couple_id y código de invitación
    static func createCouple() async throws -> (coupleId: UUID, inviteCode: String) {
        if MockDataService.shared.isEnabled {
            return MockDataService.shared.mockCreateCouple()
        }
        struct CreateCoupleResponse: Decodable {
            let coupleId: UUID
            let inviteCode: String

            enum CodingKeys: String, CodingKey {
                case coupleId = "couple_id"
                case inviteCode = "invite_code"
            }
        }

        let response: [CreateCoupleResponse] = try await client
            .rpc("create_couple")
            .execute()
            .value

        guard let result = response.first else {
            throw CoupleError.creationFailed
        }

        return (coupleId: result.coupleId, inviteCode: result.inviteCode)
    }

    // MARK: - Join Couple

    /// Se une a una pareja existente usando un código de invitación
    static func joinCouple(inviteCode: String) async throws -> UUID {
        if MockDataService.shared.isEnabled {
            if let coupleId = MockDataService.shared.mockJoinCouple(inviteCode: inviteCode) {
                return coupleId
            }
            throw CoupleError.invalidInviteCode
        }

        let params: [String: AnyJSON] = [
            "p_invite_code": .string(inviteCode.uppercased())
        ]

        let response: UUID = try await client
            .rpc("join_couple", params: params)
            .execute()
            .value

        return response
    }

    // MARK: - Get Couple

    /// Obtiene la pareja del usuario actual
    static func getCouple() async throws -> Couple? {
        if MockDataService.shared.isEnabled {
            return MockDataService.shared.getMockCouple()
        }

        guard let profile = try? await AuthService.getCurrentProfile(),
              let coupleId = profile.coupleId else {
            return nil
        }

        let couple: Couple = try await client
            .from("couples")
            .select()
            .eq("id", value: coupleId.uuidString)
            .single()
            .execute()
            .value

        return couple
    }

    // MARK: - Get Partner Profile

    /// Obtiene el perfil de la pareja del usuario actual
    static func getPartnerProfile() async throws -> Profile? {
        if MockDataService.shared.isEnabled {
            return MockDataService.shared.getMockPartnerProfile()
        }

        guard let currentUser = AuthService.getCurrentUser(),
              let couple = try await getCouple() else {
            return nil
        }

        let partnerId: UUID
        if couple.partner1Id == currentUser.id {
            guard let p2 = couple.partner2Id else { return nil }
            partnerId = p2
        } else {
            partnerId = couple.partner1Id
        }

        let partner: Profile = try await client
            .from("profiles")
            .select()
            .eq("id", value: partnerId.uuidString)
            .single()
            .execute()
            .value

        return partner
    }

    // MARK: - Errors

    enum CoupleError: LocalizedError {
        case creationFailed
        case invalidInviteCode
        case alreadyInCouple

        var errorDescription: String? {
            switch self {
            case .creationFailed:
                return "No se pudo crear la pareja. Intenta de nuevo."
            case .invalidInviteCode:
                return "Código de invitación inválido o expirado."
            case .alreadyInCouple:
                return "Ya perteneces a una pareja."
            }
        }
    }
}
