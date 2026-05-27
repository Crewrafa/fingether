import SwiftUI

struct TripExpenseFormView: View {
    let trip: Trip
    @Bindable var viewModel: TripViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var preferences = AppPreferences.shared
    private var lang: AppLanguage { preferences.language }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Amount
                    amountSection

                    // Category grid
                    categoryGrid

                    // Merchant
                    merchantSection

                    // Who paid
                    payerSection

                    // Date
                    dateSection

                    // Error
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.fingetherExpense)
                    }

                    // Save
                    Button {
                        Task {
                            await viewModel.addTripExpense(tripId: trip.id)
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    } label: {
                        Text(L10n.t("trip_save_expense", lang))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.fingetherExpense, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(L10n.t("trip_new_expense", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.t("cancel", lang)) { dismiss() }
                        .foregroundStyle(Color.fingetherPrimary)
                }
            }
            .onAppear {
                viewModel.resetExpenseForm()
            }
        }
    }

    // MARK: - Amount

    private var amountSection: some View {
        VStack(spacing: 8) {
            Text(L10n.t("trip_amount", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text("$")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fingetherExpense)
                TextField("0", text: $viewModel.expenseAmount)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .onChange(of: viewModel.expenseAmount) { _, val in
                        viewModel.expenseAmount = formatWithThousands(val)
                    }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.top, 8)
    }

    // MARK: - Category Grid

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("addtx_category", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 10) {
                ForEach(trip.categories) { cat in
                    Button {
                        viewModel.expenseCategory = cat
                    } label: {
                        VStack(spacing: 6) {
                            Text(cat.emoji)
                                .font(.title2)
                            Text(cat.name)
                                .font(.caption2)
                                .foregroundStyle(Color(.label))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            viewModel.expenseCategory?.id == cat.id
                                ? Color.fingetherPrimary.opacity(0.15)
                                : Color(.secondarySystemGroupedBackground)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    viewModel.expenseCategory?.id == cat.id
                                        ? Color.fingetherPrimary
                                        : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Merchant

    private var merchantSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("trip_merchant", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            HStack(spacing: 10) {
                Image(systemName: "storefront")
                    .foregroundStyle(Color.fingetherPrimary)
                TextField(L10n.t("trip_merchant_placeholder", lang), text: $viewModel.expenseMerchant)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Payer

    private var payerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("trip_who_paid", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            HStack(spacing: 12) {
                payerButton(label: L10n.t("trip_me", lang), isSelected: viewModel.expensePayerIsUser) {
                    viewModel.expensePayerIsUser = true
                }
                payerButton(label: L10n.t("trip_my_partner", lang), isSelected: !viewModel.expensePayerIsUser) {
                    viewModel.expensePayerIsUser = false
                }
            }
        }
    }

    private func payerButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : Color(.label))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    isSelected ? Color.fingetherPrimary : Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("trip_date", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            DatePicker("", selection: $viewModel.expenseDate, displayedComponents: .date)
                .labelsHidden()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
