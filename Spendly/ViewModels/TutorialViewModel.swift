import Foundation
import SwiftUI

// MARK: - Tutorial Module

/// Un paso del walkthrough interactivo. Define que muestra y a que pestaña navega.
struct TutorialModule: Identifiable, Hashable, Sendable {
    let id: Int
    let titleKey: String       // L10n key
    let descriptionKey: String // L10n key
    let tipKey: String         // L10n key
    let ctaKey: String         // L10n key — texto del boton "Ir a..."
    let icon: String           // SF Symbol
    let iconColorName: String  // "teal" | "rose" | "gold" | "coral" | "forest"
    let targetTab: String      // raw value de MainTabView.Tab
    let requiresCouple: Bool   // ocultar si no hay pareja
    let isInformational: Bool  // true = se marca completo al tocar CTA
}

// MARK: - Tutorial View Model

@MainActor
@Observable
final class TutorialViewModel {

    // MARK: - State

    /// Set para invalidar la UI cuando cambian los datos del mock o las preferencias.
    /// El propio @Observable detecta acceso a esta propiedad.
    var refreshTick: Int = 0

    // MARK: - Module Catalog

    /// Los 11 modulos del tutorial en el orden propuesto.
    let allModules: [TutorialModule] = [
        TutorialModule(
            id: 1,
            titleKey: "tutorial_m1_title",
            descriptionKey: "tutorial_m1_desc",
            tipKey: "tutorial_m1_tip",
            ctaKey: "tutorial_m1_cta",
            icon: "creditcard.fill",
            iconColorName: "teal",
            targetTab: "transactions",
            requiresCouple: false,
            isInformational: false
        ),
        TutorialModule(
            id: 2,
            titleKey: "tutorial_m2_title",
            descriptionKey: "tutorial_m2_desc",
            tipKey: "tutorial_m2_tip",
            ctaKey: "tutorial_m2_cta",
            icon: "pin.circle.fill",
            iconColorName: "teal",
            targetTab: "fixedExpenses",
            requiresCouple: false,
            isInformational: false
        ),
        TutorialModule(
            id: 3,
            titleKey: "tutorial_m3_title",
            descriptionKey: "tutorial_m3_desc",
            tipKey: "tutorial_m3_tip",
            ctaKey: "tutorial_m3_cta",
            icon: "heart.circle.fill",
            iconColorName: "rose",
            targetTab: "settings",
            requiresCouple: false,
            isInformational: false
        ),
        TutorialModule(
            id: 4,
            titleKey: "tutorial_m4_title",
            descriptionKey: "tutorial_m4_desc",
            tipKey: "tutorial_m4_tip",
            ctaKey: "tutorial_m4_cta",
            icon: "arrow.left.arrow.right.circle",
            iconColorName: "teal",
            targetTab: "dashboard",
            requiresCouple: true,
            isInformational: false
        ),
        TutorialModule(
            id: 5,
            titleKey: "tutorial_m5_title",
            descriptionKey: "tutorial_m5_desc",
            tipKey: "tutorial_m5_tip",
            ctaKey: "tutorial_m5_cta",
            icon: "target",
            iconColorName: "gold",
            targetTab: "savings",
            requiresCouple: false,
            isInformational: false
        ),
        TutorialModule(
            id: 6,
            titleKey: "tutorial_m6_title",
            descriptionKey: "tutorial_m6_desc",
            tipKey: "tutorial_m6_tip",
            ctaKey: "tutorial_m6_cta",
            icon: "trophy.fill",
            iconColorName: "gold",
            targetTab: "savings",
            requiresCouple: false,
            isInformational: false
        ),
        TutorialModule(
            id: 7,
            titleKey: "tutorial_m7_title",
            descriptionKey: "tutorial_m7_desc",
            tipKey: "tutorial_m7_tip",
            ctaKey: "tutorial_m7_cta",
            icon: "airplane",
            iconColorName: "teal",
            targetTab: "savings",
            requiresCouple: false,
            isInformational: false
        ),
        TutorialModule(
            id: 8,
            titleKey: "tutorial_m8_title",
            descriptionKey: "tutorial_m8_desc",
            tipKey: "tutorial_m8_tip",
            ctaKey: "tutorial_m8_cta",
            icon: "banknote",
            iconColorName: "coral",
            targetTab: "settings",
            requiresCouple: false,
            isInformational: true
        ),
        TutorialModule(
            id: 9,
            titleKey: "tutorial_m9_title",
            descriptionKey: "tutorial_m9_desc",
            tipKey: "tutorial_m9_tip",
            ctaKey: "tutorial_m9_cta",
            icon: "chart.line.uptrend.xyaxis",
            iconColorName: "forest",
            targetTab: "settings",
            requiresCouple: false,
            isInformational: true
        ),
        TutorialModule(
            id: 10,
            titleKey: "tutorial_m10_title",
            descriptionKey: "tutorial_m10_desc",
            tipKey: "tutorial_m10_tip",
            ctaKey: "tutorial_m10_cta",
            icon: "calendar",
            iconColorName: "teal",
            targetTab: "settings",
            requiresCouple: false,
            isInformational: true
        ),
        TutorialModule(
            id: 11,
            titleKey: "tutorial_m11_title",
            descriptionKey: "tutorial_m11_desc",
            tipKey: "tutorial_m11_tip",
            ctaKey: "tutorial_m11_cta",
            icon: "mic.fill",
            iconColorName: "teal",
            targetTab: "transactions",
            requiresCouple: false,
            isInformational: true
        ),
    ]

