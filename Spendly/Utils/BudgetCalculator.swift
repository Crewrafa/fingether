import Foundation

// MARK: - Budget Calculation Result

/// The result of auto-calculating the couple/individual budget from real data.
/// No manual number needed — derived entirely from income, fixed expenses, and savings.
struct BudgetCalculation: Sendable {
    /// Total income (combined for couple, solo for individual).
    let totalIncome: Decimal
    /// Total fixed/recurring expenses (effective amounts considering splits + mode).
    let totalFixedExpenses: Decimal
    /// Monthly contributions to savings goals + trips with monthly savings.
    let totalSavingsContributions: Decimal
    /// Auto-calculated: income - fixed - savings. What's truly available.
    let calculatedAvailable: Decimal
    /// Optional user-chosen spending limit (nil = no limit, use available).
    let userLimit: Decimal?
    /// The effective budget: min(available, userLimit) or just available if no limit.
    let effectiveBudget: Decimal
    /// Variable expenses spent this month (not recurring, not income).
    let spentThisMonth: Decimal
    /// How much is left: effectiveBudget - spentThisMonth.
    let remaining: Decimal
    /// Percentage used: spentThisMonth / effectiveBudget * 100.
    let percentUsed: Double

    /// Zone for the progress bar.
    var zone: BudgetZone {
        switch percentUsed {
        case ..<60: return .good
        case 60..<80: return .attention
        case 80...100: return .warning
        default: return .exceeded
        }
    }

    /// True if user has set a custom limit below the calculated available.
    var hasCustomLimit: Bool { userLimit != nil }

    /// Monthly savings implied by the limit (available - limit).
    var impliedMonthlySavings: Decimal {
        guard let limit = userLimit else { return 0 }
        return max(0, calculatedAvailable - limit)
    }
}

// MARK: - Budget Zone

enum BudgetZone: Sendable {
    case good       // 0-60%
    case attention  // 60-80%
    case warning    // 80-100%
    case exceeded   // >100%
}

// MARK: - Budget Mode

enum BudgetMode: Sendable {
    case individual
    case couple
}

// MARK: - Budget Calculator

/// Calculates the smart budget from MockDataService data.
/// Reads income, recurring expenses (with split logic), savings contributions,
/// and current-month variable spending.
enum BudgetCalculator {

    static func calculate(for mode: BudgetMode) -> BudgetCalculation {
        let mock = MockDataService.shared
        let cal = Calendar.current
        let now = Date()

        // ── Income ──
        let totalIncome: Decimal
        switch mode {
        case .individual:
            totalIncome = mock.currentUser1Income
        case .couple:
            totalIncome = mock.currentCombinedIncome
        }

        // ── Fixed / recurring expenses (effective amounts per mode) ──
        let recurringExpenses = mock.mockTransactions.filter {
            $0.isRecurring && $0.type == .expense
        }
        var totalFixed: Decimal = 0
        for tx in recurringExpenses {
            switch mode {
            case .couple:
                totalFixed += tx.amount
            case .individual:
                if tx.isShared {
                    let split = mock.splitFor(amount: tx.amount, splitType: tx.splitType ?? mock.coupleSettings.defaultSplitType)
                    totalFixed += split.user1
                } else if tx.userId == mock.currentUser1Id {
                    totalFixed += tx.amount
                }
            }
        }

        // ── Savings contributions (monthly aportes to goals + trip savings) ──
        var savingsContrib: Decimal = 0
        // Trips with monthly savings
        for trip in mock.mockTrips where trip.savingsMode == .monthly && trip.monthlySavingsAmount > 0 {
            savingsContrib += trip.monthlySavingsAmount
        }

        // ── Auto-calculated available ──
        let available = max(0, totalIncome - totalFixed - savingsContrib)

        // ── User limit ──
        let limit: Decimal? = mock.budgetLimitEnabled ? mock.userBudgetLimit : nil
        let effective: Decimal
        if let lim = limit {
            effective = min(available, lim)
        } else {
            effective = available
        }

        // ── Variable spending this month (non-recurring expenses) ──
        let monthTxs = mock.mockTransactions.filter { tx in
            tx.type == .expense &&
            !tx.isRecurring &&
            cal.isDate(tx.date, equalTo: now, toGranularity: .month)
        }
        var spent: Decimal = 0
        for tx in monthTxs {
            switch mode {
            case .couple:
                spent += tx.amount
            case .individual:
                if tx.isShared {
                    let split = mock.splitFor(amount: tx.amount, splitType: tx.splitType ?? mock.coupleSettings.defaultSplitType)
                    spent += split.user1
                } else if tx.userId == mock.currentUser1Id {
                    spent += tx.amount
                }
            }
        }

        let remaining = effective - spent
        let pctUsed: Double = effective > 0
            ? NSDecimalNumber(decimal: spent / effective).doubleValue * 100
            : 0

        return BudgetCalculation(
            totalIncome: totalIncome,
            totalFixedExpenses: totalFixed,
            totalSavingsContributions: savingsContrib,
            calculatedAvailable: available,
            userLimit: limit,
            effectiveBudget: effective,
            spentThisMonth: spent,
            remaining: remaining,
            percentUsed: pctUsed
        )
    }

    // MARK: - Contextual Insight

    /// Returns a contextual insight string based on the budget state and day of month.
    static func contextualInsight(from calc: BudgetCalculation) -> (emoji: String, text: String)? {
        let dayOfMonth = Calendar.current.component(.day, from: Date())
        let daysInMonth = Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30

        if calc.effectiveBudget <= 0 { return nil }

        // First month without data
        if calc.spentThisMonth == 0 && dayOfMonth <= 5 {
            return ("📝", "Este es tu primer mes — registra tus gastos y tendrás mejor panorama")
        }

        // Exceeded limit but within available
        if let limit = calc.userLimit, calc.spentThisMonth > limit && calc.spentThisMonth <= calc.calculatedAvailable {
            let overBy = (calc.spentThisMonth - limit).currencyFormatted
            let remaining = (calc.calculatedAvailable - calc.spentThisMonth).currencyFormatted
            return ("📊", "Se pasaron del límite por \(overBy) pero aún tienen \(remaining) del disponible real")
        }

        // Exceeded budget entirely
        if calc.percentUsed > 100 {
            return ("⚠️", "Presupuesto superado — revisen gastos variables de este mes")
        }

        // Good pace — first half of month, under 50%
        if dayOfMonth <= daysInMonth / 2 && calc.percentUsed < 50 {
            return ("🎯", "Van bien — llevan \(Int(calc.percentUsed))% del presupuesto a mitad de mes")
        }

        // Spending fast — over 70% before day 20
        if dayOfMonth < 20 && calc.percentUsed > 70 {
            let daysLeft = daysInMonth - dayOfMonth
            return ("⚡", "Ojo — llevan \(Int(calc.percentUsed))% del presupuesto y faltan \(daysLeft) días")
        }

        // Excellent — under 30% past day 15
        if dayOfMonth > 15 && calc.percentUsed < 30 {
            let extra = calc.remaining.currencyFormatted
            return ("🌟", "Excelente control — podrían ahorrar \(extra) extra este mes")
        }

        return nil
    }
}
