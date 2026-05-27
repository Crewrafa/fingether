import XCTest
@testable import Spendly

final class TripIntegrationTests: XCTestCase {

    private let devUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let coupleUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!

    @MainActor
    override func setUp() {
        super.setUp()
        MockDataService.shared.seedClean()
        MockDataService.shared.isEnabled = true
        MockDataService.shared.completeOnboarding(displayName: "Test", monthlyIncome: 20000, currency: "MXN")
        MockDataService.shared.createPhantomPartner(name: "Partner", monthlyIncome: 15000, gender: "other")
    }

    // MARK: - Trip Budget = Sum Of Categories

    func testTripTotalBudgetIsSumOfCategories() {
        let categories = [
            TripBudgetCategory(id: UUID(), name: "Hospedaje", emoji: "🏨", budgetAmount: 5000, spentAmount: 0),
            TripBudgetCategory(id: UUID(), name: "Comida", emoji: "🍽️", budgetAmount: 3000, spentAmount: 0),
            TripBudgetCategory(id: UUID(), name: "Transporte", emoji: "🚕", budgetAmount: 2000, spentAmount: 0),
        ]

        let trip = Trip(
            id: UUID(), coupleId: coupleUUID,
            name: "Cancun", emoji: "🏖️", destination: "Cancun",
            startDate: Date(), endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            totalBudget: 10000, currency: "MXN", status: .planning,
            categories: categories, isShared: true,
            savingsMode: .monthly, monthlySavingsAmount: 2000,
            currentSaved: 0, linkedTransactionId: nil, createdAt: Date()
        )

        let categorySum = trip.categories.reduce(Decimal.zero) { $0 + $1.budgetAmount }
        XCTAssertEqual(categorySum, 10000, "Category budgets should sum to total budget")
    }

    // MARK: - TripViewModel Form Budget

    @MainActor
    func testTripViewModelFormBudgetSumsCategories() {
        let vm = TripViewModel()
        vm.formCategories = [
            TripBudgetCategory(id: UUID(), name: "Hospedaje", emoji: "🏨", budgetAmount: 8000, spentAmount: 0),
            TripBudgetCategory(id: UUID(), name: "Comida", emoji: "🍽️", budgetAmount: 4000, spentAmount: 0),
            TripBudgetCategory(id: UUID(), name: "Transporte", emoji: "🚕", budgetAmount: 3000, spentAmount: 0),
        ]

        XCTAssertEqual(vm.formTotalBudget, 15000, "formTotalBudget should sum all category budgets")
    }

    // MARK: - Create Trip With Monthly Savings Creates Linked Transaction

    @MainActor
    func testCreateTripWithMonthlySavingsCreatesTransaction() async {
        let vm = TripViewModel()
        vm.formName = "Viaje a Paris"
        vm.formDestination = "Paris"
        vm.formStartDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
        vm.formEndDate = Calendar.current.date(byAdding: .month, value: 7, to: Date())!
        vm.formSavingsMode = .monthly
        vm.formMonthlySavings = "3.000"
        vm.formIsShared = false

        // Set at least one category with budget
        vm.formCategories = [
            TripBudgetCategory(id: UUID(), name: "Hospedaje", emoji: "🏨", budgetAmount: 15000, spentAmount: 0),
        ]

        let mock = MockDataService.shared
        let txCountBefore = mock.mockTransactions.count

        await vm.createTrip(coupleId: coupleUUID)

        // A new recurring savings transaction should be created
        let txCountAfter = mock.mockTransactions.count
        XCTAssertGreaterThan(txCountAfter, txCountBefore, "Should have created a new transaction")

        let savingsTxs = mock.mockTransactions.filter {
            $0.category == .savings && $0.isRecurring && $0.description.contains("Viaje a Paris")
        }
        XCTAssertFalse(savingsTxs.isEmpty, "Should have a recurring savings transaction linked to the trip")
        XCTAssertEqual(savingsTxs.first?.amount, 3000)
    }

