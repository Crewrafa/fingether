import SwiftUI

struct BudgetListView: View {

    let coupleId: UUID

    @State private var viewModel = BudgetViewModel()
    @State private var showAddBudget = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.budgets.isEmpty {
                    LoadingView()
                } else if viewModel.budgets.isEmpty {
                    EmptyStateView(
                        icon: "chart.pie",
                        title: "Sin presupuestos",
                        subtitle: "Crea un presupuesto para controlar tus gastos por categoria",
                        actionTitle: "Crear Presupuesto",
                        action: { showAddBudget = true }
                    )
                } else {
                    budgetList
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .trackCurrency()
            .navigationTitle("Presupuestos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddBudget = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.fingetherPrimary)
                    }
                }
            }
            .sheet(isPresented: $showAddBudget, onDismiss: {
                Task { await viewModel.loadBudgets(coupleId: coupleId) }
            }) {
                AddBudgetView(coupleId: coupleId)
            }
            .refreshable {
                await viewModel.loadBudgets(coupleId: coupleId)
            }
            .task {
                await viewModel.loadBudgets(coupleId: coupleId)
            }
        }
    }

    private var budgetList: some View {
        List {
            if !viewModel.budgetAlerts.isEmpty {
                Section("Alertas") {
                    ForEach(viewModel.budgetAlerts) { alert in
                        let isOver = alert.percentageUsed >= 1
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(isOver ? Color.fingetherDanger : .orange)
                            Text("\(alert.category.displayName): \(Int(truncating: (alert.percentageUsed * 100) as NSDecimalNumber))% usado")
                                .font(.subheadline)
                                .foregroundStyle(Color(.label))
                        }
                        .listRowBackground(
                            (isOver ? Color.fingetherDanger : Color.orange)
                                .opacity(0.08)
                        )
                    }
                }
            }

            Section("Presupuestos Activos") {
                ForEach(viewModel.budgets.filter(\.isActive)) { budget in
                    NavigationLink {
                        BudgetDetailView(budget: budget, coupleId: coupleId)
                    } label: {
                        BudgetRowView(budget: budget)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteBudget(id: budget.id) }
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
                }
            }

            let inactiveBudgets = viewModel.budgets.filter { !$0.isActive }
            if !inactiveBudgets.isEmpty {
                Section("Inactivos") {
                    ForEach(inactiveBudgets) { budget in
                        BudgetRowView(budget: budget)
                            .opacity(0.6)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Budget Row View

struct BudgetRowView: View {

    let budget: Budget

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(budget.category.emoji)
                Text(budget.category.displayName)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(budget.period.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5), in: Capsule())
            }

            ProgressView(value: min(budget.usagePercentage.doubleValue, 1.0))
                .tint(progressColor)

            HStack {
                Text(budget.currentSpent.currencyFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer()
                Text(budget.amountLimit.currencyFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .padding(.vertical, 4)
    }

    private var progressColor: Color {
        let pct = budget.usagePercentage.doubleValue
        if pct >= 1.0 { return Color.fingetherDanger }
        if pct >= 0.8 { return .orange }
        return Color.fingetherPrimary
    }
}
