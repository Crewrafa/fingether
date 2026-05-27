import XCTest
@testable import Spendly

final class ScoreCalculationTests: XCTestCase {

    private let coupleUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!

    @MainActor
    override func setUp() {
        super.setUp()
        MockDataService.shared.seedClean()
        MockDataService.shared.isEnabled = true
    }

    // MARK: - Score With Seeded Data

    @MainActor
    func testScoreWithFullSeedData() {
        let mock = MockDataService.shared
        // Use full seed data instead of clean
        mock.seedAllData()

        let score = mock.calculateFinancialScore(coupleId: coupleUUID)

        XCTAssertGreaterThanOrEqual(score.score, 0)
        XCTAssertLessThanOrEqual(score.score, 100)
        XCTAssertEqual(score.coupleId, coupleUUID)
    }

    // MARK: - Breakdown Components Are In Range

    @MainActor
    func testBreakdownComponentsInRange() {
        let mock = MockDataService.shared
        mock.seedAllData()

        let score = mock.calculateFinancialScore(coupleId: coupleUUID)
        let b = score.breakdown

        XCTAssertGreaterThanOrEqual(b.budgetAdherence, 0)
        XCTAssertLessThanOrEqual(b.budgetAdherence, 100)

        XCTAssertGreaterThanOrEqual(b.savingsRate, 0)
        XCTAssertLessThanOrEqual(b.savingsRate, 100)

        XCTAssertGreaterThanOrEqual(b.debtManagement, 0)
        XCTAssertLessThanOrEqual(b.debtManagement, 100)

        XCTAssertGreaterThanOrEqual(b.transactionConsistency, 0)
        XCTAssertLessThanOrEqual(b.transactionConsistency, 100)

        XCTAssertGreaterThanOrEqual(b.goalProgress, 0)
        XCTAssertLessThanOrEqual(b.goalProgress, 100)

        XCTAssertGreaterThanOrEqual(b.spendingDiversity, 0)
        XCTAssertLessThanOrEqual(b.spendingDiversity, 100)
    }

    // MARK: - Overall Is Average Of 6 Components

    @MainActor
    func testOverallIsAverageOfComponents() {
        let mock = MockDataService.shared
        mock.seedAllData()

        let score = mock.calculateFinancialScore(coupleId: coupleUUID)
        let b = score.breakdown

        let sum = b.budgetAdherence + b.savingsRate + b.debtManagement +
                  b.transactionConsistency + b.goalProgress + b.spendingDiversity
        let expectedOverall = sum / 6

        XCTAssertEqual(b.overall, expectedOverall,
                       "Overall score should be the integer average of all 6 components")
        XCTAssertEqual(score.score, b.overall,
                       "FinancialScore.score should match breakdown.overall")
    }

    // MARK: - Clean State Score

    @MainActor
    func testScoreWithCleanState() {
        let mock = MockDataService.shared
        mock.completeOnboarding(displayName: "Test", monthlyIncome: 5000, currency: "MXN")

        let score = mock.calculateFinancialScore(coupleId: coupleUUID)

        // With no budgets, no debts, no goals, no transactions:
        // budgetAdherence = 50 (no budgets)
        // savingsRate = 30 (no income tracked) or calculated if income tx exists
        // debtManagement = 80 (no debts)
        // transactionConsistency = 0 (streakDays = 0)
        // goalProgress = 40 (no goals)
        // spendingDiversity = 0 (no expenses)
        XCTAssertGreaterThanOrEqual(score.score, 0)
        XCTAssertLessThanOrEqual(score.score, 100)
    }

    // MARK: - Score With Income Only

    @MainActor
    func testScoreWithIncomeOnly() {
        let mock = MockDataService.shared
        let devUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        mock.completeOnboarding(displayName: "Test", monthlyIncome: 10000, currency: "MXN")

        let now = Date()
        let incomeTx = Transaction(
            id: UUID(), userId: devUserId, coupleId: coupleUUID,
            type: .income, category: .salary, amount: 10000,
            description: "Salario", notes: nil, date: now,
            isRecurring: false, recurringFrequency: nil,
            createdAt: now, updatedAt: now
        )
        _ = mock.addMockTransaction(incomeTx)

        let score = mock.calculateFinancialScore(coupleId: coupleUUID)

        // With income but no expenses, savingsRate should be 100 (all income saved)
        XCTAssertEqual(score.breakdown.savingsRate, 100,
                       "With income and no expenses, savings rate should be 100")
    }

    // MARK: - Tips Are Generated

    @MainActor
    func testTipsAreGenerated() {
        let mock = MockDataService.shared
        mock.seedAllData()

        let score = mock.calculateFinancialScore(coupleId: coupleUUID)
        XCTAssertFalse(score.tips.isEmpty, "Score should include at least one tip")
    }

    // MARK: - Trend Is Stable With No History

    @MainActor
    func testTrendStableWithNoHistory() {
        let mock = MockDataService.shared
        mock.completeOnboarding(displayName: "Test", monthlyIncome: 5000, currency: "MXN")
        mock.mockScoreHistory = []

        let score = mock.calculateFinancialScore(coupleId: coupleUUID)
        XCTAssertEqual(score.trend, .stable, "Trend should be stable when there is no score history")
    }

    // MARK: - Score Label Matches Range

    @MainActor
    func testScoreLabelMatchesRange() {
        let mock = MockDataService.shared
        mock.seedAllData()

        let score = mock.calculateFinancialScore(coupleId: coupleUUID)

        // Verify the label corresponds to the score value
        switch score.score {
        case 85...100:
            XCTAssertEqual(score.scoreLabel, "Excelente")
        case 75..<85:
            XCTAssertEqual(score.scoreLabel, "Muy bien")
        case 60..<75:
            XCTAssertEqual(score.scoreLabel, "Bien")
        case 40..<60:
            XCTAssertEqual(score.scoreLabel, "Regular")
        case 20..<40:
            XCTAssertEqual(score.scoreLabel, "Necesita mejora")
        default:
            XCTAssertEqual(score.scoreLabel, "Critico")
        }
    }
}
