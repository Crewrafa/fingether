import SwiftUI

struct DebtDetailView: View {
    let userId: UUID
    @State var debts: [Debt]
    let partnerName: String

    @State private var preferences = AppPreferences.shared
    private var lang: AppLanguage { preferences.language }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                balanceSummaryCard
                unpaidSection
                paidSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(L10n.t("debt_nav", lang))
        .navigationBarTitleDisplayMode(.inline)
        .trackCurrency()
    }

    // MARK: - Balance Summary

    private var balanceSummaryCard: some View {
        let iOwe = unpaidDebts.filter { $0.fromUserId == userId }.reduce(Decimal.zero) { $0 + $1.amount }
        let theyOwe = unpaidDebts.filter { $0.toUserId == userId }.reduce(Decimal.zero) { $0 + $1.amount }
        let net = theyOwe - iOwe

        return VStack(spacing: 12) {
            if abs(NSDecimalNumber(decimal: net).doubleValue) < 1.0 {
                Text("✅")
                    .font(.system(size: 40))
                Text(L10n.t("debt_settled", lang))
                    .font(.headline)
                    .foregroundStyle(Color.fingetherPrimary)
            } else if net > 0 {
                Text("📥")
                    .font(.system(size: 40))
                Text("\(partnerName) \(L10n.t("debt_they_owe", lang))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(net.currencyFormatted)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fingetherPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            } else {
                Text("📤")
                    .font(.system(size: 40))
                Text("\(L10n.t("debt_you_owe", lang)) \(partnerName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(abs(net).currencyFormatted)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fingetherDanger)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text(L10n.t("debt_i_owe", lang))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(iOwe.currencyFormatted)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.fingetherDanger)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                VStack(spacing: 2) {
                    Text(L10n.t("debt_owed_to_me", lang))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(theyOwe.currencyFormatted)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.fingetherPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Unpaid

    private var unpaidSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(L10n.t("debt_pending", lang)) (\(unpaidDebts.count))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if unpaidDebts.isEmpty {
                Text(L10n.t("debt_no_pending", lang))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(unpaidDebts.enumerated()), id: \.element.id) { index, debt in
                        debtRow(debt)
                        if index < unpaidDebts.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Paid

    private var paidSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let paid = paidDebts
            if !paid.isEmpty {
                Text("\(L10n.t("debt_paid", lang)) (\(paid.count))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    ForEach(Array(paid.enumerated()), id: \.element.id) { index, debt in
                        debtRow(debt)
                            .opacity(0.6)
                        if index < paid.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Debt Row

    private func debtRow(_ debt: Debt) -> some View {
        let iOweThis = debt.fromUserId == userId
        let directionEmoji = iOweThis ? "📤" : "📥"
        let directionText = iOweThis ? "\(L10n.t("debt_i_owe_to", lang)) \(partnerName)" : "\(partnerName) \(L10n.t("debt_owes_me", lang))"
        let color: Color = iOweThis ? Color.fingetherDanger : Color.fingetherPrimary

        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(directionEmoji)
                    .font(.title3)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(debt.concept)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(.label))
                    Text(directionText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(debt.createdAt.formattedSpanishLong)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if debt.isPaid, let paidAt = debt.paidAt {
                        Text("\(L10n.t("debt_paid_label", lang)): \(paidAt.formattedSpanishShort)")
                            .font(.caption2)
                            .foregroundStyle(Color.fingetherPrimary)
                    }
                }

                Spacer()

                Text(debt.amount.currencyFormatted)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(.vertical, 6)

            if !debt.isPaid {
                Button {
                    markDebtAsPaid(id: debt.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text(L10n.t("debt_mark_paid", lang))
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.fingetherPrimary, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .padding(.bottom, 2)
            }
        }
    }

    private func markDebtAsPaid(id: UUID) {
        MockDataService.shared.markDebtAsPaid(id: id)
        if let idx = debts.firstIndex(where: { $0.id == id }) {
            debts[idx].isPaid = true
            debts[idx].paidAt = Date()
            debts[idx].updatedAt = Date()
        }
    }

    // MARK: - Helpers

    private var unpaidDebts: [Debt] {
        debts.filter { !$0.isPaid }.sorted { $0.createdAt > $1.createdAt }
    }

    private var paidDebts: [Debt] {
        debts.filter { $0.isPaid }.sorted { $0.createdAt > $1.createdAt }
    }
}
