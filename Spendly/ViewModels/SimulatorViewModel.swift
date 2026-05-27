import Foundation

@MainActor
@Observable
final class SimulatorViewModel {

    // MARK: - State

    var selectedType: SimulationType?
    var currentSimulation: Simulation?
    var isLoading = false
    var errorMessage: String?
    var showResult = false

    // MARK: - Form State

    var formMonthlyAmount = ""
    var formTargetAmount = ""
    var formInterestRate = ""
    var formMonths = 12

    // MARK: - Couple-Mode Form State

    /// Quien recibe el cambio (raise/perdida de empleo/etc) en escenarios de pareja.
    enum AffectedPartner: String, CaseIterable, Identifiable {
        case both
        case user1
        case user2
        var id: String { rawValue }
    }

    /// Solo se usa cuando isCoupleMode == true. Default .both para no cambiar comportamiento previo.
    var formAffectedPartner: AffectedPartner = .both

    // MARK: - Scenario Cards

    struct ScenarioCard: Identifiable {
        let id = UUID()
        let type: SimulationType
        let title: String
        let subtitle: String
        let icon: String
        let gradientColors: [String]
    }

    var scenarioCards: [ScenarioCard] {
        [
            ScenarioCard(
                type: .incomeIncrease,
                title: "Aumentar ingresos",
                subtitle: "Que pasa si ganas mas cada mes",
                icon: "arrow.up.circle.fill",
                gradientColors: ["4F46E5", "4338CA"]
            ),
            ScenarioCard(
                type: .expenseReduction,
                title: "Reducir un gasto",
                subtitle: "Elimina o reduce un gasto fijo",
                icon: "scissors",
                gradientColors: ["64748B", "DB2777"]
            ),
            ScenarioCard(
                type: .savingsProjection,
                title: "Proyeccion de ahorro",
                subtitle: "Cuanto tendras en X meses",
                icon: "chart.line.uptrend.xyaxis",
                gradientColors: ["FDCB6E", "64748B"]
            ),
            ScenarioCard(
                type: .emergencyFund,
                title: "Fondo de emergencia",
                subtitle: "Cuanto necesitas y en cuanto tiempo",
                icon: "shield.checkered",
                gradientColors: ["0EA5E9", "A29BFE"]
            ),
        ]
    }

    // MARK: - Actions

    func selectScenario(_ type: SimulationType) {
        selectedType = type
        resetForm()
    }

    func runSimulation(coupleId: UUID) {
        guard let type = selectedType else { return }
        guard validateForm() else { return }

        isLoading = true
        errorMessage = nil

        let monthly = parseDecimal(formMonthlyAmount)
        let target = parseDecimal(formTargetAmount)
        let rate = parseDecimal(formInterestRate)

        let params = SimulationParams(
            monthlyAmount: monthly,
            targetAmount: target > 0 ? target : nil,
            interestRate: rate > 0 ? rate : nil,
            months: formMonths,
            category: nil
        )

        let result = calculateResult(type: type, params: params)
        let riskLevel = assessRisk(type: type, params: params, result: result)

        currentSimulation = Simulation(
            id: UUID(),
            coupleId: coupleId,
            name: scenarioCards.first(where: { $0.type == type })?.title ?? type.displayName,
            type: type,
            params: params,
            result: result,
            riskLevel: riskLevel,
            createdAt: Date()
        )

        isLoading = false
        showResult = true
    }

    // MARK: - Local Calculation

    private func calculateResult(type: SimulationType, params: SimulationParams) -> SimulationResult {
        let monthly = params.monthlyAmount
        let months = params.months
        let rate = params.interestRate ?? Decimal.zero

        var breakdown: [Decimal] = []
        var accumulated = Decimal.zero

        for _ in 1...months {
            let monthlyRate = rate / 12 / 100
            accumulated = (accumulated + monthly) * (1 + monthlyRate)
            breakdown.append(accumulated)
        }

        let projectedTotal = accumulated
        let totalContributed = monthly * Decimal(months)
        let savingsGain = projectedTotal - totalContributed

        var timeToGoal: Int? = nil
        if let target = params.targetAmount, target > 0 {
            for (i, val) in breakdown.enumerated() {
                if val >= target {
                    timeToGoal = i + 1
                    break
                }
            }
        }

        let summary: String
        switch type {
        case .incomeIncrease:
            summary = "Si aumentas tus ingresos \(monthly.currencyFormatted) al mes, en \(months) meses tendras \(projectedTotal.currencyFormatted) adicionales."
        case .expenseReduction:
            summary = "Al reducir \(monthly.currencyFormatted) mensuales, acumularas \(projectedTotal.currencyFormatted) en \(months) meses."
        case .savingsProjection:
            summary = "Ahorrando \(monthly.currencyFormatted) al mes, en \(months) meses tendras \(projectedTotal.currencyFormatted)."
        case .emergencyFund:
            if let goal = timeToGoal {
                summary = "Necesitas \(goal) meses para alcanzar tu fondo de emergencia de \(params.targetAmount?.currencyFormatted ?? "")."
            } else {
                summary = "Con \(monthly.currencyFormatted) al mes, en \(months) meses tendras \(projectedTotal.currencyFormatted) para emergencias."
            }
        case .debtPayoff:
            summary = "Pagando \(monthly.currencyFormatted) al mes, liquidaras tu deuda en aproximadamente \(timeToGoal ?? months) meses."
        }

        return SimulationResult(
            projectedTotal: projectedTotal,
            monthlyBreakdown: breakdown,
            savingsGain: savingsGain,
            timeToGoalMonths: timeToGoal,
            summary: summary
        )
    }

