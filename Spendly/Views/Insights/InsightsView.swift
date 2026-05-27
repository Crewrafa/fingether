import SwiftUI

struct InsightsView: View {
    let coupleId: UUID

    @State private var viewModel = InsightsViewModel()
    @State private var selectedType = "weekly"
    @State private var preferences = AppPreferences.shared
    @State private var paywallFeature: PremiumFeature?  // P6: insights gate
    private var isCoupleMode: Bool { preferences.isCoupleMode }

    private var isPremium: Bool {
        MockDataService.shared.mockProfile?.subscriptionTier == .premium
    }
    private var insightsRemaining: Int {
        MockDataService.shared.insightsRemainingThisMonth
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isCoupleMode {
                        coupleHeaderCard
                    }
                    if !isPremium {
                        freeTierCounter
                    }
                    insightTypePicker
                    currentInsightCard
                    cachedInsightsList
                }
                .padding()
            }
            .navigationTitle("Insights IA")
            .task {
                await viewModel.loadCachedInsights(coupleId: coupleId)
            }
            .paywallGate($paywallFeature)
        }
    }

    // MARK: - Free Tier Counter (P6)

    private var freeTierCounter: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.fingetherWarning)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Constants.FreeTierLimits.monthlyInsights - insightsRemaining) de \(Constants.FreeTierLimits.monthlyInsights) insights usados este mes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.label))
                Text("Desbloquea ilimitados con Premium")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                paywallFeature = .insightsUnlimited
            } label: {
                Text("Ver")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.fingetherPrimary)
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(Color.fingetherWarning.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.fingetherWarning.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Couple Header (only when isCoupleMode == true)

    private var coupleHeaderCard: some View {
        let mock = MockDataService.shared
        return HStack(spacing: 10) {
            Text("💕")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Insights de \(mock.currentUser1Name) & \(mock.currentUser2Name)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(.label))
                Text("Analizan los datos de los dos juntos")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.fingetherRose.opacity(0.45), lineWidth: 1.5)
        )
    }

    private var insightTypePicker: some View {
        HStack(spacing: 12) {
            ForEach(["weekly", "monthly", "custom"], id: \.self) { type in
                Button {
                    selectedType = type
                } label: {
                    Text(typeLabel(type))
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(selectedType == type ? Color.fingetherPrimary : Color(.systemGray6))
                        .foregroundStyle(selectedType == type ? .white : .primary)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var currentInsightCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.fingetherPrimary)
                Text("Insight de IA")
                    .font(.headline)
                Spacer()
            }

            if viewModel.isGenerating {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(isCoupleMode ? "Analizando las finanzas de los dos..." : "Analizando tus finanzas...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else if let insight = viewModel.currentInsight {
                Text(insight)
                    .font(.body)
                    .lineSpacing(4)
            } else {
                Text(isCoupleMode
                     ? "Genera un insight personalizado basado en los datos financieros de los dos."
                     : "Genera un insight personalizado basado en tus datos financieros.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }

            Button {
                // P6: contador free. Si se queda sin slots y no es premium → paywall.
                if MockDataService.shared.tryConsumeInsightSlot() {
                    Task {
                        await viewModel.generateInsight(coupleId: coupleId, type: selectedType)
                    }
                } else {
                    paywallFeature = .insightsUnlimited
                }
            } label: {
                Label("Generar Insight", systemImage: "wand.and.stars")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.fingetherPrimary, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .disabled(viewModel.isGenerating)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.fingetherDanger)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    private var cachedInsightsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.cachedInsights.isEmpty {
                Text("Insights anteriores")
                    .font(.headline)

                ForEach(viewModel.cachedInsights) { insight in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(typeLabel(insight.insightType))
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.fingetherPrimary.opacity(0.15), in: Capsule())
                            Spacer()
                            Text(insight.generatedAt.relativeTimeSpanish)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(insight.content)
                            .font(.subheadline)
                            .lineLimit(4)
                    }
                    .padding()
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func typeLabel(_ type: String) -> String {
        switch type {
        case "weekly": return "Semanal"
        case "monthly": return "Mensual"
        case "custom": return "Personalizado"
        default: return type.capitalized
        }
    }
}