    // MARK: - Trip Created Successfully

    @MainActor
    func testTripIsAddedToTripsArray() async {
        let vm = TripViewModel()
        vm.formName = "Weekend Trip"
        vm.formDestination = "Monterrey"
        vm.formStartDate = Calendar.current.date(byAdding: .month, value: 2, to: Date())!
        vm.formEndDate = Calendar.current.date(byAdding: .month, value: 2, to: Calendar.current.date(byAdding: .day, value: 3, to: Date())!)!
        vm.formSavingsMode = .alreadyHave
        vm.formCategories = [
            TripBudgetCategory(id: UUID(), name: "Todo", emoji: "📦", budgetAmount: 5000, spentAmount: 0),
        ]

        await vm.createTrip(coupleId: coupleUUID)

        XCTAssertFalse(vm.trips.isEmpty, "Trip should be added to view model trips")
        XCTAssertEqual(vm.trips.first?.name, "Weekend Trip")
    }

    // MARK: - Shared Trip With Monthly Savings Gets Split

    @MainActor
    func testSharedTripSavingsGetSplitAmounts() async {
        let mock = MockDataService.shared
        mock.updateMockCoupleSettings(CoupleSettings(defaultSplitType: .equal, categorySplits: [:]))

        let vm = TripViewModel()
        vm.formName = "Playa del Carmen"
        vm.formDestination = "Playa del Carmen"
        vm.formStartDate = Calendar.current.date(byAdding: .month, value: 4, to: Date())!
        vm.formEndDate = Calendar.current.date(byAdding: .month, value: 5, to: Date())!
        vm.formSavingsMode = .monthly
        vm.formMonthlySavings = "4.000"
        vm.formIsShared = true
        vm.formCategories = [
            TripBudgetCategory(id: UUID(), name: "Hotel", emoji: "🏨", budgetAmount: 20000, spentAmount: 0),
        ]

        await vm.createTrip(coupleId: coupleUUID)

        let savingsTxs = mock.mockTransactions.filter {
            $0.category == .savings && $0.isRecurring && $0.isShared
        }
        XCTAssertFalse(savingsTxs.isEmpty, "Should have a shared recurring savings transaction")

        if let tx = savingsTxs.first {
            XCTAssertNotNil(tx.splitUser1Amount)
            XCTAssertNotNil(tx.splitUser2Amount)
            XCTAssertEqual(tx.splitUser1Amount, 2000, "Equal split of 4000 should be 2000 each")
            XCTAssertEqual(tx.splitUser2Amount, 2000)
        }
    }

    // MARK: - Trip Savings Progress

    func testTripSavingsProgress() {
        let trip = Trip(
            id: UUID(), coupleId: coupleUUID,
            name: "Test", emoji: "✈️", destination: "Test",
            startDate: Date(), endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            totalBudget: 10000, currency: "MXN", status: .planning,
            categories: [], isShared: false,
            savingsMode: .monthly, monthlySavingsAmount: 2000,
            currentSaved: 5000, linkedTransactionId: nil, createdAt: Date()
        )

        XCTAssertEqual(trip.savingsProgress, 0.5, accuracy: 0.01)
        XCTAssertFalse(trip.isFunded)
    }

    func testTripFullyFunded() {
        let trip = Trip(
            id: UUID(), coupleId: coupleUUID,
            name: "Test", emoji: "✈️", destination: "Test",
            startDate: Date(), endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            totalBudget: 10000, currency: "MXN", status: .planning,
            categories: [], isShared: false,
            savingsMode: .monthly, monthlySavingsAmount: 2000,
            currentSaved: 10000, linkedTransactionId: nil, createdAt: Date()
        )

        XCTAssertEqual(trip.savingsProgress, 1.0, accuracy: 0.01)
        XCTAssertTrue(trip.isFunded)
    }

    // MARK: - Months To Goal

