import SwiftUI

struct TripSummaryView: View {
    let trip: Trip
    let coupleId: UUID
    @Bindable var viewModel: TripViewModel

    @State private var preferences = AppPreferences.shared
    private var lang: AppLanguage { preferences.language }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                summaryHeader

                // Total vs Budget
                totalVsBudgetCard

                // Category breakdown
                categoryBreakdownCard

                // Who paid more
                whoPayedMoreCard

                // Top 3 expenses
                topExpensesCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .trackCurrency()
        .navigationTitle(L10n.t("trip_summary_nav", lang))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var summaryHeader: some View {
        VStack(spacing: 10) {
            Text(trip.emoji)
                .font(.system(size: 50))

            Text(trip.name)
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(trip.destination)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            Text("\(trip.startDate.formattedSpanishShort) - \(trip.endDate.formattedSpanishShort)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            let totalDays = max(Calendar.current.dateComponents([.day], from: trip.startDate, to: trip.endDate).day ?? 1, 1)
            Text("\(totalDays) \(L10n.t("trip_days", lang))")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(.white.opacity(0.2), in: Capsule())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.fingetherSky, Color(hex: "A29BFE")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.fingetherSky.opacity(0.3), radius: 12, y: 6)
    }

    // MARK: - Total vs Budget

    private var totalVsBudgetCard: some View {
        let underBudget = trip.totalSpent <= trip.totalBudget
        let savings = trip.totalBudget - trip.totalSpent

        return VStack(spacing: 16) {
            Text(L10n.t("trip_total_vs_budget", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.label))

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text(L10n.t("trip_spent", lang))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(trip.totalSpent.currencyFormatted)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.fingetherExpense)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text(L10n.t("trip_budget_label", lang))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(trip.totalBudget.currencyFormatted)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: .infinity)
            }

            // Result badge
            HStack(spacing: 6) {
                Image(systemName: underBudget ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                Text(underBudget
                     ? "\(L10n.t("trip_saved", lang)) \(savings.currencyFormatted)"
                     : "\(L10n.t("trip_exceeded", lang)) \(abs(savings).currencyFormatted)")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(underBudget ? Color.fingetherPrimary : Color.fingetherExpense)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                (underBudget ? Color.fingetherPrimary : Color.fingetherExpense).opacity(0.1),
                in: Capsule()
            )
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("trip_breakdown_category", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.label))

            ForEach(trip.categories.sorted(by: { $0.spentAmount > $1.spentAmount })) { cat in
                HStack(spacing: 10) {
                    Text(cat.emoji)
                        .font(.title3)

                    Text(cat.name)
                        .font(.subheadline)
                        .foregroundStyle(Color(.label))

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(cat.spentAmount.currencyFormatted)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color(.label))
                        if cat.budgetAmount > 0 {
                            Text("\(Int(cat.usagePercentage * 100))% \(L10n.t("trip_of_budget", lang))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if cat.id != trip.categories.sorted(by: { $0.spentAmount > $1.spentAmount }).last?.id {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Who Paid More

    private var whoPayedMoreCard: some View {
        let expenses = viewModel.expensesForTrip(trip.id)
        let mock = MockDataService.shared
        let userId = mock.getMockProfile().id
        let partnerId = mock.getMockPartnerProfile()?.id ?? UUID()

        let userTotal = expenses.filter { $0.userId == userId }.reduce(Decimal.zero) { $0 + $1.amount }
        let partnerTotal = expenses.filter { $0.userId == partnerId }.reduce(Decimal.zero) { $0 + $1.amount }

        let userName = mock.getMockProfile().displayName
        let partnerName = mock.getMockPartnerProfile()?.displayName ?? "Pareja"

        return VStack(spacing: 14) {
            Text(L10n.t("trip_who_paid_more", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.label))

            HStack(spacing: 20) {
                VStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundStyle(userTotal >= partnerTotal ? Color.fingetherPrimary : .secondary)
                    Text(userName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(.label))
                    Text(userTotal.currencyFormatted)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: .infinity)

                Text("vs")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundStyle(partnerTotal > userTotal ? Color.fingetherPrimary : .secondary)
                    Text(partnerName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(.label))
                    Text(partnerTotal.currencyFormatted)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: .infinity)
            }

            if userTotal != partnerTotal {
                let diff = abs(userTotal - partnerTotal)
                let winner = userTotal > partnerTotal ? userName : partnerName
                Text("\(winner) \(String(format: L10n.t("trip_paid_more", lang), diff.currencyFormatted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Top 3 Expenses

    private var topExpensesCard: some View {
        let expenses = viewModel.expensesForTrip(trip.id)
            .sorted { $0.amount > $1.amount }
            .prefix(3)

        return VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("trip_top_expenses", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.label))

            if expenses.isEmpty {
                Text(L10n.t("trip_no_expenses", lang))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(expenses.enumerated()), id: \.element.id) { index, expense in
                    let cat = trip.categories.first(where: { $0.id == expense.categoryId })
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(index == 0 ? Color.fingetherWarning : .secondary)
                            .frame(width: 28)

                        Text(cat?.emoji ?? "📦")
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(expense.merchant.isEmpty ? (cat?.name ?? "Gasto") : expense.merchant)
                                .font(.subheadline)
                                .foregroundStyle(Color(.label))
                            Text(expense.date.formattedSpanishShort)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(expense.amount.currencyFormatted)
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.fingetherExpense)
                    }

                    if index < expenses.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func abs(_ value: Decimal) -> Decimal {
        value < 0 ? -value : value
    }
}
