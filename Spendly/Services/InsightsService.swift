import Foundation
import Supabase

// MARK: - Insights Service

enum InsightsService {

    private static var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    // MARK: - Generate Insight

    /// Genera un insight de IA invocando la Edge Function.
    /// `mode` es opcional: "couple" o "solo". Cuando se omite, el Edge Function infiere por contexto.
    /// `userQuestion` se forwardea al prompt cuando el tipo es "custom" o "voice_query"
    /// (Bug fix #2: antes generateFromVoice ignoraba el transcript del usuario).
    static func generateInsight(
        coupleId: UUID,
        type: String,
        mode: String? = nil,
        userQuestion: String? = nil
    ) async throws -> String {
        if MockDataService.shared.isEnabled {
            return MockDataService.shared.generateMockInsight(type: type, mode: mode)
        }
        struct InsightRequest: Encodable {
            let coupleId: String
            let insightType: String
            let mode: String?
            let userQuestion: String?

            enum CodingKeys: String, CodingKey {
                case coupleId = "couple_id"
                case insightType = "insight_type"
                case mode
                case userQuestion = "user_question"
            }
        }

        struct InsightResponse: Decodable {
            let insight: String
        }

        let request = InsightRequest(
            coupleId: coupleId.uuidString,
            insightType: type,
            mode: mode,
            userQuestion: userQuestion
        )

        let response: InsightResponse = try await client.functions
            .invoke(
                Constants.EdgeFunction.generateInsights,
                options: .init(body: request)
            )

        return response.insight
    }

    // MARK: - Get Cached Insights

    /// Obtiene insights guardados en caché que no han expirado
    static func getCachedInsights(coupleId: UUID) async throws -> [InsightCache] {
        if MockDataService.shared.isEnabled {
            return MockDataService.shared.getMockCachedInsights(coupleId: coupleId)
        }

        let now = Date().apiFormatted

        let insights: [InsightCache] = try await client
            .from("insights_cache")
            .select()
            .eq("couple_id", value: coupleId.uuidString)
            .gte("expires_at", value: now)
            .order("generated_at", ascending: false)
            .execute()
            .value

        return insights
    }
}
