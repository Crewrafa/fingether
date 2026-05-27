import SwiftUI

struct SimulationResultView: View {
    let simulation: Simulation
    /// Optional: how the impact is split between partners (only relevant when isCoupleMode).
    /// Default `.both` keeps backwards-compatible behavior for existing call sites.
    var affectedPartner: SimulatorViewModel.AffectedPartner = .both

    @Environment(\.dismiss) private var dismiss
    @State private var preferences = AppPreferences.shared
    private var lang: AppLanguage { preferences.language }
    private var isCoupleMode: Bool { preferences.isCoupleMode }

    private var result: SimulationResult {
        simulation.result ?? SimulationResult(
            projectedTotal: 0,
            monthlyBreakdown: [],
            savingsGain: 0,
            timeToGoalMonths: nil,
            summary: ""
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Comparison card
                    comparisonCard

                    // Couple impact (only when isCoupleMode)
                    if isCoupleMode {
                        coupleImpactCard
                    }

                    // Impact bar
                    impactBarCard

                    // Risk badge
                    riskCard

                    // Monthly projection chart
                    projectionCard

                    // Recommendation
                    recommendationCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .trackCurrency()
            .navigationTitle(L10n.t("simresult_nav", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("simresult_done", lang)) { dismiss() }
                        .foregroundStyle(Color.fingetherPrimary)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Two-Column Comparison

    private var comparisonCard: some View {
        VStack(spacing: 16) {
            Text(simulation.type.emoji)
                .font(.system(size: 40))

            Text(simulation.name)
                .font(.title3.bold())
                .foregroundStyle(Color(.label))

            HStack(spacing: 0) {
                // Now column
                VStack(spacing: 8) {
                    Text(L10n.t("simresult_now", lang))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(currentMonthlyValue.currencyFormatted)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text(L10n.t("simresult_monthly", lang))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                // Arrow
                VStack {
                    Image(systemName: "arrow.right")
                        .font(.title3.bold())
                        .foregroundStyle(Color.fingetherPrimary)
                }
                .frame(width: 40)

                // Projected column
                VStack(spacing: 8) {
                    Text(L10n.t("simresult_projected", lang))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(result.projectedTotal.currencyFormatted)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.fingetherPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text(String(format: L10n.t("simresult_in_months", lang), simulation.params.months))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            if result.savingsGain != 0 {
                HStack(spacing: 4) {
                    Image(systemName: result.savingsGain > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    Text("\(L10n.t("simresult_gain", lang)): \(result.savingsGain.currencyFormatted)")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(result.savingsGain > 0 ? Color.fingetherPrimary : Color.fingetherExpense)
            }

            if let months = result.timeToGoalMonths {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                    Text(String(format: L10n.t("simresult_goal_months", lang), months))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.fingetherSky)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
    }

    // MARK: - Impact Bar

    private var impactBarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("simresult_impact", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.label))

            let monthlyImpact = simulation.params.monthlyAmount
            let income = MockDataService.shared.getMockProfile().monthlyIncome
            let impactRatio = income > 0 ? min(monthlyImpact.doubleValue / income.doubleValue, 1.0) : 0

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGroupedBackground))
                        .frame(height: 20)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(impactColor(impactRatio))
                        .frame(width: max(CGFloat(impactRatio) * geo.size.width, 6), height: 20)
                }
            }
            .frame(height: 20)

            HStack {
                Text("\(Int(impactRatio * 100))% \(L10n.t("simresult_of_income", lang))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(monthlyImpact.currencyFormatted)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Color(.label))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Risk Badge

    private var riskCard: some View {
        HStack(spacing: 14) {
            Text(simulation.riskLevel.emoji)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("simresult_risk", lang))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(simulation.riskLevel.displayName)
                    .font(.headline)
                    .foregroundStyle(riskColor)
            }

            Spacer()

            Text(riskDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
        }
        .padding(16)
        .background(riskColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Projection

    private var projectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("simresult_projection", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.label))

            if result.monthlyBreakdown.count > 1 {
                // Simple bar chart
                let maxVal = result.monthlyBreakdown.max() ?? 1
                let step = max(result.monthlyBreakdown.count / 6, 1)
                let sampledIndices = stride(from: 0, to: result.monthlyBreakdown.count, by: step).map { $0 }

                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(sampledIndices, id: \.self) { idx in
                        let val = result.monthlyBreakdown[idx]
                        let height = maxVal > 0 ? CGFloat(val.doubleValue / maxVal.doubleValue) * 100 : 0
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.fingetherPrimary, Color.fingetherPrimaryDark],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: max(height, 4))

                            Text("M\(idx + 1)")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 120)

                HStack {
                    Text("\(L10n.t("simresult_month", lang)) 1")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(L10n.t("simresult_month", lang)) \(result.monthlyBreakdown.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Recommendation

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Color.fingetherWarning)
                Text(L10n.t("simresult_recommendation", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.label))
            }

            Text(result.summary)
                .font(.subheadline)
                .foregroundStyle(Color(.label))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.fingetherWarning.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private var currentMonthlyValue: Decimal {
        simulation.params.monthlyAmount
    }

    private func impactColor(_ ratio: Double) -> Color {
        if ratio >= 0.4 { return Color.fingetherExpense }
        if ratio >= 0.2 { return Color.fingetherWarning }
        return Color.fingetherPrimary
    }

    private var riskColor: Color {
        switch simulation.riskLevel {
        case .low: return Color.fingetherPrimary
        case .medium: return Color.fingetherWarning
        case .high: return Color.fingetherExpense
        }
    }

    private var riskDescription: String {
        switch simulation.riskLevel {
        case .low:
            return L10n.t("simresult_risk_low", lang)
        case .medium:
            return L10n.t("simresult_risk_medium", lang)
        case .high:
            return L10n.t("simresult_risk_high", lang)
        }
    }

    // MARK: - Couple Impact Card (only in couple mode)

    private var coupleImpactCard: some View {
        let mock = MockDataService.shared
        let n1 = mock.currentUser1Name
        let n2 = mock.currentUser2Name
        let before = computeAvailableBefore()
        let after = computeAvailableAfter(before: before)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("💕")
                    .font(.title3)
                Text("Impacto por persona")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(.label))
                Spacer()
                Text(affectedTagLabel(n1: n1, n2: n2))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.fingetherRose.opacity(0.18))
                    .foregroundStyle(Color(.label))
                    .clipShape(Capsule())
            }

            HStack(alignment: .top, spacing: 12) {
                impactPersonColumn(name: n1, before: before.user1, after: after.user1)
                Rectangle()
                    .fill(Color.fingetherRose.opacity(0.25))
                    .frame(width: 1)
                impactPersonColumn(name: n2, before: before.user2, after: after.user2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.fingetherRose.opacity(0.45), lineWidth: 1.5)
        )
        .shadow(color: Color.fingetherRose.opacity(0.18), radius: 10, y: 4)
    }

    private func impactPersonColumn(name: String, before: Decimal, after: Decimal) -> some View {
        let delta = after - before
        let isPositive = delta >= 0
        return VStack(spacing: 8) {
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(.label))
                .lineLimit(1)

            VStack(spacing: 2) {
                Text("Antes")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Text(before.currencyFormatted)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Image(systemName: "arrow.down")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            VStack(spacing: 2) {
                Text("Despues")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Text(after.currencyFormatted)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(isPositive ? Color.fingetherPrimary : Color.fingetherExpense)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                Text("\(delta >= 0 ? "+" : "")\(delta.currencyFormatted)")
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(isPositive ? Color.fingetherPrimary : Color.fingetherExpense)
        }
        .frame(maxWidth: .infinity)
    }

    private func affectedTagLabel(n1: String, n2: String) -> String {
        switch affectedPartner {
        case .both: return "Ambos"
        case .user1: return n1
        case .user2: return n2
        }
    }

    /// Disponible mensual (ingreso − gastos del mes) por persona ANTES de aplicar la simulacion.
    private func computeAvailableBefore() -> (user1: Decimal, user2: Decimal) {
        let mock = MockDataService.shared
        let cal = Calendar.current
        let now = Date()
        let split = mock.coupleSettings.defaultSplitType

        var u1Expenses: Decimal = 0
        var u2Expenses: Decimal = 0

        for tx in mock.mockTransactions where tx.type == .expense
            && cal.isDate(tx.date, equalTo: now, toGranularity: .month)
        {
            if tx.isShared {
                let parts = mock.splitFor(amount: tx.amount, splitType: tx.splitType ?? split)
                u1Expenses += parts.user1
                u2Expenses += parts.user2
            } else if tx.userId == mock.currentUser1Id {
                u1Expenses += tx.amount
            } else if tx.userId == mock.currentUser2Id {
                u2Expenses += tx.amount
            }
        }

        return (
            mock.currentUser1Income - u1Expenses,
            mock.currentUser2Income - u2Expenses
        )
    }

    /// Disponible mensual por persona DESPUES de aplicar la simulacion.
    private func computeAvailableAfter(before: (user1: Decimal, user2: Decimal)) -> (user1: Decimal, user2: Decimal) {
        let amount = simulation.params.monthlyAmount

        let signedDelta: Decimal
        switch simulation.type {
        case .incomeIncrease:
            signedDelta = amount
        case .expenseReduction:
            signedDelta = amount
        case .savingsProjection, .emergencyFund:
            signedDelta = -amount
        case .debtPayoff:
            signedDelta = -amount
        }

        switch affectedPartner {
        case .both:
            let half = signedDelta / 2
            return (before.user1 + half, before.user2 + half)
        case .user1:
            return (before.user1 + signedDelta, before.user2)
        case .user2:
            return (before.user1, before.user2 + signedDelta)
        }
    }
}
