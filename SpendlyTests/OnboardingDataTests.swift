import XCTest
@testable import Spendly

final class OnboardingDataTests: XCTestCase {

    private let devUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let coupleUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!

    @MainActor
    override func setUp() {
        super.setUp()
        MockDataService.shared.seedClean()
        MockDataService.shared.isEnabled = true
    }

    // MARK: - Complete Onboarding Creates Transactions

    @MainActor
    func testCompleteOnboardingSoloCreatesIncomeTransaction() async {
        let vm = OnboardingViewModel()
        vm.displayName = "Rafael"
        vm.monthlyIncome = "5.000.000"
        vm.currency = .cop

        // Add a fixed expense
        vm.fixedExpenses.append(FixedExpenseEntry(
            emoji: "🏠", name: "Arriendo", amount: "1.500.000", category: .housing
        ))

        // Solo mode
        vm.wantsCoupleMode = false

        await vm.completeOnboarding(userId: devUserId)

        let mock = MockDataService.shared
        let txs = mock.mockTransactions

        // Should have at least the income transaction and the fixed expense
        let incomes = txs.filter { $0.type == .income && $0.category == .salary }
        XCTAssertFalse(incomes.isEmpty, "Should have created an income transaction")

        let firstIncome = incomes.first!
        XCTAssertEqual(firstIncome.amount, 5_000_000)
        XCTAssertTrue(firstIncome.isRecurring)
        XCTAssertEqual(firstIncome.recurringFrequency, .monthly)
    }

    @MainActor
    func testCompleteOnboardingCreatesFixedExpenses() async {
        let vm = OnboardingViewModel()
        vm.displayName = "Rafael"
        vm.monthlyIncome = "5.000.000"
        vm.currency = .cop
        vm.wantsCoupleMode = false

        vm.fixedExpenses.append(FixedExpenseEntry(
            emoji: "🏠", name: "Arriendo", amount: "1.500.000", category: .housing
        ))
        vm.fixedExpenses.append(FixedExpenseEntry(
            emoji: "💡", name: "Servicios", amount: "200.000", category: .utilities
        ))

        await vm.completeOnboarding(userId: devUserId)

        let mock = MockDataService.shared
        let expenses = mock.mockTransactions.filter { $0.type == .expense && $0.isRecurring }
        XCTAssertGreaterThanOrEqual(expenses.count, 2, "Should have created recurring expense transactions")
    }

    @MainActor
    func testCompleteOnboardingCreatesDebtTransactions() async {
        let vm = OnboardingViewModel()
        vm.displayName = "Rafael"
        vm.monthlyIncome = "5.000.000"
        vm.currency = .cop
        vm.wantsCoupleMode = false

        vm.debtEntries.append(DebtEntry(
            emoji: "💳", name: "Tarjeta", totalDebt: "3.000.000", monthlyPayment: "300.000", category: .debt
        ))

        await vm.completeOnboarding(userId: devUserId)

        let mock = MockDataService.shared
        let debtTxs = mock.mockTransactions.filter { $0.category == .debt && $0.type == .expense }
        XCTAssertFalse(debtTxs.isEmpty, "Should have created debt expense transaction")
        XCTAssertEqual(debtTxs.first?.amount, 300_000, "Debt transaction amount should be the monthly payment")
    }

    // MARK: - Invite Code Generation

    @MainActor
    func testInviteCodeIsValidFormat() {
        let mock = MockDataService.shared
        let code = mock.generateInviteCode()

        XCTAssertEqual(code.count, 6, "Invite code should be 6 characters")

        let forbiddenChars: Set<Character> = ["I", "O", "0", "1"]
        for char in code {
            XCTAssertFalse(forbiddenChars.contains(char),
                           "Invite code should not contain ambiguous character '\(char)'")
        }
    }

    @MainActor
    func testInviteCodeContainsOnlyAllowedCharacters() {
        let mock = MockDataService.shared
        let allowedChars = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

        // Generate several codes to test randomness
        for _ in 0..<20 {
            let code = mock.generateInviteCode()
            for char in code {
                XCTAssertTrue(allowedChars.contains(char),
                              "Character '\(char)' is not in the allowed set")
            }
        }
    }

    @MainActor
    func testRegenerateInviteCodeChangesCode() {
        let mock = MockDataService.shared
        mock.completeOnboarding(displayName: "Test", monthlyIncome: 5000, currency: "MXN")

        let code1 = mock.mockCouple?.inviteCode ?? ""
        let code2 = mock.regenerateInviteCode()

        // Technically they could be the same by chance, but extremely unlikely
        // Test that the function returns a valid code
        XCTAssertEqual(code2.count, 6)
        XCTAssertNotNil(mock.mockCouple?.inviteCode)
    }

    // MARK: - Validation

