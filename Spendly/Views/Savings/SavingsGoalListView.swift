import SwiftUI

struct SavingsGoalListView: View {
    let coupleId: UUID

    @State private var viewModel = SavingsGoalViewModel()
    @State private var showAddGoal = false
    @State private var selectedSegment: SavingsSegment = .goals
    @State private var preferences = AppPreferences.shared
    @State private var paywallFeature: PremiumFeature?  // P6: free=1 goal max
    @Namespace private var segmentAnimation
    private var lang: AppLanguage { preferences.language }

    private var isPremium: Bool {
        MockDataService.shared.mockProfile?.subscriptionTier == .premium
    }
    private var activeGoalsCount: Int {
        viewModel.goals.filter { $0.status == .active }.count
    }

    enum SavingsSegment: String, CaseIterable {
        case goals = "Metas"
        case challenges = "Retos"
        case trips = "Viajes"
    }

    private func segmentTitle(_ segment: SavingsSegment) -> String {
        switch segment {
        case .goals: return L10n.t("savings_segment_goals", lang)
        case .challenges: return L10n.t("savings_segment_challenges", lang)
        case .trips: return L10n.t("savings_segment_trips", lang)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom segmented control
                HStack(spacing: 4) {
                    ForEach(SavingsSegment.allCases, id: \.self) { segment in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selectedSegment = segment
                            }
                        } label: {
                            Text(segmentTitle(segment))
                                .font(.subheadline.weight(selectedSegment == segment ? .bold : .medium))
                                .foregroundStyle(selectedSegment == segment ? .white : Color.fingetherSlate)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background {
                                    if selectedSegment == segment {
                                        Capsule()
                                            .fill(Color.fingetherPrimary)
                                            .matchedGeometryEffect(id: "segment", in: segmentAnimation)
                                    }
                                }
                        }
                        .sensoryFeedback(.selection, trigger: selectedSegment)
                    }
                }
                .padding(4)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                switch selectedSegment {
                case .goals:
                    goalsContent
                case .challenges:
                    ChallengeListView(coupleId: coupleId)
                case .trips:
                    TripListView(coupleId: coupleId)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .trackCurrency()
            .navigationTitle(segmentTitle(selectedSegment))
            .toolbar {
                if selectedSegment == .goals {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            // P6: free tier limit from Constants
                            if !isPremium && activeGoalsCount >= Constants.FreeTierLimits.activeSavingsGoals {
                                paywallFeature = .unlimitedSavingsGoals
                            } else {
                                showAddGoal = true
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.fingetherPrimary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddGoal) {
                AddSavingsGoalView(coupleId: coupleId) {
                    Task { await viewModel.loadGoals(coupleId: coupleId) }
                }
            }
            .paywallGate($paywallFeature)
            .task {
                await viewModel.loadGoals(coupleId: coupleId)
            }
            .refreshable {
                await viewModel.loadGoals(coupleId: coupleId)
            }
        }
    }

    // MARK: - Goals Content

    private var goalsContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading && viewModel.goals.isEmpty {
                    LoadingView()
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if viewModel.goals.isEmpty {
                    VStack(spacing: 20) {
                        Spacer().frame(height: 40)

                        ZStack {
                            Circle()
                                .fill(Color.fingetherPrimary.opacity(0.04))
                                .frame(width: 160, height: 160)
                            Text("🎯")
                                .font(.system(size: 56))
                        }

                        VStack(spacing: 8) {
                            Text(L10n.t("savings_no_goals", lang))
                                .font(.title3.bold())
                                .foregroundStyle(Color(.label))
                            Text(L10n.t("savings_no_goals_subtitle", lang))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }

                        Button {
                            showAddGoal = true
                        } label: {
                            Text(L10n.t("savings_create_goal", lang))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(colors: [Color.fingetherPrimary, Color.fingetherPrimaryDark], startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: Color.fingetherPrimary.opacity(0.2), radius: 8, y: 4)
                        }

                        Spacer()
                    }
                } else {
                    totalSummaryCard
                    goalsListSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Total Summary Card

    private var totalSummaryCard: some View {
        VStack(spacing: 12) {
            Text(L10n.t("savings_total_progress", lang))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))

            let overallProgress: Double = viewModel.totalTarget > 0
                ? min(viewModel.totalSaved.doubleValue / viewModel.totalTarget.doubleValue, 1.0)
                : 0

            Text(viewModel.totalSaved.currencyFormatted)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text("de \(viewModel.totalTarget.currencyFormatted)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            ProgressView(value: overallProgress)
                .tint(.white)
                .background(.white.opacity(0.3), in: Capsule())
                .padding(.horizontal, 20)

            Text("\(Int(overallProgress * 100))% \(L10n.t("savings_of_total", lang))")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.fingetherWarning, Color.fingetherExpense],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.fingetherWarning.opacity(0.3), radius: 12, y: 6)
    }

    // MARK: - Goals List

    private var sharedGoals: [SavingsGoal] {
        viewModel.goals.filter { $0.isShared }
    }

    private var individualGoals: [SavingsGoal] {
        viewModel.goals.filter { !$0.isShared }
    }

    private var goalsListSection: some View {
        VStack(spacing: 16) {
            // Shared goals
            if !sharedGoals.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.t("savings_shared", lang))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    ForEach(sharedGoals) { goal in
                        goalLink(goal)
                    }
                }
            }

            // Individual goals
            if !individualGoals.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.t("savings_individual", lang))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    ForEach(individualGoals) { goal in
                        goalLink(goal)
                    }
                }
            }
        }
    }

    private func goalLink(_ goal: SavingsGoal) -> some View {
        NavigationLink {
            SavingsGoalDetailView(goalId: goal.id, coupleId: coupleId, viewModel: viewModel)
        } label: {
            enhancedGoalRow(goal)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                Task { await viewModel.deleteGoal(id: goal.id) }
            } label: {
                Label(L10n.t("savings_delete", lang), systemImage: "trash")
            }
        }
    }

    private func enhancedGoalRow(_ goal: SavingsGoal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(goal.emoji)
                    .font(.largeTitle)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(goal.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(.label))

                        Text(goal.isShared ? "💕" : "🧑")
                            .font(.caption2)

                        if goal.status == .completed {
                            Text("🎉")
                                .font(.caption)
                        } else if goal.progress >= 0.8 {
                            Text("🔥")
                                .font(.caption)
                        }

                        Spacer()
                    }

                    if let targetDate = goal.targetDate {
                        Text("\(L10n.t("savings_goal_date", lang)): \(targetDate.formattedSpanishLong)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Progress bar
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGroupedBackground))
                            .frame(height: 10)

                        RoundedRectangle(cornerRadius: 5)
                            .fill(progressColor(for: goal))
                            .frame(width: max(CGFloat(goal.progress) * geo.size.width, 4), height: 10)
                    }
                }
                .frame(height: 10)

                HStack {
                    Text(goal.currentAmount.currencyFormatted)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.fingetherPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Spacer()

                    Text("\(Int(goal.progress * 100))%")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(progressColor(for: goal))

                    Spacer()

                    Text(goal.targetAmount.currencyFormatted)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }

    private func progressColor(for goal: SavingsGoal) -> Color {
        if goal.status == .completed || goal.progress >= 1.0 {
            return Color.fingetherPrimary
        } else if goal.progress >= 0.8 {
            return Color.fingetherPrimary
        } else if goal.progress >= 0.5 {
            return Color.fingetherWarning
        } else {
            return Color.fingetherExpense
        }
    }
}

