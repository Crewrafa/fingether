import Foundation

@MainActor
@Observable
final class DashboardViewModel {

    // MARK: - State

    var monthlySummary: MonthlySummary?
    var allTransactions: [Transaction] = []
    var recentTransactions: [Transaction] = []
    var budgetAlerts: [BudgetAlertResponse] = []
    var isLoading = false
    var errorMessage: String?
    var currentUserId: UUID?
    // NOTE: pet state se carga via PetService desde otros lugares (achievements, scoring).
    // El Dashboard ya no renderiza la mascota — code-pet en esta VM eliminado por dead code.

    // MARK: - Computed: Totals

    var totalIncome: Decimal { monthlySummary?.totalIncome ?? 0 }
    var totalExpenses: Decimal { monthlySummary?.totalExpenses ?? 0 }
    var balance: Decimal { monthlySummary?.netBalance ?? 0 }

    // MARK: - Computed: Individual vs Shared

    var myExpenses: Decimal {
        monthTransactions
            .filter { $0.type == .expense && $0.userId == currentUserId && !$0.isShared }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    var sharedExpenses: Decimal {
        monthTransactions
            .filter { $0.type == .expense && $0.isShared }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    var partnerExpenses: Decimal {
        monthTransactions
            .filter { $0.type == .expense && $0.userId != currentUserId && !$0.isShared }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    // MARK: - Computed: Fixed Expenses

    var fixedExpenses: [Transaction] {
        monthTransactions
            .filter { $0.type == .expense && $0.isRecurring }
            .sorted { $0.amount > $1.amount }
    }

    var fixedExpensesTotal: Decimal {
        fixedExpenses.reduce(Decimal.zero) { $0 + $1.amount }
    }

    // MARK: - Computed: Recent by scope

    var myRecentTransactions: [Transaction] {
        Array(allTransactions
            .filter { $0.userId == currentUserId && !$0.isShared }
            .sorted { $0.date > $1.date }
            .prefix(3))
    }

    var sharedRecentTransactions: [Transaction] {
        Array(allTransactions
            .filter { $0.isShared }
            .sorted { $0.date > $1.date }
            .prefix(3))
    }

    // MARK: - Computed: Top Savings Goal

    var topSavingsGoal: SavingsGoal? {
        MockDataService.shared.mockSavingsGoals
            .filter { $0.status == .active }
            .first
    }

    var activeSavingsGoalsCount: Int {
        MockDataService.shared.mockSavingsGoals
            .filter { $0.status == .active }
            .count
    }

    // MARK: - Computed: Top Expense Categories (for solo mode)

    var topExpenseCategories: [(category: TransactionCategory, amount: Decimal)] {
        let expenses = monthTransactions.filter { $0.type == .expense }
        var categoryTotals: [TransactionCategory: Decimal] = [:]
        for tx in expenses {
            categoryTotals[tx.category, default: 0] += tx.amount
        }
        return categoryTotals
            .map { (category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
            .prefix(3)
            .map { $0 }
    }

    // MARK: - Computed: Top Income Categories

    var topIncomeCategories: [(category: TransactionCategory, amount: Decimal)] {
        let income = monthTransactions.filter { $0.type == .income }
        var categoryTotals: [TransactionCategory: Decimal] = [:]
        for tx in income {
            categoryTotals[tx.category, default: 0] += tx.amount
        }
        return categoryTotals
            .map { (category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    // MARK: - Private

    private var monthTransactions: [Transaction] {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        return allTransactions.filter {
            let tc = cal.dateComponents([.year, .month], from: $0.date)
            return tc.year == comps.year && tc.month == comps.month
        }
    }

    // MARK: - Actions

    func loadDashboard(coupleId: UUID, userId: UUID) async {
        isLoading = true
        errorMessage = nil
        currentUserId = userId
        defer { isLoading = false }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                await self.loadMonthlySummary(coupleId: coupleId)
            }
            group.addTask { @MainActor in
                await self.loadAllTransactions(coupleId: coupleId)
            }
            group.addTask { @MainActor in
                await self.loadBudgetAlerts(coupleId: coupleId)
            }
        }
    }

    /// Loads dashboard data for solo users (no couple).
    func loadSoloDashboard(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        currentUserId = userId
        defer { isLoading = false }

        // For solo mode, load only user-specific data via mock
        allTransactions = MockDataService.shared.mockTransactions
            .filter { $0.userId == userId }
        recentTransactions = Array(allTransactions.sorted { $0.date > $1.date }.prefix(5))

        // Build a simple summary from local data
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        let monthTx = allTransactions.filter {
            let tc = cal.dateComponents([.year, .month], from: $0.date)
            return tc.year == comps.year && tc.month == comps.month
        }
        let income = monthTx.filter { $0.type == .income }.reduce(Decimal.zero) { $0 + $1.amount }
        let expenses = monthTx.filter { $0.type == .expense }.reduce(Decimal.zero) { $0 + $1.amount }
        // Build category breakdown
        var catBreakdown: [TransactionCategory: Decimal] = [:]
        for tx in monthTx where tx.type == .expense {
            catBreakdown[tx.category, default: 0] += tx.amount
        }
        let topCat = catBreakdown.max(by: { $0.value < $1.value })?.key

        monthlySummary = MonthlySummary(
            totalIncome: income,
            totalExpenses: expenses,
            netBalance: income - expenses,
            categoryBreakdown: catBreakdown,
            transactionCount: monthTx.count,
            topCategory: topCat
        )
    }

    // MARK: - Private Loaders

    private func loadMonthlySummary(coupleId: UUID) async {
        do {
            monthlySummary = try await DashboardService.getMonthlySummary(coupleId: coupleId, month: Date())
        } catch {
            monthlySummary = nil
        }
    }

    private func loadAllTransactions(coupleId: UUID) async {
        do {
            allTransactions = try await TransactionService.getTransactions(coupleId: coupleId, month: nil, category: nil, type: nil)
            recentTransactions = Array(allTransactions.sorted { $0.date > $1.date }.prefix(5))
        } catch {
            allTransactions = []
            recentTransactions = []
        }
    }

    private func loadBudgetAlerts(coupleId: UUID) async {
        do {
            budgetAlerts = try await BudgetService.checkBudgetAlerts(coupleId: coupleId)
        } catch {
            budgetAlerts = []
        }
    }
}
