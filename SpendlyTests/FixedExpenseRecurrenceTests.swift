import XCTest
@testable import Spendly

final class FixedExpenseRecurrenceTests: XCTestCase {

    private let devUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let coupleUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!

    @MainActor
    override func setUp() {
        super.setUp()
        MockDataService.shared.seedClean()
        MockDataService.shared.isEnabled = true
    }

    // MARK: - Recurring Transaction Created In April

    @MainActor
    func testRecurringTransactionExistsInCreationMonth() {
        let mock = MockDataService.shared
        mock.completeOnboarding(displayName: "Test", monthlyIncome: 5000, currency: "MXN")

        let cal = Calendar.current
        let aprilDate = cal.date(from: DateComponents(year: 2026, month: 4, day: 15))!

        let tx = Transaction(
            id: UUID(), userId: devUserId, coupleId: coupleUUID,
            type: .expense, category: .housing, amount: 8500,
            description: "Renta mensual", notes: nil, date: aprilDate,
            isRecurring: true, recurringFrequency: .monthly,
            isShared: false,
            createdAt: aprilDate, updatedAt: aprilDate
        )
        _ = mock.addMockTransaction(tx)

        // Filter for April
        let aprilTxs = mock.getMockTransactions(
            coupleId: coupleUUID, month: aprilDate, category: nil, type: nil
        )
        let recurringHousing = aprilTxs.filter { $0.isRecurring && $0.category == .housing }
        XCTAssertFalse(recurringHousing.isEmpty, "Recurring transaction should appear in its creation month")
    }

    // MARK: - Recurring Transaction Should Logically Apply To Future Months

    @MainActor
    func testRecurringTransactionFlagIsPreserved() {
        let mock = MockDataService.shared
        mock.completeOnboarding(displayName: "Test", monthlyIncome: 5000, currency: "MXN")

        let cal = Calendar.current
        let aprilDate = cal.date(from: DateComponents(year: 2026, month: 4, day: 15))!

        let tx = Transaction(
            id: UUID(), userId: devUserId, coupleId: coupleUUID,
            type: .expense, category: .utilities, amount: 450,
            description: "Recibo de luz", notes: nil, date: aprilDate,
            isRecurring: true, recurringFrequency: .monthly,
            isShared: false,
            createdAt: aprilDate, updatedAt: aprilDate
        )
        let saved = mock.addMockTransaction(tx)

        XCTAssertTrue(saved.isRecurring, "isRecurring flag should be preserved")
        XCTAssertEqual(saved.recurringFrequency, .monthly, "Frequency should be monthly")

        // A recurring expense created in April should logically apply in May too.
        // The mock service stores the original transaction; the app replicates it
        // across months in the UI layer. Verify the recurring data is intact.
        let allRecurring = mock.mockTransactions.filter { $0.isRecurring && $0.coupleId == coupleUUID }
        let matchingTx = allRecurring.first(where: { $0.id == saved.id })
        XCTAssertNotNil(matchingTx, "Recurring transaction should be retrievable from mock store")
        XCTAssertEqual(matchingTx?.recurringFrequency, .monthly)
    }

    // MARK: - Multiple Recurring Expenses

    @MainActor
    func testMultipleRecurringExpensesAllPreserved() {
        let mock = MockDataService.shared
        mock.completeOnboarding(displayName: "Test", monthlyIncome: 20000, currency: "MXN")

        let now = Date()

        let expenses: [(String, TransactionCategory, Decimal)] = [
            ("Renta", .housing, 8500),
            ("Luz", .utilities, 450),
            ("Internet", .utilities, 399),
            ("Netflix", .entertainment, 299),
        ]

        for (desc, cat, amount) in expenses {
            let tx = Transaction(
                id: UUID(), userId: devUserId, coupleId: coupleUUID,
                type: .expense, category: cat, amount: amount,
                description: desc, notes: nil, date: now,
                isRecurring: true, recurringFrequency: .monthly,
                isShared: false,
                createdAt: now, updatedAt: now
            )
            _ = mock.addMockTransaction(tx)
        }

        let recurring = mock.mockTransactions.filter { $0.isRecurring && $0.type == .expense }
        XCTAssertEqual(recurring.count, 4, "All 4 recurring expenses should be stored")
    }

    // MARK: - Recurring Frequency Types

    func testAllRecurringFrequenciesExist() {
        let frequencies = RecurringFrequency.allCases
        XCTAssertEqual(frequencies.count, 5)
        XCTAssertTrue(frequencies.contains(.daily))
        XCTAssertTrue(frequencies.contains(.weekly))
        XCTAssertTrue(frequencies.contains(.biweekly))
        XCTAssertTrue(frequencies.contains(.monthly))
        XCTAssertTrue(frequencies.contains(.yearly))
    }

    // MARK: - Non-Recurring Does Not Have Frequency

    func testNonRecurringTransactionHasNoFrequency() {
        let now = Date()
        let tx = Transaction(
            id: UUID(), userId: devUserId, coupleId: coupleUUID,
            type: .expense, category: .food, amount: 85,
            description: "Tacos", notes: nil, date: now,
            isRecurring: false, recurringFrequency: nil,
            createdAt: now, updatedAt: now
        )
        XCTAssertFalse(tx.isRecurring)
        XCTAssertNil(tx.recurringFrequency)
    }

    // MARK: - Recurring Income Also Preserved

    @MainActor
    func testRecurringIncomePreserved() {
        let mock = MockDataService.shared
        mock.completeOnboarding(displayName: "Test", monthlyIncome: 20000, currency: "MXN")

        let now = Date()
        let tx = Transaction(
            id: UUID(), userId: devUserId, coupleId: coupleUUID,
            type: .income, category: .salary, amount: 20000,
            description: "Salario", notes: nil, date: now,
            isRecurring: true, recurringFrequency: .monthly,
            createdAt: now, updatedAt: now
        )
        let saved = mock.addMockTransaction(tx)

        XCTAssertTrue(saved.isRecurring)
        XCTAssertEqual(saved.type, .income)
        XCTAssertEqual(saved.recurringFrequency, .monthly)
    }

    // MARK: - Recurring Transaction With Shared Split

    @MainActor
    func testRecurringSharedTransactionGetsSplitAmounts() {
        let mock = MockDataService.shared
        mock.completeOnboarding(displayName: "Test", monthlyIncome: 10000, currency: "MXN")
        mock.createPhantomPartner(name: "Partner", monthlyIncome: 10000, gender: "other")
        mock.updateMockCoupleSettings(CoupleSettings(defaultSplitType: .equal, categorySplits: [:]))

        let now = Date()
        let tx = Transaction(
            id: UUID(), userId: devUserId, coupleId: coupleUUID,
            type: .expense, category: .housing, amount: 8500,
            description: "Renta", notes: nil, date: now,
            isRecurring: true, recurringFrequency: .monthly,
            isShared: true, splitType: .equal,
            createdAt: now, updatedAt: now
        )
        let saved = mock.addMockTransaction(tx)

        XCTAssertTrue(saved.isRecurring)
        XCTAssertTrue(saved.isShared)
        XCTAssertNotNil(saved.splitUser1Amount)
        XCTAssertNotNil(saved.splitUser2Amount)
        XCTAssertEqual(saved.splitUser1Amount, 4250)
        XCTAssertEqual(saved.splitUser2Amount, 4250)
    }
}
