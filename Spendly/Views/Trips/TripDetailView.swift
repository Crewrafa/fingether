import SwiftUI

struct TripDetailView: View {
    let trip: Trip
    let coupleId: UUID
    @Bindable var viewModel: TripViewModel

    @State private var showExpenseForm = false
    @State private var preferences = AppPreferences.shared
    private var lang: AppLanguage { preferences.language }

    private var currentTrip: Trip {
        viewModel.trips.first(where: { $0.id == trip.id }) ?? trip
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    budgetProgressSection
                    categoriesBreakdown
                    dailyAverageCard
                    recentExpensesSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())

            // FAB for adding expense
            if currentTrip.status == .active {
                Button {
                    showExpenseForm = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.headline.bold())
                        Text(L10n.t("trip_expense_btn", lang))
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.fingetherExpense, in: Capsule())
                    .shadow(color: Color.fingetherExpense.opacity(0.4), radius: 10, y: 5)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .trackCurrency()
        .navigationTitle(currentTrip.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if currentTrip.status == .active {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task { await viewModel.completeTrip(tripId: trip.id) }
                        } label: {
                            Label(L10n.t("trip_end_trip", lang), systemImage: "checkmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Color.fingetherPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showExpenseForm) {
            TripExpenseFormView(trip: currentTrip, viewModel: viewModel)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 8) {
            Text(currentTrip.emoji)
                .font(.system(size: 50))

            Text(currentTrip.name)
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(currentTrip.destination)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            if currentTrip.status == .active {
                Text(dayLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2), in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.fingetherPrimary, Color.fingetherPrimaryDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.fingetherPrimary.opacity(0.3), radius: 12, y: 6)
    }

    // MARK: - Budget Progress

    private var budgetProgressSection: some View {
        let usage = budgetUsage
        return VStack(spacing: 12) {
            HStack {
                Text(L10n.t("trip_budget", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.label))
                Spacer()
                Text("\(Int(usage * 100))%")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(budgetColor(usage))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGroupedBackground))
                        .frame(height: 20)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(budgetColor(usage))
                        .frame(width: max(CGFloat(usage) * geo.size.width, 4), height: 20)
                }
            }
            .frame(height: 20)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("trip_spent", lang))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(currentTrip.totalSpent.currencyFormatted)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.fingetherExpense)
                }
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text(L10n.t("trip_remaining", lang))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(currentTrip.remainingBudget.currencyFormatted)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.fingetherPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(L10n.t("trip_total", lang))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(currentTrip.totalBudget.currencyFormatted)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color(.label))
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Categories Breakdown

    private var categoriesBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("trip_by_category", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.label))

            ForEach(currentTrip.categories) { cat in
                HStack(spacing: 10) {
                    Text(cat.emoji)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(cat.name)
                                .font(.subheadline)
                                .foregroundStyle(Color(.label))
                            Spacer()
                            Text("\(cat.spentAmount.currencyFormatted) / \(cat.budgetAmount.currencyFormatted)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGroupedBackground))
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(categoryBarColor(cat.usagePercentage))
                                    .frame(width: max(CGFloat(cat.usagePercentage) * geo.size.width, 2), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Daily Average

    private var dailyAverageCard: some View {
        let totalDays = max(Calendar.current.dateComponents([.day], from: currentTrip.startDate, to: currentTrip.endDate).day ?? 1, 1)
        let elapsed = max(Calendar.current.dateComponents([.day], from: currentTrip.startDate, to: Date()).day ?? 1, 1)
        let actualDaily = currentTrip.totalSpent.doubleValue / Double(elapsed)
        let idealDaily = currentTrip.totalBudget.doubleValue / Double(totalDays)
        let isOverBudget = actualDaily > idealDaily

        return HStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(L10n.t("trip_daily_avg", lang))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(actualDaily.currencyFormatted)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(isOverBudget ? Color.fingetherExpense : Color.fingetherPrimary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 4) {
                Text(L10n.t("trip_ideal_daily", lang))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(idealDaily.currencyFormatted)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Color(.label))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Recent Expenses

    private var recentExpensesSection: some View {
        let expenses = viewModel.expensesForTrip(trip.id)
        return VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("trip_recent_expenses", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.label))

            if expenses.isEmpty {
                Text(L10n.t("trip_no_expenses", lang))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(expenses.prefix(10)) { expense in
                    expenseRow(expense)
                    if expense.id != expenses.prefix(10).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func expenseRow(_ expense: TripExpense) -> some View {
        let category = currentTrip.categories.first(where: { $0.id == expense.categoryId })
        return HStack(spacing: 10) {
            Text(category?.emoji ?? "📦")
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.merchant.isEmpty ? (category?.name ?? "Gasto") : expense.merchant)
                    .font(.subheadline)
                    .foregroundStyle(Color(.label))
                Text(expense.date.formattedSpanishShort)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(expense.amount.currencyFormatted)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.fingetherExpense)
        }
    }

    // MARK: - Helpers

    private var dayLabel: String {
        let totalDays = max(Calendar.current.dateComponents([.day], from: currentTrip.startDate, to: currentTrip.endDate).day ?? 1, 1)
        let elapsed = Calendar.current.dateComponents([.day], from: currentTrip.startDate, to: Date()).day ?? 0
        let currentDay = min(max(elapsed + 1, 1), totalDays)
        return String(format: L10n.t("trip_day_of", lang), currentDay, totalDays)
    }

    private var budgetUsage: Double {
        guard currentTrip.totalBudget > 0 else { return 0 }
        return min(currentTrip.totalSpent.doubleValue / currentTrip.totalBudget.doubleValue, 1.0)
    }

    private func budgetColor(_ usage: Double) -> Color {
        if usage >= 0.9 { return Color.fingetherExpense }
        if usage >= 0.7 { return Color.fingetherWarning }
        return Color.fingetherPrimary
    }

    private func categoryBarColor(_ usage: Double) -> Color {
        if usage >= 0.9 { return Color.fingetherExpense }
        if usage >= 0.7 { return Color.fingetherWarning }
        return Color.fingetherPrimary
    }
}