    func testMonthsToGoalCalculation() {
        let trip = Trip(
            id: UUID(), coupleId: coupleUUID,
            name: "Test", emoji: "✈️", destination: "Test",
            startDate: Date(), endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            totalBudget: 10000, currency: "MXN", status: .planning,
            categories: [], isShared: false,
            savingsMode: .monthly, monthlySavingsAmount: 3000,
            currentSaved: 1000, linkedTransactionId: nil, createdAt: Date()
        )

        XCTAssertEqual(trip.monthsToGoal, 3, "9000 remaining / 3000 per month = 3 months")
    }

    func testMonthsToGoalWhenAlreadyFunded() {
        let trip = Trip(
            id: UUID(), coupleId: coupleUUID,
            name: "Test", emoji: "✈️", destination: "Test",
            startDate: Date(), endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            totalBudget: 10000, currency: "MXN", status: .planning,
            categories: [], isShared: false,
            savingsMode: .monthly, monthlySavingsAmount: 2000,
            currentSaved: 10000, linkedTransactionId: nil, createdAt: Date()
        )

        XCTAssertEqual(trip.monthsToGoal, 0)
    }

    // MARK: - AlreadyHave Mode Sets CurrentSaved To Budget

    @MainActor
    func testAlreadyHaveModeSetsCurrentSaved() async {
        let vm = TripViewModel()
        vm.formName = "Quick Trip"
        vm.formDestination = "Oaxaca"
        vm.formStartDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        vm.formEndDate = Calendar.current.date(byAdding: .month, value: 1, to: Calendar.current.date(byAdding: .day, value: 5, to: Date())!)!
        vm.formSavingsMode = .alreadyHave
        vm.formIsShared = false
        vm.formCategories = [
            TripBudgetCategory(id: UUID(), name: "Total", emoji: "📦", budgetAmount: 8000, spentAmount: 0),
        ]

        await vm.createTrip(coupleId: coupleUUID)

        let createdTrip = vm.trips.first
        XCTAssertNotNil(createdTrip)
        XCTAssertEqual(createdTrip?.currentSaved, createdTrip?.totalBudget,
                       "alreadyHave mode should set currentSaved equal to totalBudget")
    }

    // MARK: - Record Savings Payment

    @MainActor
    func testRecordSavingsPaymentIncreasesCurrentSaved() async {
        let vm = TripViewModel()
        vm.formName = "Test Trip"
        vm.formDestination = "Somewhere"
        vm.formStartDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
        vm.formEndDate = Calendar.current.date(byAdding: .month, value: 4, to: Date())!
        vm.formSavingsMode = .monthly
        vm.formMonthlySavings = "2.000"
        vm.formIsShared = false
        vm.formCategories = [
            TripBudgetCategory(id: UUID(), name: "Hotel", emoji: "🏨", budgetAmount: 6000, spentAmount: 0),
        ]

        await vm.createTrip(coupleId: coupleUUID)

        guard let tripId = vm.trips.first?.id else {
            XCTFail("Trip should have been created")
            return
        }

        let savedBefore = vm.trips.first?.currentSaved ?? 0
        vm.recordSavingsPayment(tripId: tripId, amount: 2000)
        let savedAfter = vm.trips.first?.currentSaved ?? 0

        XCTAssertEqual(savedAfter - savedBefore, 2000, "Should increase currentSaved by the payment amount")
    }

    // MARK: - Default Categories

    @MainActor
    func testDefaultCategoriesExist() {
        let cats = TripViewModel.defaultCategories()
        XCTAssertGreaterThanOrEqual(cats.count, 5, "Should have at least 5 default trip categories")
        XCTAssertTrue(cats.allSatisfy { $0.budgetAmount == 0 }, "Default categories should start with 0 budget")
        XCTAssertTrue(cats.allSatisfy { $0.spentAmount == 0 }, "Default categories should start with 0 spent")
    }
}
