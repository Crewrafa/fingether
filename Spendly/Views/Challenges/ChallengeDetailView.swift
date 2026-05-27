import SwiftUI

struct ChallengeDetailView: View {
    let challenge: FinancialChallenge
    let coupleId: UUID
    @Bindable var viewModel: ChallengeViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var showAbandonAlert = false
    @State private var preferences = AppPreferences.shared
    private var lang: AppLanguage { preferences.language }

    private var currentChallenge: FinancialChallenge {
        viewModel.challenges.first(where: { $0.id == challenge.id }) ?? challenge
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Progress
                progressSection

                // Days remaining
                daysSection

                // Mascot message
                mascotMessageCard

                // Details
                detailsCard

                // Abandon button
                if currentChallenge.status == .active {
                    Button {
                        showAbandonAlert = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "flag.fill")
                            Text(L10n.t("challenge_abandon", lang))
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.fingetherExpense)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.fingetherExpense.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(L10n.t("challenge_detail_nav", lang))
        .navigationBarTitleDisplayMode(.inline)
        .alert(L10n.t("challenge_abandon_title", lang), isPresented: $showAbandonAlert) {
            Button(L10n.t("cancel", lang), role: .cancel) {}
            Button(L10n.t("challenge_abandon_btn", lang), role: .destructive) {
                Task {
                    await viewModel.abandonChallenge(challenge.id)
                    dismiss()
                }
            }
        } message: {
            Text(String(format: L10n.t("challenge_abandon_msg", lang), currentChallenge.xpReward))
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text(currentChallenge.type.emoji)
                .font(.system(size: 60))

            Text(currentChallenge.name)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(currentChallenge.description)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            HStack(spacing: 12) {
                Label(currentChallenge.difficulty.displayName, systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.2), in: Capsule())
                    .foregroundStyle(.white)

                Label("+\(currentChallenge.xpReward) XP", systemImage: "star.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.2), in: Capsule())
                    .foregroundStyle(.white)
            }
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

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text(L10n.t("challenge_progress", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.label))
                Spacer()
                Text("\(Int(currentChallenge.progress * 100))%")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(progressColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGroupedBackground))
                        .frame(height: 24)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(progressColor)
                        .frame(width: max(CGFloat(currentChallenge.progress) * geo.size.width, 6), height: 24)
                }
            }
            .frame(height: 24)

            HStack {
                Text("\(L10n.t("challenge_current", lang)): \(formattedValue(currentChallenge.currentValue))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(L10n.t("challenge_target", lang)): \(formattedValue(currentChallenge.targetValue))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Days Remaining

    private var daysSection: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("\(currentChallenge.daysRemaining)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fingetherPrimary)
                Text(L10n.t("challenge_days_remaining", lang))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 50)

            VStack(spacing: 4) {
                let total = max(Calendar.current.dateComponents([.day], from: currentChallenge.startDate, to: currentChallenge.endDate).day ?? 1, 1)
                let elapsed = max(total - currentChallenge.daysRemaining, 0)
                Text("\(elapsed)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(.label))
                Text(L10n.t("challenge_days_completed", lang))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Mascot Message

    private var mascotMessageCard: some View {
        HStack(spacing: 12) {
            Text("🐾")
                .font(.system(size: 36))

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("challenge_finzy_says", lang))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.fingetherPrimary)
                Text(mascotMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color(.label))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.fingetherPrimary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Details

    private var detailsCard: some View {
        VStack(spacing: 12) {
            detailRow(icon: "calendar", label: L10n.t("challenge_start", lang), value: currentChallenge.startDate.formattedSpanishLong)
            Divider()
            detailRow(icon: "calendar.badge.clock", label: L10n.t("challenge_end", lang), value: currentChallenge.endDate.formattedSpanishLong)
            Divider()
            detailRow(icon: "chart.bar.fill", label: L10n.t("challenge_metric", lang), value: currentChallenge.metric.displayName)
            if let category = currentChallenge.category {
                Divider()
                detailRow(icon: "tag.fill", label: L10n.t("challenge_category_label", lang), value: category.displayName)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(.label))
        }
    }

    // MARK: - Helpers

    private var progressColor: Color {
        if currentChallenge.progress >= 0.8 { return Color.fingetherPrimary }
        if currentChallenge.progress >= 0.5 { return Color.fingetherWarning }
        return Color.fingetherWarning
    }

    private var mascotMessage: String {
        if currentChallenge.progress >= 0.9 {
            return L10n.t("challenge_mascot_90", lang)
        } else if currentChallenge.progress >= 0.5 {
            return L10n.t("challenge_mascot_50", lang)
        } else if currentChallenge.progress >= 0.2 {
            return L10n.t("challenge_mascot_20", lang)
        } else {
            return L10n.t("challenge_mascot_low", lang)
        }
    }

    private func formattedValue(_ value: Decimal) -> String {
        switch currentChallenge.metric {
        case .amount:
            return value.currencyFormatted
        case .days:
            return "\(Int(NSDecimalNumber(decimal: value).doubleValue)) \(L10n.t("challenge_days", lang))"
        case .count:
            return "\(Int(NSDecimalNumber(decimal: value).doubleValue))"
        case .percentage:
            return "\(Int(NSDecimalNumber(decimal: value).doubleValue))%"
        }
    }
}
