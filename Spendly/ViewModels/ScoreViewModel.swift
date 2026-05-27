import Foundation

@MainActor
@Observable
final class ScoreViewModel {

    // MARK: - State

    var currentScore: FinancialScore?
    var scoreHistory: [FinancialScore] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Computed

    var scoreValue: Int {
        currentScore?.score ?? 0
    }

    var scoreProgress: Double {
        Double(scoreValue) / 100.0
    }

    var trend: ScoreTrend {
        currentScore?.trend ?? .stable
    }

    var breakdown: ScoreBreakdown? {
        currentScore?.breakdown
    }

    var tips: [String] {
        currentScore?.tips ?? []
    }

    // MARK: - Actions

    func loadScore(coupleId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let mockData = MockDataService.shared
        let calculated = mockData.calculateFinancialScore(coupleId: coupleId)
        currentScore = calculated
        scoreHistory = mockData.mockScoreHistory

        // Update today's entry in history with the calculated score
        if let lastIdx = scoreHistory.lastIndex(where: { Calendar.current.isDateInToday($0.calculatedAt) }) {
            scoreHistory[lastIdx] = calculated
            mockData.mockScoreHistory = scoreHistory
        } else {
            scoreHistory.append(calculated)
            mockData.mockScoreHistory = scoreHistory
        }
    }

    func refreshScore(coupleId: UUID) async {
        let mockData = MockDataService.shared
        let newScore = mockData.calculateFinancialScore(coupleId: coupleId)
        currentScore = newScore

        // Add to history
        mockData.mockScoreHistory.append(newScore)

        // Keep only last 12 entries
        if mockData.mockScoreHistory.count > 12 {
            mockData.mockScoreHistory = Array(mockData.mockScoreHistory.suffix(12))
        }
        scoreHistory = mockData.mockScoreHistory
    }

    // MARK: - Couple Contribution (only used in couple mode)

    /// Desglose de cuanto contribuye cada miembro de la pareja al score, sub-score por sub-score.
    /// Cada valor es 0–100 (porcentaje del sub-score atribuible a esa persona).
    /// Lee MockDataService directamente — mantiene el patron existente del Score.
    struct CoupleContribution: Sendable {
        var consistencyUser1: Int    // % del transactionConsistency
        var consistencyUser2: Int
        var savingsUser1: Int        // % del goalProgress (quien aporto mas a metas)
        var savingsUser2: Int
        var spendingUser1: Int       // % de quien gasta menos (mas saludable)
        var spendingUser2: Int
        var transactionsUser1: Int   // % de quien registra mas transacciones
        var transactionsUser2: Int
        /// Resumen general 0–100 que sintetiza la contribucion total al score.
        var overallUser1: Int
        var overallUser2: Int
    }

    var coupleContribution: CoupleContribution {
        let mock = MockDataService.shared
        let now = Date()
        let cal = Calendar.current

        let monthTxs = mock.mockTransactions.filter {
            cal.isDate($0.date, equalTo: now, toGranularity: .month)
        }

        // --- Transactions count ratio ---
        let u1Tx = monthTxs.filter { $0.userId == mock.currentUser1Id }.count
        let u2Tx = monthTxs.filter { $0.userId == mock.currentUser2Id }.count
        let totalTx = max(u1Tx + u2Tx, 1)
        let u1TxPct = Int((Double(u1Tx) / Double(totalTx) * 100).rounded())
        let u2TxPct = 100 - u1TxPct

        // --- Streaks ratio (consistency) ---
        let u1Streak = mock.mockProfile?.streakDays ?? 0
        let u2Streak = mock.mockPartnerProfile?.streakDays ?? 0
        let totalStreak = max(u1Streak + u2Streak, 1)
        let u1StreakPct = Int((Double(u1Streak) / Double(totalStreak) * 100).rounded())
        let u2StreakPct = 100 - u1StreakPct

        // --- Spending share (lower expense share = healthier) ---
        let split = mock.coupleSettings.defaultSplitType
        var u1Expenses: Decimal = 0
        var u2Expenses: Decimal = 0
        for tx in monthTxs where tx.type == .expense {
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
        // "Spending healthiness": quien gasta menos en proporcion a su ingreso contribuye mas al score
        let u1Income = mock.currentUser1Income
        let u2Income = mock.currentUser2Income

        var u1SpendRatio: Double = 1.0
        if u1Income > 0 {
            u1SpendRatio = NSDecimalNumber(decimal: u1Expenses / u1Income).doubleValue
        }

        var u2SpendRatio: Double = 1.0
        if u2Income > 0 {
            u2SpendRatio = NSDecimalNumber(decimal: u2Expenses / u2Income).doubleValue
        }

        let u1Healthiness = max(0.0, 1.0 - u1SpendRatio)
        let u2Healthiness = max(0.0, 1.0 - u2SpendRatio)
        let totalHealth = max(u1Healthiness + u2Healthiness, 0.0001)
        let u1SpendingPct = Int((u1Healthiness / totalHealth * 100).rounded())
        let u2SpendingPct = 100 - u1SpendingPct

        // --- Savings: aproximacion segun share de ingreso ---
        var u1SavingsPct = 50
        var u2SavingsPct = 50
        let totalIncome = u1Income + u2Income
        if totalIncome > 0 {
            let u1Share = NSDecimalNumber(decimal: u1Income / totalIncome).doubleValue
            u1SavingsPct = Int((u1Share * 100).rounded())
            u2SavingsPct = 100 - u1SavingsPct
        }

        // --- Overall: promedio simple de los 4 componentes ---
        let overall1 = (u1TxPct + u1StreakPct + u1SpendingPct + u1SavingsPct) / 4
        let overall2 = 100 - overall1

        return CoupleContribution(
            consistencyUser1: u1StreakPct, consistencyUser2: u2StreakPct,
            savingsUser1: u1SavingsPct, savingsUser2: u2SavingsPct,
            spendingUser1: u1SpendingPct, spendingUser2: u2SpendingPct,
            transactionsUser1: u1TxPct, transactionsUser2: u2TxPct,
            overallUser1: overall1, overallUser2: overall2
        )
    }
}
