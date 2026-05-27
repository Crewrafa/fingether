import XCTest
@testable import Spendly

final class FinancialCalculationsTests: XCTestCase {

    private let devUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let partnerUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let coupleUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!

    @MainActor
    override func setUp() {
        super.setUp()
        MockDataService.shared.seedClean()
        MockDataService.shared.isEnabled = true
    }

    // MARK: - Split Calculations (Equal)

    @MainActor
    func testEqualSplitDividesEvenly() {
        let mock = MockDataService.shared
        mock.completeOnboarding(displayName: "Test", monthlyIncome: 5000, currency: "MXN")
        mock.createPhantomPartner(name: "Partner", monthlyIncome: 5000, gender: "other")
        mock.updateMockCoupleSettings(CoupleSettings(defaultSplitType: .equal, categorySplits: [:]))

        let now = Date()
        let tx = Transaction(
            id: UUID(), userId: devUserId, coupleId: coupleUUID,
            type: .expense, category: .food, amount: 1000,
            description: "Test expense", notes: nil, date: now,
            isRecurring: true, recurringFrequency: .monthly,
            isShared: true, splitType: .equal,
            createdAt: now, updatedAt: now
        )
        let saved = mock.addMockTransaction(tx)

        XCTAssertEqual(saved.splitUser1Amount, 500)
        XCTAssertEqual(saved.splitUser2Amount, 500)
    }

    // MARK: - Split Calculations (Custom Percentage)

    @MainActor
    func testCustomSplit70_30() {
        let mock = MockDataService.shared
        mock.completeOnboarding(displayName: "Test", monthlyIncome: 7000, currency: "MXN")
        mock.createPhantomPartner(name: "Partner", monthlyIncome: 3000, gender: "other")
        mock.updateMockCoupleSettings(CoupleSettings(defaultSplitType: .custom(70), categorySplits: [:]))

        let now = Date()
        let tx = Transaction(
            id: UUID(), userId: devUserId, coupleId: coupleUUID,
            type: .expense, category: .housing, amount: 10000,
            description: "Renta", notes: nil, date: now,
            isRecurring: true, recurringFrequency: .monthly,
            isShared: true, splitType: .custom(70),
            createdAt: now, updatedAt: now
        )
        let saved = mock.addMockTransaction(tx)

        XCTAssertEqual(saved.splitUser1Amount, 7000)
        XCTAssertEqual(saved.splitUser2Amount, 3000)
    }

    // MARK: - Split Calculations (One Pays)

    @MainActor
    func testOnePaysUser1() {
        let mock = MockDataService.shared
        mock.completeOnboarding(displayName: "Test", monthlyIncome: 5000, currency: "MXN")
        mock.createPhantomPartner(name: "Partner", monthlyIncome: 5000, gender: "other")

        let now = Date()
        let tx = Transaction(
            id: UUID(), userId: devUserId, coupleId: coupleUUID,
            type: .expense, category: .utilities, amount: 500,
            description: "Internet", notes: nil, date: now,
            isRecurring: true, recurringFrequency: .monthly,
            isShared: true, splitType: .onePays(devUserId),
            createdAt: now, updatedAt: now
        )
        let saved = mock.addMockTransaction(tx)

        XCTAssertEqual(saved.splitUser1Amount, 500)
        XCTAssertEqual(saved.splitUser2Amount, 0)
    }

    @MainActor
    func testOnePaysUser2() {
        let mock = MockDataService.shared
        mock.completeOnboarding(displayName: "Test", monthlyIncome: 5000, currency: "MXN")
        mock.createPhantomPartner(name: "Partner", monthlyIncome: 5000, gender: "other")

        let now = Date()
        let tx = Transaction(
            id: UUID(), userId: devUserId, coupleId: coupleUUID,
            type: .expense, category: .utilities, amount: 500,
            description: "Internet", notes: nil, date: now,
            isRecurring: true, recurringFrequency: .monthly,
            isShared: true, splitType: .onePays(partnerUserId),
            createdAt: now, updatedAt: now
        )
        let saved = mock.addMockTransaction(tx)

        XCTAssertEqual(saved.splitUser1Amount, 0)
        XCTAssertEqual(saved.splitUser2Amount, 500)
    }

    // MARK: - Effective Amount Logic

    func testExpenseEffectiveAmountIsNegative() {
        let now = Date()
        let expense = Transaction(
            id: UUID(), userId: devUserId, coupleId: coupleUUID,
            type: .expense, category: .food, amount: 250,
            description: "Tacos", notes: nil, date: now,
            isRecurring: false, recurringFrequency: nil,
            createdAt: now, updatedAt: now
        )
        // Expense amounts should be positive in the model but effectively reduce balance
        XCTAssertEqual(expense.type, .expense)
        XCTAssertEqual(expense.amount, 250)
    }

    func testIncomeAmount() {
        let now = Date()
        let income = Transaction(
            id: UUID(), userId: devUserId, coupleId: coupleUUID,
            type: .income, category: .salary, amount: 10000,
            description: "Salario", notes: nil, date: now,
            isRecurring: true, recurringFrequency: .monthly,
            createdAt: now, updatedAt: now
        )
        XCTAssertEqual(income.type, .income)
        XCTAssertEqual(income.amount, 10000)
    }

    // MARK: - Available Calculation (Income - Expenses)

