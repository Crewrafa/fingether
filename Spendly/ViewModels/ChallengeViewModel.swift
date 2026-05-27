import Foundation

@MainActor
@Observable
final class ChallengeViewModel {

    // MARK: - State

    var challenges: [FinancialChallenge] = []
    var suggestedChallenges: [FinancialChallenge] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Computed

    var activeChallenge: FinancialChallenge? {
        challenges.first(where: { $0.status == .active })
    }

    var completedChallenges: [FinancialChallenge] {
        challenges.filter { $0.status == .completed }
            .sorted { $0.endDate > $1.endDate }
    }

    var failedChallenges: [FinancialChallenge] {
        challenges.filter { $0.status == .failed }
            .sorted { $0.endDate > $1.endDate }
    }

    var historyChallenges: [FinancialChallenge] {
        challenges.filter { $0.status == .completed || $0.status == .failed || $0.status == .cancelled }
            .sorted { $0.endDate > $1.endDate }
    }

    // MARK: - Actions

    func loadChallenges(coupleId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let mock = MockDataService.shared
        guard mock.isEnabled else { return }

        challenges = mock.mockChallenges
        suggestedChallenges = generateSuggestions(coupleId: coupleId)
    }

    func acceptChallenge(_ challenge: FinancialChallenge, coupleId: UUID) async {
        var accepted = challenge
        accepted.status = .active
        accepted.startDate = Date()
        accepted.endDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()

        // Remove from suggestions
        suggestedChallenges.removeAll { $0.id == challenge.id }

        // Add to active
        challenges.append(accepted)
        MockDataService.shared.mockChallenges = challenges
    }

    func abandonChallenge(_ challengeId: UUID) async {
        if let idx = challenges.firstIndex(where: { $0.id == challengeId }) {
            challenges[idx].status = .cancelled
            MockDataService.shared.mockChallenges = challenges
        }
    }

    // MARK: - Private

