import XCTest
@testable import Spendly

final class CreditSimulatorTests: XCTestCase {

    @MainActor
    func testMonthlyPaymentCalculation() {
        let vm = CreditSimulatorViewModel()
        vm.amountText = "10.000.000"
        vm.rateText = "28.5"
        vm.months = 36

        XCTAssertTrue(vm.monthlyPayment > 0, "Monthly payment should be positive")
        XCTAssertTrue(vm.totalPayment > vm.parsedAmount, "Total payment should exceed principal at positive rate")
        XCTAssertTrue(vm.totalInterest > 0, "Total interest should be positive")
    }

    @MainActor
    func testTotalPaymentEqualsMonthlyTimesMonths() {
        let vm = CreditSimulatorViewModel()
        vm.amountText = "5.000.000"
        vm.rateText = "20"
        vm.months = 24

        let expected = vm.monthlyPayment * Decimal(vm.months)
        XCTAssertEqual(vm.totalPayment, expected, "totalPayment should equal monthlyPayment * months")
    }

    @MainActor
    func testTotalInterestEqualsPaymentMinusPrincipal() {
        let vm = CreditSimulatorViewModel()
        vm.amountText = "8.000.000"
        vm.rateText = "15"
        vm.months = 48

        let expectedInterest = vm.totalPayment - vm.parsedAmount
        XCTAssertEqual(vm.totalInterest, expectedInterest)
    }

    // MARK: - Zero Rate

    @MainActor
    func testZeroRateGivesEvenPayments() {
        let vm = CreditSimulatorViewModel()
        vm.amountText = "1.200.000"
        vm.rateText = "0"
        vm.months = 12

        // When rate is 0, monthly payment = amount / months
        let expectedPayment = vm.parsedAmount / Decimal(vm.months)
        XCTAssertEqual(vm.monthlyPayment, expectedPayment, "Zero rate: payment should be principal / months")
        XCTAssertEqual(vm.totalInterest, 0, "Zero rate: total interest should be 0")
    }

    // MARK: - Amortization Table

    @MainActor
    func testAmortizationTableHasCorrectRowCount() {
        let vm = CreditSimulatorViewModel()
        vm.amountText = "5.000.000"
        vm.rateText = "24"
        vm.months = 36

        XCTAssertEqual(vm.amortizationTable.count, 36, "Table should have one row per month")
    }

    @MainActor
    func testAmortizationTableFinalBalanceNearZero() {
        let vm = CreditSimulatorViewModel()
        vm.amountText = "10.000.000"
        vm.rateText = "28.5"
        vm.months = 36

        let table = vm.amortizationTable
        guard let lastRow = table.last else {
            XCTFail("Amortization table should not be empty")
            return
        }

        let balanceDouble = NSDecimalNumber(decimal: lastRow.balance).doubleValue
        XCTAssertEqual(balanceDouble, 0, accuracy: 1.0, "Final balance should be approximately 0")
    }

    @MainActor
    func testAmortizationCapitalSumsToApproximatePrincipal() {
        let vm = CreditSimulatorViewModel()
        vm.amountText = "5.000.000"
        vm.rateText = "20"
        vm.months = 24

        let table = vm.amortizationTable
        let totalCapital = table.reduce(Decimal.zero) { $0 + $1.capital }
        let principalDouble = NSDecimalNumber(decimal: vm.parsedAmount).doubleValue
        let capitalDouble = NSDecimalNumber(decimal: totalCapital).doubleValue

        // Allow some rounding tolerance since values are rounded to Int
        XCTAssertEqual(capitalDouble, principalDouble, accuracy: Double(vm.months),
                       "Sum of capital payments should approximate the principal")
    }

    // MARK: - Edge Cases

    @MainActor
    func testZeroAmountProducesZeroPayment() {
        let vm = CreditSimulatorViewModel()
        vm.amountText = ""
        vm.amountSlider = 0
        vm.rateText = "28.5"
        vm.months = 36

        XCTAssertEqual(vm.parsedAmount, 0)
    }

    @MainActor
    func testZeroMonthsProducesZeroPayment() {
        let vm = CreditSimulatorViewModel()
        vm.amountText = "5.000.000"
        vm.rateText = "20"
        vm.months = 0

        XCTAssertEqual(vm.monthlyPayment, 0)
    }

    // MARK: - Comparisons

    @MainActor
    func testComparisonsContainsCurrentPlan() {
        let vm = CreditSimulatorViewModel()
        vm.amountText = "10.000.000"
        vm.rateText = "24"
        vm.months = 36

        let plans = vm.comparisons
        let currentPlan = plans.first(where: { $0.months == 36 })
        XCTAssertNotNil(currentPlan, "Comparisons should include the current plan's month count")
    }

    @MainActor
    func testShorterPlanPaysLessInterest() {
        let vm = CreditSimulatorViewModel()
        vm.amountText = "10.000.000"
        vm.rateText = "24"
        vm.months = 36

        let plans = vm.comparisons.sorted { $0.months < $1.months }
        guard plans.count >= 2 else {
            XCTFail("Should have at least 2 comparison plans")
            return
        }
        // Shorter plan should have less total interest
        XCTAssertTrue(plans.first!.totalInterest < plans.last!.totalInterest,
                       "Shorter plan should pay less total interest")
    }
}