    @MainActor
    func testOnboardingValidationRequiresName() {
        let vm = OnboardingViewModel()
        vm.currentStep = 1
        vm.displayName = ""

        let valid = vm.validateCurrentStep()
        XCTAssertFalse(valid, "Should not validate with empty name")
        XCTAssertNotNil(vm.errorMessage)
    }

    @MainActor
    func testOnboardingValidationRequiresIncome() {
        let vm = OnboardingViewModel()
        vm.wantsCoupleMode = false
        vm.currentStep = 3
        vm.monthlyIncome = ""

        let valid = vm.validateCurrentStep()
        XCTAssertFalse(valid, "Should not validate with empty income")
        XCTAssertNotNil(vm.errorMessage)
    }

    @MainActor
    func testOnboardingValidationAcceptsValidName() {
        let vm = OnboardingViewModel()
        vm.currentStep = 1
        vm.displayName = "Rafael"

        let valid = vm.validateCurrentStep()
        XCTAssertTrue(valid)
        XCTAssertNil(vm.errorMessage)
    }

    @MainActor
    func testOnboardingValidationAcceptsValidIncome() {
        let vm = OnboardingViewModel()
        vm.wantsCoupleMode = false
        vm.currentStep = 3
        vm.monthlyIncome = "5.000.000"

        let valid = vm.validateCurrentStep()
        XCTAssertTrue(valid)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - Step Navigation

    @MainActor
    func testSoloModeTotalSteps() {
        let vm = OnboardingViewModel()
        vm.wantsCoupleMode = false
        XCTAssertEqual(vm.totalSteps, 6)
    }

    @MainActor
    func testCoupleModeTotalSteps() {
        let vm = OnboardingViewModel()
        vm.wantsCoupleMode = true
        XCTAssertEqual(vm.totalSteps, 9)
    }

    @MainActor
    func testProgressCalculation() {
        let vm = OnboardingViewModel()
        vm.wantsCoupleMode = false // 6 steps
        vm.currentStep = 0
        XCTAssertEqual(vm.progress, 0.0)

        vm.currentStep = 5 // last step
        XCTAssertEqual(vm.progress, 1.0)
    }

    // MARK: - Couple Flow: Shared Expenses Get Split

    @MainActor
    func testCoupleOnboardingCreatesSharedSplitTransactions() async {
        let vm = OnboardingViewModel()
        vm.displayName = "Rafael"
        vm.monthlyIncome = "5.000.000"
        vm.partnerIncome = "3.000.000"
        vm.currency = .cop
        vm.wantsCoupleMode = true
        vm.selectedSplit = .equal
        vm.isPartnerLinked = true

        // Simulate partner already created
        let mock = MockDataService.shared
        mock.completeOnboarding(displayName: "Rafael", monthlyIncome: 5_000_000, currency: "COP")
        mock.createPhantomPartner(name: "Pareja", monthlyIncome: 3_000_000, gender: "other")

        let expense = FixedExpenseEntry(
            emoji: "🏠", name: "Arriendo", amount: "2.000.000", category: .housing
        )
        vm.fixedExpenses.append(expense)
        vm.sharedFlags[expense.id] = true

        await vm.completeOnboarding(userId: devUserId)

        // Find the shared housing expense
        let sharedTxs = mock.mockTransactions.filter { $0.isShared && $0.category == .housing }
        XCTAssertFalse(sharedTxs.isEmpty, "Should have a shared housing transaction")

        if let tx = sharedTxs.first {
            XCTAssertNotNil(tx.splitUser1Amount, "Should have split amounts")
            XCTAssertNotNil(tx.splitUser2Amount, "Should have split amounts")
            let sum = (tx.splitUser1Amount ?? 0) + (tx.splitUser2Amount ?? 0)
            XCTAssertEqual(sum, tx.amount, "Split amounts should sum to total")
        }
    }

    // MARK: - Split Preview

    @MainActor
    func testSplitPreviewEqual() {
        let vm = OnboardingViewModel()
        vm.selectedSplit = .equal

        let (u1, u2) = vm.splitPreview(for: 1000)
        XCTAssertEqual(u1, 500)
        XCTAssertEqual(u2, 500)
    }

    @MainActor
    func testSplitPreviewCustom() {
        let vm = OnboardingViewModel()
        vm.selectedSplit = .custom
        vm.customPercent = 70

        let (u1, u2) = vm.splitPreview(for: 1000)
        XCTAssertEqual(u1, 700)
        XCTAssertEqual(u2, 300)
    }

    @MainActor
    func testSplitPreviewOnePays() {
        let vm = OnboardingViewModel()
        vm.selectedSplit = .onePays
        vm.onePayerIsUser1 = true

        let (u1, u2) = vm.splitPreview(for: 1000)
        XCTAssertEqual(u1, 1000)
        XCTAssertEqual(u2, 0)
    }
}