    /// Modulos visibles segun el contexto actual (couple mode o no).
    var visibleModules: [TutorialModule] {
        let mock = MockDataService.shared
        let hasPartner = (mock.mockCouple?.user2Name?.isEmpty == false)
        return allModules.filter { module in
            !module.requiresCouple || hasPartner
        }
    }

    // MARK: - Completion

    /// True si el modulo ya esta completado.
    /// Steps 1-7: derivado de los datos del MockDataService.
    /// Steps 8-11: leido de AppPreferences.tutorialInfoStepsViewed.
    func isCompleted(_ module: TutorialModule) -> Bool {
        let mock = MockDataService.shared
        switch module.id {
        case 1:
            return !mock.mockTransactions.isEmpty
        case 2:
            return mock.mockTransactions.contains { $0.isRecurring && $0.type == .expense }
        case 3:
            return mock.mockCouple?.user2Name?.isEmpty == false
        case 4:
            return mock.mockTransactions.contains { $0.isShared }
        case 5:
            return mock.mockSavingsGoals.contains { $0.status == .active }
        case 6:
            return mock.mockChallenges.contains { $0.status == .active || $0.status == .completed }
        case 7:
            return !mock.mockTrips.isEmpty
        case 8, 9, 10, 11:
            return AppPreferences.shared.tutorialInfoStepsViewed.contains(module.id)
        default:
            return false
        }
    }

    /// Cuantos modulos completados de los visibles.
    var completedCount: Int {
        visibleModules.filter { isCompleted($0) }.count
    }

    /// Total de modulos visibles.
    var totalCount: Int {
        visibleModules.count
    }

    /// Progreso 0.0-1.0
    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    /// Devuelve el siguiente modulo pendiente (el que esta en "Siguiente"), o nil si todo esta completo.
    var nextPendingModule: TutorialModule? {
        visibleModules.first { !isCompleted($0) }
    }

    // MARK: - Actions

    /// Marca un modulo informativo como visto y notifica al MainTabView para cambiar de pestaña.
    func handleCTA(for module: TutorialModule) {
        if module.isInformational {
            AppPreferences.shared.markTutorialInfoStepViewed(module.id)
        }
        NotificationCenter.default.post(
            name: .fingetherTutorialNavigateToTab,
            object: nil,
            userInfo: ["tab": module.targetTab]
        )
        // Forzar refresh de la lista cuando el usuario regrese
        refreshTick += 1
    }

    /// Forzar recalculo (llamado en .onAppear de la lista para ver progreso actualizado tras volver de otra tab).
    func refresh() {
        refreshTick += 1
    }

    // MARK: - Helpers (color resolution)

    func iconColor(for module: TutorialModule) -> Color {
        switch module.iconColorName {
        case "teal": return Color.fingetherPrimary
        case "rose": return Color.fingetherRose
        case "gold": return Color.fingetherWarning
        case "coral": return Color.fingetherExpense
        case "forest": return Color.fingetherForest
        default: return Color.fingetherPrimary
        }
    }
}
