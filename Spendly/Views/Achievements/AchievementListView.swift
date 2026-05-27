import SwiftUI

struct AchievementListView: View {
    let coupleId: UUID

    @State private var viewModel = AchievementViewModel()
    @State private var preferences = AppPreferences.shared
    private var isCoupleMode: Bool { preferences.isCoupleMode }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.achievements.isEmpty {
                    LoadingView()
                } else if viewModel.achievements.isEmpty {
                    EmptyStateView(
                        icon: "trophy",
                        title: "Sin logros aun",
                        subtitle: "Completa retos financieros para desbloquear logros y accesorios para tu mascota"
                    )
                } else {
                    achievementGrid
                }
            }
            .navigationTitle("Logros")
            .task {
                await viewModel.loadAchievements(coupleId: coupleId)
                await viewModel.checkForNew(coupleId: coupleId)
            }
            .refreshable {
                await viewModel.loadAchievements(coupleId: coupleId)
            }
        }
    }

    private var achievementGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                let unlocked = viewModel.achievements.filter { $0.unlockedAt != nil }
                let locked = viewModel.achievements.filter { $0.unlockedAt == nil }

                // Couple highlights — only when isCoupleMode
                if isCoupleMode {
                    let coupleAch = viewModel.achievements.filter { $0.category == .social }
                    if !coupleAch.isEmpty {
                        coupleSectionHeader
                        achievementsGrid(coupleAch, isLocked: false)
                    }
                }

                if !unlocked.isEmpty {
                    sectionHeader("Desbloqueados (\(unlocked.count))")
                    achievementsGrid(unlocked, isLocked: false)
                }

                if !locked.isEmpty {
                    sectionHeader("Por desbloquear (\(locked.count))")
                    achievementsGrid(locked, isLocked: true)
                }
            }
            .padding()
        }
    }

    private var coupleSectionHeader: some View {
        let mock = MockDataService.shared
        return HStack(spacing: 8) {
            Text("💕")
            Text("Logros de pareja")
                .font(.headline)
            Spacer()
            Text("\(mock.currentUser1Name) & \(mock.currentUser2Name)")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.fingetherRose.opacity(0.18))
                .clipShape(Capsule())
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func achievementsGrid(_ achievements: [Achievement], isLocked: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(achievements) { achievement in
                achievementCard(achievement, isLocked: isLocked)
            }
        }
    }

    private func achievementCard(_ achievement: Achievement, isLocked: Bool) -> some View {
        let isCouple = achievement.category == .social && isCoupleMode
        let accentColor: Color = isCouple ? Color.fingetherRose : Color.fingetherPrimary

        return VStack(spacing: 8) {
            Image(systemName: achievement.icon)
                .font(.system(size: 36))
                .foregroundStyle(isLocked ? .secondary : accentColor)
                .opacity(isLocked ? 0.4 : 1)

            Text(achievement.title)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(achievement.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if isLocked {
                ProgressView(value: Double(achievement.progress), total: Double(achievement.target))
                    .tint(accentColor)
                Text("\(achievement.progress)/\(achievement.target)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if let date = achievement.unlockedAt {
                Text(date.formattedSpanishShort)
                    .font(.caption2)
                    .foregroundStyle(accentColor)
            }

            if let accessory = achievement.rewardAccessory {
                HStack(spacing: 2) {
                    Image(systemName: "gift.fill")
                        .font(.caption2)
                    Text(accessory.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption2)
                }
                .foregroundStyle(.orange)
            }

            if isCouple {
                let mock = MockDataService.shared
                HStack(spacing: 3) {
                    Text("💕")
                        .font(.system(size: 9))
                    Text("\(mock.currentUser1Name) & \(mock.currentUser2Name)")
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(accentColor)
                .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            isLocked ? Color(.systemGray6) : accentColor.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isLocked ? .clear : accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}
