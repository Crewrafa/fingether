import SwiftUI

struct AddBudgetView: View {

    @Environment(\.dismiss) private var dismiss

    let coupleId: UUID

    @State private var selectedCategory: TransactionCategory = .food
    @State private var amountLimit = ""
    @State private var period: BudgetPeriod = .monthly
    @State private var alertThreshold = 0.80
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let errorMessage {
                        ErrorBanner(message: errorMessage) {
                            self.errorMessage = nil
                        }
                    }

                    categorySection
                    amountSection
                    periodSection
                    thresholdSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Nuevo Presupuesto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Color.fingetherDanger)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await createBudget() }
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Crear")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(amountLimit.isEmpty || isLoading)
                }
            }
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categoria")
                .font(.headline)
                .foregroundStyle(Color(.label))

            let expenseCategories: [TransactionCategory] = [
                .food, .transport, .housing, .utilities, .entertainment,
                .health, .education, .shopping, .travel, .gifts, .other
            ]
            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(expenseCategories) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedCategory = category
                        }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(
                                        selectedCategory == category
                                        ? (Constants.categoryColors[category] ?? .gray)
                                        : (Constants.categoryColors[category] ?? .gray).opacity(0.12)
                                    )
                                    .frame(width: 44, height: 44)

                                Image(systemName: category.iconName)
                                    .font(.system(size: 18))
                                    .foregroundStyle(
                                        selectedCategory == category ? .white : (Constants.categoryColors[category] ?? .gray)
                                    )
                            }

                            Text(category.displayName)
                                .font(.system(size: 10))
                                .foregroundStyle(Color(.label))
                                .lineLimit(1)
                        }
                    }
                    .sensoryFeedback(.selection, trigger: selectedCategory)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
        }
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Limite del presupuesto")
                .font(.headline)
                .foregroundStyle(Color(.label))

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fingetherPrimary)

                TextField("0", text: $amountLimit)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(.label))
                    .onChange(of: amountLimit) { _, val in
                        amountLimit = formatWithThousands(val)
                    }
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    // MARK: - Period Section

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Periodo")
                .font(.headline)
                .foregroundStyle(Color(.label))

            HStack(spacing: 8) {
                ForEach(BudgetPeriod.allCases) { budgetPeriod in
                    Button {
                        period = budgetPeriod
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: budgetPeriod.iconName)
                                .font(.title3)
                            Text(budgetPeriod.displayName)
                                .font(.caption.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            period == budgetPeriod
                            ? Color.fingetherPrimary
                            : Color(.secondarySystemGroupedBackground)
                        )
                        .foregroundStyle(
                            period == budgetPeriod ? .white : Color(.label)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                    }
                }
            }
        }
    }

    // MARK: - Threshold Section

    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Umbral de alerta")
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                Spacer()
                Text("\(Int(alertThreshold * 100))%")
                    .font(.headline)
                    .foregroundStyle(Color.fingetherPrimary)
            }

            Text("Te avisaremos cuando llegues a este porcentaje de tu presupuesto.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Slider(value: $alertThreshold, in: 0.5...0.95, step: 0.05)
                .tint(Color.fingetherPrimary)

            HStack {
                Text("50%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("95%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }

    // MARK: - Create Budget

    private func createBudget() async {
        guard let amount = Decimal(string: amountLimit.replacingOccurrences(of: ",", with: ".")), amount > 0 else {
            errorMessage = "Ingresa un monto valido mayor a cero."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let budget = Budget(
                id: UUID(),
                coupleId: coupleId,
                category: selectedCategory,
                amountLimit: amount,
                period: period,
                currentSpent: 0,
                alertThreshold: Decimal(alertThreshold),
                isActive: true,
                startDate: Date(),
                createdAt: Date(),
                updatedAt: Date()
            )
            _ = try await BudgetService.createBudget(budget)
            dismiss()
        } catch {
            errorMessage = "No se pudo crear el presupuesto. Intenta de nuevo."
        }
    }
}
