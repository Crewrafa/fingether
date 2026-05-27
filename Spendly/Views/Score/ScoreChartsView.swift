import SwiftUI
import Charts

// MARK: - Score Charts View

/// Vista con 5 graficos financieros basados en las transacciones del casal.
struct ScoreChartsView: View {

    let coupleId: UUID
    let userId: UUID

    @State private var mockData = MockDataService.shared
    @State private var preferences = AppPreferences.shared
    private var lang: AppLanguage { preferences.language }

    // MARK: - Design Tokens

    private let tealColor = Color.fingetherPrimary
    private let expenseColor = Color.fingetherExpense
    private let warningColor = Color.fingetherWarning
    private let purpleIndividual = Color.fingetherSky
    private let purpleShared = Color.fingetherRose

    private let categoryPalette: [Color] = [
        Color.fingetherPrimary,
        Color.fingetherExpense,
        Color.fingetherSky,
        Color.fingetherWarning,
        Color(hex: "0984E3"),
        Color.fingetherRose,
    ]

    // MARK: - Computed Data

    private var allTransactions: [Transaction] {
        mockData.mockTransactions
    }

    private var currentMonthExpenses: [Transaction] {
        let now = Date()
        let startOfMonth = now.startOfMonth
        return allTransactions.filter { tx in
            tx.type == .expense &&
            tx.date >= startOfMonth &&
            tx.date <= now
        }
    }

    private var currentMonthIncome: [Transaction] {
        let now = Date()
        let startOfMonth = now.startOfMonth
        return allTransactions.filter { tx in
            tx.type == .income &&
            tx.date >= startOfMonth &&
            tx.date <= now
        }
    }