    private func assessRisk(type: SimulationType, params: SimulationParams, result: SimulationResult) -> RiskLevel {
        let mock = MockDataService.shared
        // En modo pareja usar ingreso combinado real; individual usa solo el ingreso del perfil.
        let referenceIncome: Decimal
        if AppPreferences.shared.isCoupleMode && mock.currentCombinedIncome > 0 {
            referenceIncome = mock.currentCombinedIncome
        } else {
            referenceIncome = mock.getMockProfile().monthlyIncome
        }
        guard referenceIncome > 0 else { return .low }

        let ratio = params.monthlyAmount.doubleValue / referenceIncome.doubleValue

        if ratio > 0.4 {
            return .high
        } else if ratio > 0.2 {
            return .medium
        } else {
            return .low
        }
    }

    // MARK: - Couple-Mode Computeds

    /// Ingreso de referencia para la simulacion segun el modo actual.
    var referenceIncome: Decimal {
        let mock = MockDataService.shared
        if AppPreferences.shared.isCoupleMode && mock.currentCombinedIncome > 0 {
            return mock.currentCombinedIncome
        }
        return mock.getMockProfile().monthlyIncome
    }

    /// Gastos mensuales totales del mes actual (combinados en pareja, individuales en solo).
    var referenceMonthlyExpenses: Decimal {
        let mock = MockDataService.shared
        let cal = Calendar.current
        let now = Date()
        let txs = mock.mockTransactions.filter {
            $0.type == .expense &&
            cal.isDate($0.date, equalTo: now, toGranularity: .month) &&
            (AppPreferences.shared.isCoupleMode || $0.userId == mock.currentUser1Id)
        }
        return txs.reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// Disponible mensual de cada miembro ANTES de aplicar la simulacion (solo couple mode).
    var coupleAvailableBefore: (user1: Decimal, user2: Decimal) {
        let mock = MockDataService.shared
        let cal = Calendar.current
        let now = Date()

        // Calcular gastos de cada usuario este mes (incluyendo su parte de los compartidos)
        let split = mock.coupleSettings.defaultSplitType
        var u1Expenses: Decimal = 0
        var u2Expenses: Decimal = 0

        for tx in mock.mockTransactions where tx.type == .expense
            && cal.isDate(tx.date, equalTo: now, toGranularity: .month)
        {
            if tx.isShared {
                let parts = mock.splitFor(amount: tx.amount, splitType: tx.splitType ?? split)
                u1Expenses += parts.user1
                u2Expenses += parts.user2
            } else if tx.userId == mock.currentUser1Id {
                u1Expenses += tx.amount
            } else if tx.userId == mock.currentUser2Id {
                u2Expenses += tx.amount
            }
        }

        let u1Available = mock.currentUser1Income - u1Expenses
        let u2Available = mock.currentUser2Income - u2Expenses
        return (u1Available, u2Available)
    }

    /// Disponible mensual de cada miembro DESPUES de aplicar la simulacion seleccionada.
    func coupleAvailableAfter() -> (user1: Decimal, user2: Decimal) {
        guard let sim = currentSimulation else { return coupleAvailableBefore }
        let before = coupleAvailableBefore
        let amount = sim.params.monthlyAmount

        // Decide a quien afecta segun affectedPartner del form
        let target: AffectedPartner = formAffectedPartner

        // Signo del impacto: positivo = mas dinero, negativo = menos
        let signedDelta: Decimal
        switch sim.type {
        case .incomeIncrease:
            signedDelta = amount
        case .expenseReduction:
            signedDelta = amount   // ahorro mensual = mas disponible
        case .savingsProjection, .emergencyFund:
            signedDelta = -amount  // se aporta a ahorro = menos disponible
        case .debtPayoff:
            signedDelta = -amount  // pago a deuda = menos disponible
        }

        switch target {
        case .both:
            let half = signedDelta / 2
            return (before.user1 + half, before.user2 + half)
        case .user1:
            return (before.user1 + signedDelta, before.user2)
        case .user2:
            return (before.user1, before.user2 + signedDelta)
        }
    }

    /// Reset incluyendo el affected partner.
    func resetCoupleForm() {
        formAffectedPartner = .both
    }

    // MARK: - Helpers

    func resetForm() {
        formMonthlyAmount = ""
        formTargetAmount = ""
        formInterestRate = ""
        formMonths = 12
        formAffectedPartner = .both
        errorMessage = nil
    }

    private func validateForm() -> Bool {
        let monthly = parseDecimal(formMonthlyAmount)
        if monthly <= 0 {
            errorMessage = "El monto mensual debe ser mayor a cero."
            return false
        }
        if formMonths < 1 || formMonths > 360 {
            errorMessage = "Los meses deben ser entre 1 y 360."
            return false
        }
        return true
    }

    private func parseDecimal(_ text: String) -> Decimal {
        let digits = text.filter(\.isNumber)
        return Decimal(string: digits) ?? Decimal.zero
    }
}
