import SwiftUI

// MARK: - Premium Feature Catalog

/// Catalogo de features premium. Centraliza el "que esta bloqueado" para que el
/// resto de la app pregunte `PaywallGate.shared.requires(.x)`.
enum PremiumFeature: String, CaseIterable, Identifiable {
    case voiceInput
    case insightsUnlimited
    case unlimitedSavingsGoals
    case challenges
    case trips
    case financialSimulator
    case creditSimulatorAdvanced  // tabla de amortizacion + comparador
    case scoreBreakdown            // desglose + historial + graficas
    case calendarHistory           // meses anteriores
    case dataExport
    case shareableAchievements

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .voiceInput:                return "Input por voz"
        case .insightsUnlimited:         return "Insights IA ilimitados"
        case .unlimitedSavingsGoals:     return "Metas de ahorro ilimitadas"
        case .challenges:                return "Retos financieros"
        case .trips:                     return "Viajes con planificación"
        case .financialSimulator:        return "Simulador financiero"
        case .creditSimulatorAdvanced:   return "Tabla de amortización completa"
        case .scoreBreakdown:            return "Desglose del Score Fingether"
        case .calendarHistory:           return "Historial del calendario"
        case .dataExport:                return "Exportar datos"
        case .shareableAchievements:     return "Logros compartibles"
        }
    }

    var icon: String {
        switch self {
        case .voiceInput:                return "mic.fill"
        case .insightsUnlimited:         return "sparkles"
        case .unlimitedSavingsGoals:     return "target"
        case .challenges:                return "trophy.fill"
        case .trips:                     return "airplane"
        case .financialSimulator:        return "wand.and.stars"
        case .creditSimulatorAdvanced:   return "chart.bar.doc.horizontal"
        case .scoreBreakdown:            return "chart.line.uptrend.xyaxis"
        case .calendarHistory:           return "calendar"
        case .dataExport:                return "square.and.arrow.up"
        case .shareableAchievements:     return "trophy"
        }
    }
}

// MARK: - Paywall Gate

/// Singleton observable que sabe si el usuario es premium.
/// Lee de MockDataService.mockProfile.subscriptionTier.
@Observable
final class PaywallGate {
    static let shared = PaywallGate()
    private init() {}

    var isPremium: Bool {
        let mock = MockDataService.shared
        return mock.mockProfile?.subscriptionTier == .premium
    }

    /// True si la feature requiere paywall (usuario no es premium).
    func requires(_ feature: PremiumFeature) -> Bool {
        !isPremium
    }
}

// MARK: - Paywall Sheet

struct PaywallSheet: View {

    let triggerFeature: PremiumFeature
    var onDismiss: () -> Void = {}
    var onPurchase: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: Plan = .yearly

    enum Plan { case monthly, yearly }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerHero
                    triggerCard
                    featureList
                    planSelector
                    ctaButton
                    restoreButton
                    legalFooter
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDismiss()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private var headerHero: some View {
        VStack(spacing: 12) {
            Text("✨")
                .font(.system(size: 56))
            Text("Fingether Premium")
                .font(.title.bold())
                .foregroundStyle(Color(.label))
            Text("Desbloquea todo el potencial de Fingether en pareja")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Trigger Card

    private var triggerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: triggerFeature.icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(
                        colors: [Color.fingetherPrimary, Color.fingetherPrimaryDark],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(triggerFeature.displayName)
                    .font(.subheadline.weight(.semibold))
                Text("Requiere Fingether Premium")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.fingetherPrimary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.fingetherPrimary.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Feature List

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Lo que incluye Premium")
                .font(.headline)
                .foregroundStyle(Color(.label))

            VStack(alignment: .leading, spacing: 10) {
                ForEach(PremiumFeature.allCases) { feature in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.fingetherPrimary)
                        Text(feature.displayName)
                            .font(.subheadline)
                            .foregroundStyle(Color(.label))
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Plan Selector

    private var planSelector: some View {
        VStack(spacing: 10) {
            Text("Elige tu plan")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                planCard(
                    plan: .yearly,
                    title: "Anual",
                    price: "$39.99",
                    period: "/año",
                    badge: "Ahorra 33%"
                )
                planCard(
                    plan: .monthly,
                    title: "Mensual",
                    price: "$4.99",
                    period: "/mes",
                    badge: nil
                )
            }
        }
    }

    private func planCard(plan: Plan, title: String, price: String, period: String, badge: String?) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedPlan = plan }
        } label: {
            VStack(spacing: 6) {
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.fingetherExpense)
                        .clipShape(Capsule())
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.label))
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.title2.bold())
                        .foregroundStyle(Color(.label))
                    Text(period)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.fingetherPrimary.opacity(0.10) : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.fingetherPrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            onPurchase()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text("Probar Premium")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.fingetherPrimary, Color.fingetherPrimaryDark],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.fingetherPrimary.opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var restoreButton: some View {
        Button {
            // Hook for restore — for now just dismiss
            dismiss()
        } label: {
            Text("Restaurar compra")
                .font(.subheadline)
                .foregroundStyle(Color.fingetherPrimary)
        }
    }

    private var legalFooter: some View {
        Text("Al suscribirte aceptas los términos y la política de privacidad. La suscripción se renueva automáticamente.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }
}

// MARK: - View Modifier for paywall gating

extension View {
    /// Si la feature requiere paywall, presenta el sheet bloqueando el acceso.
    /// Uso: `.paywallGate(.voiceInput, isPresented: $showPaywall) { ... }`
    func paywallGate(_ feature: PremiumFeature, isPresented: Binding<Bool>) -> some View {
        self.sheet(isPresented: isPresented) {
            PaywallSheet(triggerFeature: feature)
        }
    }

    /// Variante con `Binding<PremiumFeature?>`. Permite mostrar distintos sheets
    /// para distintas features desde la misma vista.
    /// Uso: `.paywallGate($activeFeature)` con `@State var activeFeature: PremiumFeature?`
    func paywallGate(_ feature: Binding<PremiumFeature?>) -> some View {
        self.sheet(item: feature) { f in
            PaywallSheet(triggerFeature: f)
        }
    }
}