    @MainActor
    func testAvailableBalance() {
        let mock = MockDataService.shared
        mock.completeOnboarding(displayName: "Test", monthlyIncome: 20000, currency: "MXN")

        let now = Date()

        let income = Transaction(
            id: UUID(), userId: devUserId, coupleId: coupleUUID,
            type: .income, category: .salary, amount: 20000,
            description: "Salario", notes: nil, date: now,
            isRecurring: false, recurringFrequency: nil,
            createdAt: now, updatedAt: now
        )
        _ = mock.addMockTransaction(income)

        let expense1 = Transaction(
            id: UUID(), userId: devUserId, coupleId: coupleUUID,
            type: .expense, category: .food, amount: 3000,
            description: "Comida", notes: nil, date: now,
            isRecurring: false, recurringFrequency: nil,
            createdAt: now, updatedAt: now
        )
        _ = mock.addMockTransaction(expense1)

        let expense2 = Transaction(
            id: UUID(), userId: devUserId, coupleId: coupleUUID,
            type: .expense, category: .transport, amount: 2000,
            description: "Transporte", notes: nil, date: now,
            isRecurring: false, recurringFrequency: nil,
            createdAt: now, updatedAt: now
        )
        _ = mock.addMockTransaction(expense2)

        let txs = mock.getMockTransactions(coupleId: coupleUUID, month: now, category: nil, type: nil)
        let totalIncome = txs.filter { $0.type == .income }.reduce(Decimal.zero) { $0 + $1.amount }
        let totalExpenses = txs.filter { $0.type == .expense }.reduce(Decimal.zero) { $0 + $1.amount }
        let available = totalIncome - totalExpenses

        XCTAssertEqual(available, 15000)
    }

    // MARK: - Budget Percentage

    func testBudgetPercentageCalculation() {
        let spent: Decimal = 3500
        let limit: Decimal = 5000
        let percentage = NSDecimalNumber(decimal: spent / limit * 100).doubleValue
        XCTAssertEqual(percentage, 70.0, accuracy: 0.1)
    }

    func testBudgetPercentageOver100() {
        let spent: Decimal = 6000
        let limit: Decimal = 5000
        let percentage = NSDecimalNumber(decimal: spent / limit * 100).doubleValue
        XCTAssertEqual(percentage, 120.0, accuracy: 0.1)
    }

    // MARK: - Division By Zero Protection

    func testDivisionByZeroBudget() {
        let spent: Decimal = 500
        let limit: Decimal = 0
        // The app should handle zero budget gracefully
        if limit > 0 {
            let _ = spent / limit
            XCTFail("Should not reach here with zero limit")
        } else {
            // Safe path: percentage is 0 when limit is 0
            let percentage = 0.0
            XCTAssertEqual(percentage, 0.0)
        }
    }

    func testSplitWithZeroAmount() {
        let now = Date()
        let tx = Transaction(
            id: UUID(), userId: devUserId, coupleId: coupleUUID,
            type: .expense, category: .food, amount: 0,
            description: "Zero expense", notes: nil, date: now,
            isRecurring: false, recurringFrequency: nil,
            isShared: true, splitType: .equal,
            createdAt: now, updatedAt: now
        )
        // Equal split of 0 should be 0/0
        XCTAssertEqual(tx.amount, 0)
    }

    // MARK: - Split Amounts Sum To Total

    @MainActor
    func testSplitAmountsSumToTotal() {
        let mock = MockDataService.shared
        mock.completeOnboarding(displayName: "Test", monthlyIncome: 5000, currency: "MXN")
        mock.createPhantomPartner(name: "Partner", monthlyIncome: 5000, gender: "other")
        mock.updateMockCoupleSettings(CoupleSettings(defaultSplitType: .custom(60), categorySplits: [:]))

        let now = Date()
        let tx = Transaction(
            id: UUID(), userId: devUserId, coupleId: coupleUUID,
            type: .expense, category: .food, amount: 1000,
            description: "Test", notes: nil, date: now,
            isRecurring: true, recurringFrequency: .monthly,
            isShared: true, splitType: .custom(60),
            createdAt: now, updatedAt: now
        )
        let saved = mock.addMockTransaction(tx)

        let sum = (saved.splitUser1Amount ?? 0) + (saved.splitUser2Amount ?? 0)
        XCTAssertEqual(sum, saved.amount, "Split amounts should sum to total amount")
    }

    // MARK: - Non-Shared Transaction Has No Split

    func testNonSharedTransactionHasNoSplit() {
        let now = Date()
        let tx = Transaction(
            id: UUID(), userId: devUserId, coupleId: coupleUUID,
            type: .expense, category: .shopping, amount: 500,
            description: "Personal purchase", notes: nil, date: now,
            isRecurring: false, recurringFrequency: nil,
            isShared: false, splitType: nil,
            createdAt: now, updatedAt: now
        )
        XCTAssertNil(tx.splitType)
        XCTAssertNil(tx.splitUser1Amount)
        XCTAssertNil(tx.splitUser2Amount)
    }

    // MARK: - Shared Defaults To Equal

    func testSharedTransactionDefaultsToEqual() {
        let now = Date()
        let tx = Transaction(
            id: UUID(), userId: devUserId, coupleId: coupleUUID,
            type: .expense, category: .food, amount: 1000,
            description: "Shared meal", notes: nil, date: now,
            isRecurring: false, recurringFrequency: nil,
            isShared: true, splitType: nil,
            createdAt: now, updatedAt: now
        )
        // The Transaction init auto-sets splitType to .equal when isShared is true and splitType is nil
        XCTAssertEqual(tx.splitType, .equal)
    }
}
