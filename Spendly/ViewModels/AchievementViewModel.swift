import Foundation

@MainActor
@Observable
final class AchievementViewModel {

    // MARK: - State

    var achievements: [Achievement] = []
    var newlyUnlockedKeys: [String] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Computed Properties

    var unlockedAchievements: [Achievement] {
        achievements.filter { $0.isUnlocked }
    }

    var lockedAchievements: [Achievement] {
        achievements.filter { !$0.isUnlocked }
    }

    var totalProgress: Double {
        guard !achievements.isEmpty else { return 0 }
        return Double(unlockedAchievements.count) / Double(achievements.count)
    }

    // MARK: - Actions

    func loadAchievements(coupleId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            achievements = try await AchievementService.getAchievements(coupleId: coupleId)
        } catch {
            errorMessage = "No se pudieron cargar los logros. Intenta de nuevo."
        }
    }

    func checkForNew(coupleId: UUID) async {
        errorMessage = nil

        do {
            newlyUnlockedKeys = try await AchievementService.checkAchievements(coupleId: coupleId)
            // Reload achievements to get updated state
            if !newlyUnlockedKeys.isEmpty {
                achievements = try await AchievementService.getAchievements(coupleId: coupleId)
            }
        } catch {
            errorMessage = "No se pudieron verificar nuevos logros."
        }
    }

    func dismissNewlyUnlocked() {
        newlyUnlockedKeys = []
    }
}
