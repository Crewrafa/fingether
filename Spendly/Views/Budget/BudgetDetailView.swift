import SwiftUI

struct BudgetDetailView: View {

    let budget: Budget
    let coupleId: UUID

    @State private var viewModel = TransactionViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                progressCard
                statsCards
                detailsCard
                transactionsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .trackCurrency()
        .navigationTitle(budget.category.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadTransactions(coupleId: coupleId)
            viewModel.selectedFilterCategory = budget.category
            viewModel.selectedFilterType = .expense
            viewModel.applyFilters()
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(hex: "E0E0E0"), lineWidth: 12)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: min(budget.usagePercentage.doubleValue, 1.0))
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring, value: budget.usagePercentage)

                VStack(spacing: 4) {
                    Text("\(Int(budget.usagePercentage.doubleValue * 100))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(ringColor)
                    Text("utilizado")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)

            if budget.isOverBudget {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.fingetherDanger)
                    Text("Presupuesto excedido por \(abs(budget.remainingAmount).currencyFormatted)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.fingetherDanger)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.fingetherDanger.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    // MARK: - Stats Cards

    private var statsCards: some View {
        HStack(spacing: 12) {
            statCard(title: "Gastado", value: budget.currentSpent.currencyFormatted, color: Color.fingetherDanger)
            statCard(title: "Limite", value: budget.amountLimit.currencyFormatted, color: Color.fingetherPrimaryDark)
            statCard(
                title: "Restante",
                value: budget.remainingAmount.currencyFormatted,
                color: budget.remainingAmount >= 0 ? Color.fingetherPrimary : Color.fingetherDanger
            )
        }
    }

    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Detalles", systemImage: "info.circle")
                .font(.headline)
                .foregroundStyle(Color(.label))

            HStack {
                Text("Periodo")
                    .foregroundStyle(Color(.label))
                Spacer()
                Label(budget.period.displayName, systemImage: budget.period.iconName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Text("Alerta al")
                    .foregroundStyle(Color(.label))
                Spacer()
                Text("\(Int(budget.alertThreshold.doubleValue * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Text("Estado")
                    .foregroundStyle(Color(.label))
                Spacer()
                Text(budget.isOverBudget ? "Excedido" : budget.isOverThreshold ? "Alerta" : "Dentro del limite")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(budget.isOverBudget ? Color.fingetherDanger : budget.isOverThreshold ? .orange : Color.fingetherPrimary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }

    // MARK: - Transactions Section

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transacciones")
                .font(.headline)
                .foregroundStyle(Color(.label))

            if viewModel.filteredTransactions.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "Sin gastos",
                    subtitle: "No hay transacciones en esta categoria para el periodo actual"
                )
                .padding(.vertical, 16)
            } else {
                ForEach(viewModel.filteredTransactions) { transaction in
                    TransactionRow(transaction: transaction)
                    if transaction.id != viewModel.filteredTransactions.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }

    // MARK: - Helpers

    private var ringColor: Color {
        let pct = budget.usagePercentage.doubleValue
        if pct >= 1.0 { return Color.fingetherDanger }
        if pct >= 0.8 { return .orange }
        return Color.fingetherPrimary
    }
}
