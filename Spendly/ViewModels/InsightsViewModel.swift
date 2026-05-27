import Foundation

@MainActor
@Observable
final class InsightsViewModel {

    // MARK: - State

    var currentInsight: String?
    var cachedInsights: [InsightCache] = []
    var isGenerating = false
    var isLoading = false
    var errorMessage: String?
    var voiceInput = ""

    // MARK: - Actions

    func generateInsight(coupleId: UUID, type: String) async {
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        do {
            let mode: String = AppPreferences.shared.isCoupleMode ? "couple" : "solo"
            let insight = try await InsightsService.generateInsight(
                coupleId: coupleId,
                type: type,
                mode: mode
            )
            currentInsight = insight
            AnalyticsService.track(.insightGenerated, properties: ["type": type])
            await loadCachedInsights(coupleId: coupleId)
        } catch {
            errorMessage = mapInsightError(error)
        }
    }

    func loadCachedInsights(coupleId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            cachedInsights = try await InsightsService.getCachedInsights(coupleId: coupleId)

            if currentInsight == nil, let latest = cachedInsights.first {
                currentInsight = latest.content
            }
        } catch {
            errorMessage = "No se pudieron cargar los consejos guardados."
        }
    }

    func generateFromVoice(coupleId: UUID) async {
        let trimmedInput = voiceInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            errorMessage = "No se detecto ninguna pregunta. Intenta de nuevo."
            return
        }

        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        do {
            // Bug fix #2: forward the actual transcript as user_question so Claude can answer it.
            // Send as a "custom" insight (the Edge Function path that respects user_question)
            // tagged with mode for couple/solo context.
            let mode: String = AppPreferences.shared.isCoupleMode ? "couple" : "solo"
            let insight = try await InsightsService.generateInsight(
                coupleId: coupleId,
                type: "custom",
                mode: mode,
                userQuestion: trimmedInput
            )
            currentInsight = insight
            voiceInput = ""
            await loadCachedInsights(coupleId: coupleId)
        } catch {
            errorMessage = mapInsightError(error)
        }
    }

    func clearCurrentInsight() {
        currentInsight = nil
    }

    // MARK: - Private Helpers

    private func mapInsightError(_ error: Error) -> String {
        let description = error.localizedDescription.lowercased()

        if description.contains("premium") || description.contains("subscription") {
            return "Esta funcion requiere suscripcion Premium."
        }
        if description.contains("limit") || description.contains("rate") {
            return "Alcanzaste el limite de consultas. Intenta mas tarde."
        }
        if description.contains("network") || description.contains("connection") {
            return "Sin conexion a internet. Verifica tu red e intenta de nuevo."
        }
        return "No se pudo generar el consejo. Intenta de nuevo."
    }
}
