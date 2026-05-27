import Foundation

@MainActor
@Observable
final class CalendarViewModel {

    // MARK: - State

    var selectedMonth = Date()
    var daySummaries: [DayFinancialSummary] = []
    var selectedDay: DayFinancialSummary?
    var isLoading = false
    var errorMessage: String?

    // MARK: - Computed

    var monthTitle: String {
        selectedMonth.formattedMonth.capitalizedFirst
    }

    var daysInMonth: Int {
        let cal = Calendar.current
        let range = cal.range(of: .day, in: .month, for: selectedMonth)
        return range?.count ?? 30
    }

    var firstWeekdayOffset: Int {
        let cal = Calendar.current
        let firstDay = selectedMonth.startOfMonth
        // Monday = 1, Sunday = 7 in ISO calendar
        let weekday = cal.component(.weekday, from: firstDay)
        // Convert to Monday-based: Mon=0, Tue=1, ... Sun=6
        return (weekday + 5) % 7
    }

    var totalExpensesThisMonth: Decimal {
        daySummaries.reduce(Decimal.zero) { $0 + $1.totalExpenses }
    }

    var totalIncomeThisMonth: Decimal {
        daySummaries.reduce(Decimal.zero) { $0 + $1.totalIncome }
    }

    var activeDaysCount: Int {
        daySummaries.filter { $0.transactionCount > 0 }.count
    }

    var highestSpendingDay: DayFinancialSummary? {
        daySummaries.max { $0.totalExpenses < $1.totalExpenses }
    }

    var mostCommonCategory: TransactionCategory? {
        var counts: [TransactionCategory: Int] = [:]
        for summary in daySummaries {
            for tx in summary.transactions where tx.type == .expense {
                counts[tx.category, default: 0] += 1
            }
        }
        return counts.max { $0.value < $1.value }?.key
    }

    // MARK: - Actions

    func loadMonth(coupleId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        daySummaries = MockDataService.shared.getDayFinancialSummaries(month: selectedMonth, coupleId: coupleId)
    }

    /// Carga el mes filtrando por usuario individual cuando isCoupleMode == false.
    /// En couple mode pasa nil y muestra los gastos de ambos.
    func loadMonth(coupleId: UUID, userId: UUID?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        daySummaries = MockDataService.shared.getDayFinancialSummaries(
            month: selectedMonth,
            coupleId: coupleId,
            userId: userId
        )
    }

    func changeMonth(by value: Int, coupleId: UUID) async {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newDate
            await loadMonth(coupleId: coupleId)
        }
    }

    /// Variante con userId opcional (para modo individual).
    func changeMonth(by value: Int, coupleId: UUID, userId: UUID?) async {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newDate
            await loadMonth(coupleId: coupleId, userId: userId)
        }
    }

    func selectDay(_ summary: DayFinancialSummary?) {
        if selectedDay?.id == summary?.id {
            selectedDay = nil
        } else {
            selectedDay = summary
        }
    }

    func summaryForDay(_ dayNumber: Int) -> DayFinancialSummary? {
        daySummaries.first { $0.dayNumber == dayNumber }
    }
}
