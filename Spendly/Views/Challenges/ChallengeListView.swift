import SwiftUI

struct ChallengeListView: View {
    let coupleId: UUID

    @State private var viewModel = ChallengeViewModel()
    @State private var preferences = AppPreferences.shared
    @State private var paywallFeature: PremiumFeature?  // P6
    private var lang: AppLanguage { preferences.language }

    private var isPremium: Bool {
        MockDataService.shared.mockProfile?.subscriptionTier == .premium
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading && viewModel.challenges.isEmpty {
                    LoadingView()
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if viewModel.challenges.isEmpty && viewModel.suggestedChallenges.isEmpty {
                    EmptyStateView(
                        icon: "flag.checkered",
                        title: L10n.t("challenge_no_challenges", lang),
                        subtitle: L10n.t("challenge_no_challenges_subtitle", lang)
                    )
                    .padding(.top, 40)
                } else {
                    // Active challenge (hero card)
                    if let active = viewModel.activeChallenge {
                        activeChallengeCard(active)
                    }

                    // Suggested challenges
                    if !viewModel.suggestedChallenges.isEmpty {
                        suggestedSection
                    }

                    // History
                    if !viewModel.historyChallenges.isEmpty {
                        historySection
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .task {
            await viewModel.loadChallenges(coupleId: coupleId)
        }
        .refreshable {
            await viewModel.loadChallenges(coupleId: coupleId)
        }
        .paywallGate($paywallFeature)
    }

    // MARK: - Active Challenge Hero

    private func activeChallengeCard(_ challenge: FinancialChallenge) -> some View {
        NavigationLink {
            ChallengeDetailView(challenge: challenge, coupleId: coupleId, viewModel: viewModel)
        } label: {
            VStack(spacing: 14) {
                HStack {
                    Text(challenge.type.emoji)
                        .font(.system(size: 36))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("challenge_active", lang))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                        Text(challenge.name)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(challenge.difficulty.emoji)
                            .font(.title3)
                        Text("\(challenge.daysRemaining)d")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }

                // Progress bar
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.white.opacity(0.25))
                                .frame(height: 14)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.white)
                                .frame(width: max(CGFloat(challenge.progress) * geo.size.width, 4), height: 14)
                        }
                    }
                    .frame(height: 14)

                    HStack {
                        Text("\(Int(challenge.progress * 100))% \(L10n.t("challenge_completed_pct", lang))")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Text("+\(challenge.xpReward) XP")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(20)
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
        .buttonStyle(.plain)
    }

    // MARK: - Suggested Challenges

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.t("challenge_suggested", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)

            ForEach(viewModel.suggestedChallenges) { challenge in
                suggestedCard(challenge)
            }
        }
    }

    private func suggestedCard(_ challenge: FinancialChallenge) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(challenge.type.emoji)
                    .font(.largeTitle)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(challenge.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(.label))

                        Text(challenge.difficulty.displayName)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(difficultyColor(challenge.difficulty).opacity(0.15))
                            .foregroundStyle(difficultyColor(challenge.difficulty))
                            .clipShape(Capsule())
                    }

                    Text(challenge.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            HStack {
                Label("+\(challenge.xpReward) XP", systemImage: "star.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.fingetherWarning)

                Spacer()

                Button {
                    // P6: challenges require premium
                    if isPremium {
                        Task {
                            await viewModel.acceptChallenge(challenge, coupleId: coupleId)
                        }
                    } else {
                        paywallFeature = .challenges
                    }
                } label: {
                    Text(L10n.t("challenge_accept", lang))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.fingetherPrimary, in: Capsule())
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.t("challenge_history", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)

            ForEach(viewModel.historyChallenges) { challenge in
                historyRow(challenge)
            }
        }
    }

    private func historyRow(_ challenge: FinancialChallenge) -> some View {
        HStack(spacing: 12) {
            Text(challenge.status.emoji)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(.label))

                HStack(spacing: 8) {
                    Text(challenge.status.displayName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(statusColor(challenge.status))

                    Text(challenge.endDate.formattedSpanishShort)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if challenge.status == .completed {
                Text("+\(challenge.xpReward) XP")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.fingetherWarning)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private func difficultyColor(_ difficulty: ChallengeDifficulty) -> Color {
        switch difficulty {
        case .easy: return Color.fingetherPrimary
        case .medium: return Color.fingetherWarning
        case .hard: return Color.fingetherWarning
        case .extreme: return Color.fingetherDanger
        }
    }

    private func statusColor(_ status: ChallengeStatus) -> Color {
        switch status {
        case .active: return Color.fingetherPrimary
        case .completed: return Color.fingetherPrimary
        case .failed: return Color.fingetherDanger
        case .cancelled: return .secondary
        }
    }
}