    private var totalMonthlyBudget: Decimal {
        let budgets = mockData.mockBudgets.filter { $0.isActive && $0.period == .monthly }
        guard !budgets.isEmpty else {
            let totalIncome = currentMonthIncome.reduce(Decimal.zero) { $0 + $1.amount }
            return totalIncome
        }
        return budgets.reduce(Decimal.zero) { $0 + $1.amountLimit }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            if allTransactions.isEmpty {
                emptyStateView
            } else {
                categoryDonutChart
                weeklyBarChart
                monthlyTrendChart
                individualVsCoupleChart
                topMerchantsChart
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        chartCard {
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 44))
                    .foregroundStyle(tealColor.opacity(0.5))

                Text(L10n.t("charts_no_data", lang))
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(L10n.t("charts_add_transactions", lang))
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 24)
        }
    }

    // MARK: - Chart 1: Distribucion de gastos por categoria (Donut)

    private var categoryDonutChart: some View {
        chartCard {
            VStack(alignment: .leading, spacing: 12) {
                chartTitle(
                    title: L10n.t("charts_expense_dist", lang),
                    subtitle: L10n.t("charts_by_category", lang)
                )

                if currentMonthExpenses.isEmpty {
                    noDataPlaceholder(message: L10n.t("charts_no_expenses", lang))
                } else {
                    let grouped = categoryGroupedData
                    Chart(grouped, id: \.category) { item in
                        SectorMark(
                            angle: .value("Monto", item.amount.doubleValue),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(item.color)
                        .cornerRadius(4)
                    }
                    .frame(height: 200)

                    // Legend
                    VStack(spacing: 8) {
                        ForEach(grouped, id: \.category) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 10, height: 10)

                                Text(item.emoji)
                                    .font(.caption)

                                Text(item.displayName)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text(item.amount.currencyFormatted)
                                    .font(.subheadline)
                                    .fontDesign(.rounded)
                                    .foregroundStyle(.primary)

                                Text(formatPercent(item.percentage))
                                    .font(.caption)
                                    .fontDesign(.rounded)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
    }

    private var categoryGroupedData: [CategorySlice] {
        var totals: [TransactionCategory: Decimal] = [:]
        for tx in currentMonthExpenses {
            totals[tx.category, default: 0] += tx.amount
        }

        let sorted = totals.sorted { $0.value > $1.value }
        let grandTotal = sorted.reduce(Decimal.zero) { $0 + $1.value }
        guard grandTotal > 0 else { return [] }

        var slices: [CategorySlice] = []
        var othersTotal: Decimal = 0

        for (index, pair) in sorted.enumerated() {
            if index < 5 {
                let pct = (pair.value / grandTotal * 100)
                slices.append(CategorySlice(
                    category: pair.key.rawValue,
                    displayName: pair.key.displayName,
                    emoji: pair.key.emoji,
                    amount: pair.value,
                    percentage: pct,
                    color: categoryPalette[index % categoryPalette.count]
                ))
            } else {
                othersTotal += pair.value
            }
        }

        if othersTotal > 0 {
            let pct = (othersTotal / grandTotal * 100)
            slices.append(CategorySlice(
                category: "otros",
                displayName: L10n.t("charts_others", lang),
                emoji: "📌",
                amount: othersTotal,
                percentage: pct,
                color: Color(.systemGray3)
            ))
        }

        return slices
    }

    // MARK: - Chart 2: Gastos por semana del mes (Bar)

    private var weeklyBarChart: some View {
        chartCard {
            VStack(alignment: .leading, spacing: 12) {
                chartTitle(
                    title: L10n.t("charts_weekly", lang),
                    subtitle: L10n.t("charts_weekly_subtitle", lang)
                )

                if currentMonthExpenses.isEmpty {
                    noDataPlaceholder(message: L10n.t("charts_no_expenses", lang))
                } else {
                    let weeklyData = weeklyGroupedData
                    let idealWeekly = (totalMonthlyBudget / 4).doubleValue

                    Chart {
                        ForEach(weeklyData, id: \.weekLabel) { item in
                            BarMark(
                                x: .value("Semana", item.weekLabel),
                                y: .value("Monto", item.total.doubleValue)
                            )
                            .foregroundStyle(item.total.doubleValue > idealWeekly ? expenseColor : tealColor)
                            .cornerRadius(6)
                        }

                        RuleMark(y: .value("Ideal", idealWeekly))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .foregroundStyle(warningColor)
                            .annotation(position: .top, alignment: .trailing) {
                                Text(L10n.t("charts_ideal", lang))
                                    .font(.caption2)
                                    .fontDesign(.rounded)
                                    .foregroundStyle(warningColor)
                            }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let dbl = value.as(Double.self) {
                                    Text(dbl.currencyCompact)
                                        .font(.caption2)
                                        .fontDesign(.rounded)
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                }
            }
        }
    }

    private var weeklyGroupedData: [WeeklySlice] {
        let calendar = Calendar.current
        let startOfMonth = Date().startOfMonth

        var weeks: [Int: Decimal] = [:]

        for tx in currentMonthExpenses {
            let dayOfMonth = calendar.component(.day, from: tx.date)
            let weekIndex = min((dayOfMonth - 1) / 7, 4)
            weeks[weekIndex, default: 0] += tx.amount
        }

        let numberOfWeeks = max(calendar.range(of: .weekOfMonth, in: .month, for: startOfMonth)?.count ?? 4, 4)
        let weeksToShow = min(numberOfWeeks, 5)

        return (0..<weeksToShow).map { i in
            WeeklySlice(
                weekLabel: "\(L10n.t("charts_week_abbr", lang)) \(i + 1)",
                total: weeks[i, default: 0]
            )
        }
    }

    // MARK: - Chart 3: Tendencia mensual (Line)

    private var monthlyTrendChart: some View {
        chartCard {
            VStack(alignment: .leading, spacing: 12) {
                chartTitle(
                    title: L10n.t("charts_monthly_trend", lang),
                    subtitle: L10n.t("charts_income_vs_expenses", lang)
                )

                let trendData = monthlyTrendData

                if trendData.isEmpty {
                    noDataPlaceholder(message: L10n.t("charts_no_historical", lang))
                } else if trendData.count == 1 {
                    // Solo 1 mes de datos: mostrar por semana
                    weeklyTrendFallbackChart
                } else {
                    Chart {
                        ForEach(trendData, id: \.monthLabel) { item in
                            LineMark(
                                x: .value("Mes", item.monthLabel),
                                y: .value("Ingreso", item.income.doubleValue)
                            )
                            .foregroundStyle(tealColor)
                            .symbol(Circle())
                            .interpolationMethod(.catmullRom)

                            LineMark(
                                x: .value("Mes", item.monthLabel),
                                y: .value("Gasto", item.expenses.doubleValue)
                            )
                            .foregroundStyle(expenseColor)
                            .symbol(Circle())
                            .interpolationMethod(.catmullRom)

                            // Shaded area for savings (income - expenses when positive)
                            if item.income > item.expenses {
                                AreaMark(
                                    x: .value("Mes", item.monthLabel),
                                    yStart: .value("Gasto", item.expenses.doubleValue),
                                    yEnd: .value("Ingreso", item.income.doubleValue)
                                )
                                .foregroundStyle(tealColor.opacity(0.12))
                                .interpolationMethod(.catmullRom)
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let dbl = value.as(Double.self) {
                                    Text(dbl.currencyCompact)
                                        .font(.caption2)
                                        .fontDesign(.rounded)
                                }
                            }
                        }
                    }
                    .frame(height: 200)

                    // Legend
                    HStack(spacing: 16) {
                        legendDot(color: tealColor, label: L10n.t("charts_income_label", lang))
                        legendDot(color: expenseColor, label: L10n.t("charts_expense_label", lang))
                        legendDot(color: tealColor.opacity(0.3), label: L10n.t("charts_savings_label", lang))
                    }
                    .font(.caption)
                }
            }
        }
    }

    private var weeklyTrendFallbackChart: some View {
        let weeklyIncome = weeklyIncomeAndExpenseData
        return Chart {
            ForEach(weeklyIncome, id: \.weekLabel) { item in
                LineMark(
                    x: .value("Semana", item.weekLabel),
                    y: .value("Ingreso", item.income.doubleValue)
                )
                .foregroundStyle(tealColor)
                .symbol(Circle())

                LineMark(
                    x: .value("Semana", item.weekLabel),
                    y: .value("Gasto", item.expenses.doubleValue)
                )
                .foregroundStyle(expenseColor)
                .symbol(Circle())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let dbl = value.as(Double.self) {
                        Text(dbl.currencyCompact)
                            .font(.caption2)
                            .fontDesign(.rounded)
                    }
                }
            }
        }
        .frame(height: 200)
    }

    private var weeklyIncomeAndExpenseData: [WeeklyTrendSlice] {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = now.startOfMonth

        let thisMonthTx = allTransactions.filter { $0.date >= startOfMonth && $0.date <= now }

        var incomeByWeek: [Int: Decimal] = [:]
        var expenseByWeek: [Int: Decimal] = [:]

        for tx in thisMonthTx {
            let dayOfMonth = calendar.component(.day, from: tx.date)
            let weekIndex = min((dayOfMonth - 1) / 7, 4)
            if tx.type == .income {
                incomeByWeek[weekIndex, default: 0] += tx.amount
            } else {
                expenseByWeek[weekIndex, default: 0] += tx.amount
            }
        }

        return (0..<4).map { i in
            WeeklyTrendSlice(
                weekLabel: "\(L10n.t("charts_week_abbr", lang)) \(i + 1)",
                income: incomeByWeek[i, default: 0],
                expenses: expenseByWeek[i, default: 0]
            )
        }
    }

    private var monthlyTrendData: [MonthlyTrendSlice] {
        let calendar = Calendar.current
        let now = Date()

        // Group all transactions by year-month
        var incomeByMonth: [String: Decimal] = [:]
        var expenseByMonth: [String: Decimal] = [:]
        var monthOrder: [String] = []

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = "MMM yy"

        // Collect last 6 months
        for monthsBack in (0..<6).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthsBack, to: now) else { continue }
            let key = formatter.string(from: monthDate)
            let monthStart = monthDate.startOfMonth
            guard let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) else { continue }

            let monthTx = allTransactions.filter { $0.date >= monthStart && $0.date < nextMonthStart }
            guard !monthTx.isEmpty else { continue }

            let inc = monthTx.filter { $0.type == .income }.reduce(Decimal.zero) { $0 + $1.amount }
            let exp = monthTx.filter { $0.type == .expense }.reduce(Decimal.zero) { $0 + $1.amount }

            incomeByMonth[key] = inc
            expenseByMonth[key] = exp
            if !monthOrder.contains(key) {
                monthOrder.append(key)
            }
        }

        return monthOrder.map { key in
            MonthlyTrendSlice(
                monthLabel: key,
                income: incomeByMonth[key, default: 0],
                expenses: expenseByMonth[key, default: 0]
            )
        }
    }

    // MARK: - Chart 4: Individual vs Pareja (Stacked bar)

    private var individualVsCoupleChart: some View {
        chartCard {
            VStack(alignment: .leading, spacing: 12) {
                chartTitle(
                    title: L10n.t("charts_individual_vs_couple", lang),
                    subtitle: L10n.t("charts_expense_dist_subtitle", lang)
                )

                if currentMonthExpenses.isEmpty {
                    noDataPlaceholder(message: L10n.t("charts_no_expenses", lang))
                } else {
                    let data = individualVsCoupleData

                    Chart(data, id: \.label) { item in
                        BarMark(
                            x: .value("Monto", item.amount.doubleValue),
                            y: .value("Tipo", "Gastos")
                        )
                        .foregroundStyle(item.color)
                        .cornerRadius(6)
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let dbl = value.as(Double.self) {
                                    Text(dbl.currencyCompact)
                                        .font(.caption2)
                                        .fontDesign(.rounded)
                                }
                            }
                        }
                    }
                    .chartYAxis(.hidden)
                    .chartPlotStyle { plot in
                        plot.frame(height: 50)
                    }
                    .frame(height: 70)

                    // Percentage labels
                    let total = data.reduce(Decimal.zero) { $0 + $1.amount }
                    if total > 0 {
                        HStack(spacing: 16) {
                            ForEach(data, id: \.label) { item in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(item.color)
                                        .frame(width: 10, height: 10)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.label)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        HStack(spacing: 4) {
                                            Text(item.amount.currencyFormatted)
                                                .font(.subheadline)
                                                .fontDesign(.rounded)
                                                .fontWeight(.medium)

                                            Text(formatPercent(item.amount / total * 100))
                                                .font(.caption2)
                                                .fontDesign(.rounded)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private var individualVsCoupleData: [SegmentSlice] {
        var personalTotal: Decimal = 0
        var sharedTotal: Decimal = 0

        for tx in currentMonthExpenses {
            if tx.isShared {
                // Use effective amount (split amount for the user)
                let effectiveAmount = effectiveAmountForUser(tx)
                sharedTotal += effectiveAmount
            } else if tx.userId == userId {
                personalTotal += tx.amount
            }
        }

        var segments: [SegmentSlice] = []
        if personalTotal > 0 {
            segments.append(SegmentSlice(label: L10n.t("charts_personal", lang), amount: personalTotal, color: purpleIndividual))
        }
        if sharedTotal > 0 {
            segments.append(SegmentSlice(label: L10n.t("charts_shared", lang), amount: sharedTotal, color: purpleShared))
        }

        // If nothing matched (e.g., all expenses are partner's personal), show total
        if segments.isEmpty {
            let total = currentMonthExpenses.reduce(Decimal.zero) { $0 + $1.amount }
            if total > 0 {
                segments.append(SegmentSlice(label: L10n.t("charts_total_expenses", lang), amount: total, color: tealColor))
            }
        }

        return segments
    }

    private func effectiveAmountForUser(_ tx: Transaction) -> Decimal {
        guard tx.isShared else { return tx.amount }

        switch tx.splitType {
        case .equal:
            return tx.amount / 2
        case .proportional:
            return tx.amount / 2
        case .custom(let pct):
            if tx.userId == userId {
                return tx.amount * Decimal(pct) / 100
            } else {
                return tx.amount * Decimal(100 - pct) / 100
            }
        case .onePays(let payerId):
            return payerId == userId ? tx.amount : 0
        case .none:
            return tx.amount / 2
        }
    }

    // MARK: - Chart 5: Top 5 comercios (Horizontal bars)

    private var topMerchantsChart: some View {
        chartCard {
            VStack(alignment: .leading, spacing: 12) {
                chartTitle(
                    title: L10n.t("charts_top_merchants", lang),
                    subtitle: L10n.t("charts_top_merchants_subtitle", lang)
                )

                if currentMonthExpenses.isEmpty {
                    noDataPlaceholder(message: L10n.t("charts_no_expenses", lang))
                } else {
                    let merchantData = topMerchantsData

                    if merchantData.isEmpty {
                        noDataPlaceholder(message: L10n.t("charts_no_merchants", lang))
                    } else {
                        Chart(merchantData, id: \.merchant) { item in
                            BarMark(
                                x: .value("Monto", item.amount.doubleValue),
                                y: .value("Comercio", item.merchant)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [tealColor, tealColor.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(6)
                            .annotation(position: .trailing, spacing: 4) {
                                Text(item.amount.currencyFormatted)
                                    .font(.caption2)
                                    .fontDesign(.rounded)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis {
                            AxisMarks { value in
                                AxisValueLabel {
                                    if let name = value.as(String.self) {
                                        Text(name)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                    }
                                }
                            }
                        }
                        .chartPlotStyle { plot in
                            plot.frame(height: CGFloat(merchantData.count) * 44)
                        }
                        .frame(height: CGFloat(merchantData.count) * 44 + 20)
                    }
                }
            }
        }
    }

    private var topMerchantsData: [MerchantSlice] {
        var totals: [String: Decimal] = [:]

        for tx in currentMonthExpenses {
            let name = tx.description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            totals[name, default: 0] += tx.amount
        }

        let sorted = totals.sorted { $0.value > $1.value }
        return Array(sorted.prefix(5)).map { pair in
            MerchantSlice(merchant: pair.key, amount: pair.value)
        }
    }

    // MARK: - Reusable Components

    private func chartCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private func chartTitle(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func noDataPlaceholder(message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 32)
            Spacer()
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    private func formatPercent(_ value: Decimal) -> String {
        let dbl = NSDecimalNumber(decimal: value).doubleValue
        return String(format: "%.1f%%", dbl)
    }
}

// MARK: - Data Models

private struct CategorySlice {
    let category: String
    let displayName: String
    let emoji: String
    let amount: Decimal
    let percentage: Decimal
    let color: Color
}

private struct WeeklySlice {
    let weekLabel: String
    let total: Decimal
}

private struct MonthlyTrendSlice {
    let monthLabel: String
    let income: Decimal
    let expenses: Decimal
}

private struct WeeklyTrendSlice {
    let weekLabel: String
    let income: Decimal
    let expenses: Decimal
}

private struct SegmentSlice {
    let label: String
    let amount: Decimal
    let color: Color
}

private struct MerchantSlice {
    let merchant: String
    let amount: Decimal
}

// MARK: - Preview

#Preview {
    ScrollView {
        ScoreChartsView(
            coupleId: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            userId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )
        .padding(.horizontal, 16)
    }
    .background(Color(.systemGroupedBackground))
}