    private func generateSuggestions(coupleId: UUID) -> [FinancialChallenge] {
        let now = Date()
        let cal = Calendar.current
        let weekLater = cal.date(byAdding: .day, value: 7, to: now) ?? now
        let twoWeeksLater = cal.date(byAdding: .day, value: 14, to: now) ?? now
        let fourWeeksLater = cal.date(byAdding: .day, value: 28, to: now) ?? now
        let monthLater = cal.date(byAdding: .day, value: 30, to: now) ?? now

        // MARK: Easy challenges (7 days, 50 XP)
        let easyChallenges: [FinancialChallenge] = [
            FinancialChallenge(
                id: UUID(), coupleId: coupleId,
                name: "🚫🛵 Semana sin delivery",
                description: "No pidan comida a domicilio durante 7 días. Cocinen juntos y ahorren.",
                type: .noSpend, metric: .days, targetValue: 7, currentValue: 0,
                difficulty: .easy, status: .active,
                startDate: now, endDate: weekLater,
                category: .food, xpReward: 50,
                createdAt: now
            ),
            FinancialChallenge(
                id: UUID(), coupleId: coupleId,
                name: "📝 Registro perfecto",
                description: "Registren al menos 1 gasto cada día por 7 días. ¡Sin excusas!",
                type: .budgetStreak, metric: .days, targetValue: 7, currentValue: 0,
                difficulty: .easy, status: .active,
                startDate: now, endDate: weekLater,
                category: nil, xpReward: 50,
                createdAt: now
            ),
            FinancialChallenge(
                id: UUID(), coupleId: coupleId,
                name: "💰 Micro ahorro",
                description: "Ahorren al menos $50.000 esta semana entre los dos.",
                type: .savingsSprint, metric: .amount, targetValue: 50000, currentValue: 0,
                difficulty: .easy, status: .active,
                startDate: now, endDate: weekLater,
                category: .savings, xpReward: 50,
                createdAt: now
            ),
            FinancialChallenge(
                id: UUID(), coupleId: coupleId,
                name: "☕ Sin café comprado",
                description: "No compren café afuera por 7 días. Prepárenlo en casa y disfruten juntos.",
                type: .noSpend, metric: .days, targetValue: 7, currentValue: 0,
                difficulty: .easy, status: .active,
                startDate: now, endDate: weekLater,
                category: .food, xpReward: 50,
                createdAt: now
            ),
            FinancialChallenge(
                id: UUID(), coupleId: coupleId,
                name: "🏠 Cocineros en casa",
                description: "Gasten $0 en restaurantes por 7 días. ¡A cocinar en pareja!",
                type: .noSpend, metric: .days, targetValue: 7, currentValue: 0,
                difficulty: .easy, status: .active,
                startDate: now, endDate: weekLater,
                category: .food, xpReward: 50,
                createdAt: now
            ),
        ]

        // MARK: Medium challenges (14-30 days, 150 XP)
        let mediumChallenges: [FinancialChallenge] = [
            FinancialChallenge(
                id: UUID(), coupleId: coupleId,
                name: "📉 Mes austero",
                description: "Gasten 20% menos que el mes pasado. Revisen juntos cada gasto.",
                type: .categoryLimit, metric: .percentage, targetValue: 80, currentValue: 0,
                difficulty: .medium, status: .active,
                startDate: now, endDate: monthLater,
                category: nil, xpReward: 150,
                createdAt: now
            ),
            FinancialChallenge(
                id: UUID(), coupleId: coupleId,
                name: "🏠 Presupuesto ninja",
                description: "No se pasen del presupuesto diario por 30 días. Disciplina total.",
                type: .budgetStreak, metric: .days, targetValue: 30, currentValue: 0,
                difficulty: .medium, status: .active,
                startDate: now, endDate: monthLater,
                category: nil, xpReward: 150,
                createdAt: now
            ),
            FinancialChallenge(
                id: UUID(), coupleId: coupleId,
                name: "🎯 Detox de antojos",
                description: "$0 en entretenimiento y compras innecesarias por 2 semanas.",
                type: .noSpend, metric: .days, targetValue: 14, currentValue: 0,
                difficulty: .medium, status: .active,
                startDate: now, endDate: twoWeeksLater,
                category: .entertainment, xpReward: 150,
                createdAt: now
            ),
            FinancialChallenge(
                id: UUID(), coupleId: coupleId,
                name: "🍳 Chef en casa",
                description: "Gasten menos del 50% de lo normal en restaurantes este mes.",
                type: .categoryLimit, metric: .percentage, targetValue: 50, currentValue: 0,
                difficulty: .medium, status: .active,
                startDate: now, endDate: monthLater,
                category: .food, xpReward: 150,
                createdAt: now
            ),
            FinancialChallenge(
                id: UUID(), coupleId: coupleId,
                name: "💪 Ahorro constante",
                description: "Ahorren al menos $200.000 cada semana por 4 semanas. ¡$800.000 en total!",
                type: .savingsSprint, metric: .amount, targetValue: 800000, currentValue: 0,
                difficulty: .medium, status: .active,
                startDate: now, endDate: fourWeeksLater,
                category: .savings, xpReward: 150,
                createdAt: now
            ),
        ]

        // MARK: Hard challenges (30 days, 300 XP)
        let hardChallenges: [FinancialChallenge] = [
            FinancialChallenge(
                id: UUID(), coupleId: coupleId,
                name: "🔥 Modo supervivencia",
                description: "Solo gasten en necesidades básicas por 30 días. Cero lujos.",
                type: .budgetStreak, metric: .days, targetValue: 30, currentValue: 0,
                difficulty: .hard, status: .active,
                startDate: now, endDate: monthLater,
                category: nil, xpReward: 300,
                createdAt: now
            ),
            FinancialChallenge(
                id: UUID(), coupleId: coupleId,
                name: "💪 Ahorro extremo",
                description: "Ahorren el 30% del ingreso combinado este mes. ¡Reto de titanes!",
                type: .savingsSprint, metric: .percentage, targetValue: 30, currentValue: 0,
                difficulty: .hard, status: .active,
                startDate: now, endDate: monthLater,
                category: .savings, xpReward: 300,
                createdAt: now
            ),
            FinancialChallenge(
                id: UUID(), coupleId: coupleId,
                name: "🏆 Triple corona",
                description: "Completen 3 retos medios en el mismo mes. ¡Demuestren de qué están hechos!",
                type: .incomeBoost, metric: .count, targetValue: 3, currentValue: 0,
                difficulty: .hard, status: .active,
                startDate: now, endDate: monthLater,
                category: nil, xpReward: 300,
                createdAt: now
            ),
            FinancialChallenge(
                id: UUID(), coupleId: coupleId,
                name: "📊 Financieros disciplinados",
                description: "Registren gastos + bajo presupuesto + avancen su meta por 30 días.",
                type: .budgetStreak, metric: .days, targetValue: 30, currentValue: 0,
                difficulty: .hard, status: .active,
                startDate: now, endDate: monthLater,
                category: nil, xpReward: 300,
                createdAt: now
            ),
            FinancialChallenge(
                id: UUID(), coupleId: coupleId,
                name: "🎯 Cero deudas",
                description: "Liquiden todos los préstamos pendientes en 30 días. ¡Libertad financiera!",
                type: .budgetStreak, metric: .days, targetValue: 30, currentValue: 0,
                difficulty: .hard, status: .active,
                startDate: now, endDate: monthLater,
                category: .debt, xpReward: 300,
                createdAt: now
            ),
        ]

        // Pick 3 random from each difficulty to avoid overwhelming the user
        let pickedEasy = Array(easyChallenges.shuffled().prefix(3))
        let pickedMedium = Array(mediumChallenges.shuffled().prefix(3))
        let pickedHard = Array(hardChallenges.shuffled().prefix(3))

        return pickedEasy + pickedMedium + pickedHard
    }
}
