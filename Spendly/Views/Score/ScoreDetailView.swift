import SwiftUI

struct ScoreDetailView: View {

    let coupleId: UUID

    @State private var viewModel = ScoreViewModel()
    @State private var preferences = AppPreferences.shared
    private var lang: AppLanguage { preferences.language }

    private let tealColor = Color.fingetherPrimary

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryCard
                breakdownDetailCards
                improvementSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(L10n.t("score_detail_nav", lang))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadScore(coupleId: coupleId)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t("score_current", lang))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(viewModel.scoreValue)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(viewModel.currentScore?.scoreColor ?? .secondary)
                        Text("/100")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(L10n.t("score_trend", lang))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.trend.iconName)
                            .font(.title3.weight(.semibold))
                        Text(viewModel.trend.arrow)
                            .font(.title2.weight(.bold))
                    }
                    .foregroundStyle(viewModel.trend.color)
                }
            }

            if let score = viewModel.currentScore {
                HStack {
                    Label(score.scoreLabel, systemImage: "star.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(score.scoreColor)
                    Spacer()
                    Text("\(L10n.t("score_calculated", lang)): \(score.calculatedAt.formattedSpanishShort)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Breakdown Detail Cards

    private var breakdownDetailCards: some View {
        VStack(spacing: 12) {
            if let breakdown = viewModel.breakdown {
                detailCard(
                    emoji: "📊",
                    title: L10n.t("score_budget_adherence", lang),
                    score: breakdown.budgetAdherence,
                    description: L10n.t("score_budget_adherence_desc", lang),
                    tip: breakdown.budgetAdherence < 60
                        ? L10n.t("score_budget_tip_low", lang)
                        : L10n.t("score_budget_tip_high", lang)
                )

                detailCard(
                    emoji: "💰",
                    title: L10n.t("score_savings_rate_title", lang),
                    score: breakdown.savingsRate,
                    description: L10n.t("score_savings_rate_desc", lang),
                    tip: breakdown.savingsRate < 60
                        ? L10n.t("score_savings_tip_low", lang)
                        : L10n.t("score_savings_tip_high", lang)
                )

                detailCard(
                    emoji: "💳",
                    title: L10n.t("score_debt_title", lang),
                    score: breakdown.debtManagement,
                    description: L10n.t("score_debt_desc", lang),
                    tip: breakdown.debtManagement < 60
                        ? L10n.t("score_debt_tip_low", lang)
                        : L10n.t("score_debt_tip_high", lang)
                )

                detailCard(
                    emoji: "📝",
                    title: L10n.t("score_consistency_title", lang),
                    score: breakdown.transactionConsistency,
                    description: L10n.t("score_consistency_desc", lang),
                    tip: breakdown.transactionConsistency < 60
                        ? L10n.t("score_consistency_tip_low", lang)
                        : L10n.t("score_consistency_tip_high", lang)
                )

                detailCard(
                    emoji: "🎯",
                    title: L10n.t("score_goal_title", lang),
                    score: breakdown.goalProgress,
                    description: L10n.t("score_goal_desc", lang),
                    tip: breakdown.goalProgress < 60
                        ? L10n.t("score_goal_tip_low", lang)
                        : L10n.t("score_goal_tip_high", lang)
                )

                detailCard(
                    emoji: "🔀",
                    title: L10n.t("score_diversity_title", lang),
                    score: breakdown.spendingDiversity,
                    description: L10n.t("score_diversity_desc", lang),
                    tip: breakdown.spendingDiversity < 60
                        ? L10n.t("score_diversity_tip_low", lang)
                        : L10n.t("score_diversity_tip_high", lang)
                )
            }
        }
    }

    private func detailCard(emoji: String, title: String, score: Int, description: String, tip: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(emoji) \(title)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(score)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(colorForScore(score))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorForScore(score))
                        .frame(width: geo.size.width * CGFloat(score) / 100, height: 8)
                }
            }
            .frame(height: 8)

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.fingetherWarning)
                    .padding(.top, 1)
                Text(tip)
                    .font(.caption)
                    .foregroundStyle(Color(.label))
            }
            .padding(10)
            .background(Color.fingetherWarning.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Improvement Section

    private var improvementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("score_improve_title", lang))
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                improvementItem(number: 1, text: L10n.t("score_improve_1", lang))
                improvementItem(number: 2, text: L10n.t("score_improve_2", lang))
                improvementItem(number: 3, text: L10n.t("score_improve_3", lang))
                improvementItem(number: 4, text: L10n.t("score_improve_4", lang))
                improvementItem(number: 5, text: L10n.t("score_improve_5", lang))
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func improvementItem(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(tealColor)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color(.label))
        }
    }

    // MARK: - Helpers

    private func colorForScore(_ score: Int) -> Color {
        switch score {
        case 75...100: return Color.fingetherPrimary
        case 60..<75: return Color.fingetherAmber
        case 40..<60: return Color.fingetherWarning
        default: return Color.fingetherDanger
        }
    }
}
