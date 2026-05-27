import SwiftUI

struct FinancialCalendarView: View {

    let coupleId: UUID

    @State private var viewModel = CalendarViewModel()
    @State private var preferences = AppPreferences.shared
    @State private var paywallFeature: PremiumFeature?  // P6
    private var lang: AppLanguage { preferences.language }
    private var isCoupleMode: Bool { preferences.isCoupleMode }

    /// User filter aplicado cuando isCoupleMode == false. nil = sin filtro (couple mode).
    private var activeUserFilter: UUID? {
        isCoupleMode ? nil : MockDataService.shared.currentUser1Id
    }

    private var isPremium: Bool {
        MockDataService.shared.mockProfile?.subscriptionTier == .premium
    }

    /// True si el usuario está viendo un mes anterior al actual y NO es premium.
    private var canGoToPreviousMonth: Bool {
        isPremium  // sólo premium puede navegar a meses anteriores
    }

    private let tealColor = Color.fingetherPrimary
    private let roseColor = Color.fingetherRose
    private var weekdays: [String] { L10n.t("calendar_weekdays", lang).components(separatedBy: ",") }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                monthSelector
                calendarGrid
                if let selected = viewModel.selectedDay {
                    dayDetailSection(selected)
                }
                insightsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(L10n.t("calendar_nav_title", lang))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadMonth(coupleId: coupleId, userId: activeUserFilter)
        }
        .paywallGate($paywallFeature)
    }

    // MARK: - Month Selector

    private var monthSelector: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    // P6: free tier solo puede ver mes actual. Mes anterior = premium.
                    if canGoToPreviousMonth {
                        Task { await viewModel.changeMonth(by: -1, coupleId: coupleId, userId: activeUserFilter) }
                    } else {
                        paywallFeature = .calendarHistory
                    }
                } label: {
                    Image(systemName: canGoToPreviousMonth ? "chevron.left" : "lock.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(tealColor)
                        .frame(width: 40, height: 40)
                        .background(tealColor.opacity(0.1))
                        .clipShape(Circle())
                }

                Spacer()

                Text(viewModel.monthTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(.label))
                    .contentTransition(.interpolate)

                Spacer()

                Button {
                    Task { await viewModel.changeMonth(by: 1, coupleId: coupleId, userId: activeUserFilter) }
                } label: {
                    let isCurrentMonth = Calendar.current.isDate(viewModel.selectedMonth, equalTo: Date(), toGranularity: .month)
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isCurrentMonth ? .secondary.opacity(0.3) : tealColor)
                        .frame(width: 40, height: 40)
                        .background(isCurrentMonth ? Color(.systemGray5) : tealColor.opacity(0.1))
                        .clipShape(Circle())
                }
            }

            if isCoupleMode {
                let mock = MockDataService.shared
                HStack(spacing: 6) {
                    Text("💕")
                        .font(.caption2)
                    Text("\(mock.currentUser1Name) & \(mock.currentUser2Name)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(.label))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(roseColor.opacity(0.18))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        VStack(spacing: 8) {
            // Weekday headers
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            LazyVGrid(columns: columns, spacing: 4) {
                // Empty cells for offset
                ForEach(0..<viewModel.firstWeekdayOffset, id: \.self) { _ in
                    Color.clear
                        .frame(height: 48)
                }

                // Day cells
                ForEach(1...viewModel.daysInMonth, id: \.self) { day in
                    let summary = viewModel.summaryForDay(day)
                    dayCell(day: day, summary: summary)
                }
            }

            // Legend
            legendRow
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func dayCell(day: Int, summary: DayFinancialSummary?) -> some View {
        let isSelected = viewModel.selectedDay?.dayNumber == day
        let heatLevel = summary?.heatLevel ?? .none
        let isToday = isCurrentDay(day)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectDay(summary)
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.system(size: 14, weight: isToday ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white : isToday ? tealColor : Color(.label))

                if let summary, summary.transactionCount > 0 {
                    Text("\(summary.transactionCount)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? tealColor : heatLevel.color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isToday ? tealColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: viewModel.selectedDay?.id)
    }

    private var legendRow: some View {
        HStack(spacing: 12) {
            ForEach([HeatLevel.none, .low, .medium, .high, .extreme], id: \.self) { level in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(level.color)
                        .frame(width: 12, height: 12)
                    Text(level.displayName)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Day Detail

    private func dayDetailSection(_ summary: DayFinancialSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("📅 \(summary.date.formattedSpanishLong)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    withAnimation { viewModel.selectedDay = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(L10n.t("calendar_income", lang))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(summary.totalIncome.currencyFormatted)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(tealColor)
                        .lineLimit(1).minimumScaleFactor(0.5)
                }

                VStack(spacing: 4) {
                    Text(L10n.t("calendar_expenses", lang))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(summary.totalExpenses.currencyFormatted)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.fingetherExpense)
                        .lineLimit(1).minimumScaleFactor(0.5)
                }

                VStack(spacing: 4) {
                    Text(L10n.t("calendar_transactions", lang))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(summary.transactionCount)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(.label))
                }
            }
            .frame(maxWidth: .infinity)

            if !summary.transactions.isEmpty {
                Divider()

                VStack(spacing: 0) {
                    ForEach(Array(summary.transactions.enumerated()), id: \.element.id) { index, tx in
                        HStack(spacing: 10) {
                            Text(tx.category.emoji)
                                .font(.body)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(tx.description)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color(.label))
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    Text(tx.category.displayName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    if isCoupleMode {
                                        payerBadge(for: tx)
                                    }
                                }
                            }

                            Spacer()

                            Text(tx.type == .income ? "+\(tx.amount.currencyFormatted)" : "-\(tx.amount.currencyFormatted)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(tx.type == .income ? Color.fingetherIncome : Color.fingetherExpense)
                                .lineLimit(1).minimumScaleFactor(0.5)
                        }
                        .padding(.vertical, 6)

                        if index < summary.transactions.count - 1 {
                            Divider().padding(.leading, 34)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.t("calendar_month_summary", lang))
                .font(.headline)

            VStack(spacing: 10) {
                insightRow(emoji: "💸", label: L10n.t("calendar_total_spent", lang), value: viewModel.totalExpensesThisMonth.currencyFormatted)
                insightRow(emoji: "💰", label: L10n.t("calendar_total_income", lang), value: viewModel.totalIncomeThisMonth.currencyFormatted)
                insightRow(emoji: "📅", label: L10n.t("calendar_active_days", lang), value: "\(viewModel.activeDaysCount) \(L10n.t("calendar_of", lang)) \(viewModel.daysInMonth)")

                if let highDay = viewModel.highestSpendingDay, highDay.totalExpenses > 0 {
                    insightRow(emoji: "🔥", label: L10n.t("calendar_highest_day", lang), value: "\(highDay.date.formattedSpanishShort) (\(highDay.totalExpenses.currencyFormatted))")
                }

                if let topCat = viewModel.mostCommonCategory {
                    insightRow(emoji: topCat.emoji, label: L10n.t("calendar_top_category", lang), value: topCat.displayName)
                }
            }

            // Patterns
            if viewModel.activeDaysCount > 0 {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("calendar_patterns", lang))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    let avgDaily = viewModel.totalExpensesThisMonth / Decimal(max(viewModel.activeDaysCount, 1))
                    patternItem(text: "\(L10n.t("calendar_avg_daily", lang)) \(avgDaily.currencyFormatted)")

                    let activeRatio = Double(viewModel.activeDaysCount) / Double(viewModel.daysInMonth)
                    if activeRatio < 0.3 {
                        patternItem(text: String(format: L10n.t("calendar_low_logging", lang), Int(activeRatio * 100)))
                    } else if activeRatio > 0.7 {
                        patternItem(text: String(format: L10n.t("calendar_high_logging", lang), Int(activeRatio * 100)))
                    }

                    let weekendDays = viewModel.daySummaries.filter { isWeekend($0.date) }
                    let weekendTotal = weekendDays.reduce(Decimal.zero) { $0 + $1.totalExpenses }
                    let weekdayTotal = viewModel.totalExpensesThisMonth - weekendTotal
                    if weekendTotal > 0 && weekdayTotal > 0 {
                        let weekendPct = Int(NSDecimalNumber(decimal: weekendTotal / viewModel.totalExpensesThisMonth * 100).doubleValue)
                        patternItem(text: String(format: L10n.t("calendar_weekend_pct", lang), weekendPct))
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func insightRow(emoji: String, label: String, value: String) -> some View {
        HStack {
            Text("\(emoji) \(label)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.label))
                .lineLimit(1).minimumScaleFactor(0.5)
        }
    }

    private func patternItem(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(tealColor)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            Text(text)
                .font(.caption)
                .foregroundStyle(Color(.label))
        }
    }

    // MARK: - Helpers

    private func isCurrentDay(_ day: Int) -> Bool {
        let cal = Calendar.current
        let now = Date()
        return cal.isDate(viewModel.selectedMonth, equalTo: now, toGranularity: .month) &&
               cal.component(.day, from: now) == day
    }

    private func isWeekend(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    // MARK: - Payer Badge (couple mode only)

    @ViewBuilder
    private func payerBadge(for tx: Transaction) -> some View {
        let mock = MockDataService.shared
        let isUser1 = tx.userId == mock.currentUser1Id
        let name = isUser1 ? mock.currentUser1Name : mock.currentUser2Name
        let color = isUser1 ? tealColor : roseColor

        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(name)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
            if tx.isShared {
                Text("· compartido")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
