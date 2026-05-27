import SwiftUI

struct SimulatorView: View {
    let coupleId: UUID

    @State private var viewModel = SimulatorViewModel()
    @State private var showForm = false
    @State private var preferences = AppPreferences.shared
    @State private var paywallFeature: PremiumFeature?  // P6
    private var lang: AppLanguage { preferences.language }

    private var isPremium: Bool {
        MockDataService.shared.mockProfile?.subscriptionTier == .premium
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerCard

                    // Scenario cards
                    scenarioGrid
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .trackCurrency()
            .navigationTitle(L10n.t("simulator_nav", lang))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showForm) {
                if viewModel.selectedType != nil {
                    simulationFormSheet
                }
            }
            .sheet(isPresented: $viewModel.showResult) {
                if let sim = viewModel.currentSimulation {
                    SimulationResultView(
                        simulation: sim,
                        affectedPartner: viewModel.formAffectedPartner
                    )
                }
            }
            .paywallGate($paywallFeature)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 36))
                .foregroundStyle(.white)

            Text(L10n.t("simulator_header", lang))
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(L10n.t("simulator_subtitle", lang))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
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

    // MARK: - Scenario Grid

    private var scenarioGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            ForEach(viewModel.scenarioCards) { card in
                Button {
                    // P6: financial simulator is premium-only
                    if isPremium {
                        viewModel.selectScenario(card.type)
                        showForm = true
                    } else {
                        paywallFeature = .financialSimulator
                    }
                } label: {
                    scenarioCardView(card)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func scenarioCardView(_ card: SimulatorViewModel.ScenarioCard) -> some View {
        VStack(spacing: 12) {
            Image(systemName: card.icon)
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    LinearGradient(
                        colors: card.gradientColors.map { Color(hex: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14)
                )

            Text(card.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.label))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(card.subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }

    // MARK: - Form Sheet

    private var simulationFormSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Monthly amount
                    formField(
                        label: monthlyLabel,
                        placeholder: "0",
                        text: $viewModel.formMonthlyAmount,
                        isCurrency: true
                    )

                    // Target amount (for emergency fund)
                    if viewModel.selectedType == .emergencyFund || viewModel.selectedType == .savingsProjection {
                        formField(
                            label: L10n.t("simulator_target_amount", lang),
                            placeholder: "0",
                            text: $viewModel.formTargetAmount,
                            isCurrency: true
                        )
                    }

                    // Interest rate (optional)
                    if viewModel.selectedType == .savingsProjection || viewModel.selectedType == .debtPayoff {
                        formField(
                            label: L10n.t("simulator_interest_rate", lang),
                            placeholder: "0",
                            text: $viewModel.formInterestRate,
                            isCurrency: false
                        )
                    }

                    // Affected Partner (couple mode only)
                    if preferences.isCoupleMode {
                        affectedPartnerSelector
                    }

                    // Months
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.t("simulator_period", lang))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        HStack {
                            Text("\(viewModel.formMonths) \(L10n.t("simulator_months", lang))")
                                .font(.system(.title3, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color(.label))

                            Spacer()

                            Stepper("", value: $viewModel.formMonths, in: 1...360, step: 1)
                                .labelsHidden()
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Quick month presets
                    HStack(spacing: 8) {
                        ForEach([3, 6, 12, 24, 36], id: \.self) { months in
                            Button {
                                viewModel.formMonths = months
                            } label: {
                                Text("\(months)m")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(viewModel.formMonths == months ? .white : Color(.label))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        viewModel.formMonths == months
                                            ? Color.fingetherPrimary
                                            : Color(.secondarySystemGroupedBackground),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Error
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.fingetherExpense)
                    }

                    // Run button
                    Button {
                        viewModel.runSimulation(coupleId: coupleId)
                        if viewModel.errorMessage == nil {
                            showForm = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text(L10n.t("simulator_run", lang))
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.fingetherPrimary, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(viewModel.isLoading)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(viewModel.selectedType?.displayName ?? L10n.t("simulator_simulation", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.t("cancel", lang)) { showForm = false }
                        .foregroundStyle(Color.fingetherPrimary)
                }
            }
        }
    }

    private func formField(label: String, placeholder: String, text: Binding<String>, isCurrency: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            HStack(spacing: 4) {
                if isCurrency {
                    Text("$")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.fingetherPrimary)
                }
                TextField(placeholder, text: text)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .keyboardType(.numberPad)
                    .onChange(of: text.wrappedValue) { _, val in
                        if isCurrency {
                            text.wrappedValue = formatWithThousands(val)
                        }
                    }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Affected Partner Selector (couple mode only)

    private var affectedPartnerSelector: some View {
        let mock = MockDataService.shared
        let n1 = mock.currentUser1Name
        let n2 = mock.currentUser2Name
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("💕")
                Text("¿A quién afecta?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            HStack(spacing: 8) {
                affectedPartnerChip(.both, label: "Ambos")
                affectedPartnerChip(.user1, label: n1)
                affectedPartnerChip(.user2, label: n2)
            }
        }
    }

    private func affectedPartnerChip(_ value: SimulatorViewModel.AffectedPartner, label: String) -> some View {
        let isSelected = viewModel.formAffectedPartner == value
        return Button {
            viewModel.formAffectedPartner = value
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : Color(.label))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    isSelected ? Color.fingetherRose : Color(.secondarySystemGroupedBackground),
                    in: Capsule()
                )
                .overlay(
                    Capsule().stroke(Color.fingetherRose.opacity(isSelected ? 0 : 0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var monthlyLabel: String {
        switch viewModel.selectedType {
        case .incomeIncrease:
            return L10n.t("simulator_increase", lang)
        case .expenseReduction:
            return L10n.t("simulator_reduction", lang)
        case .savingsProjection:
            return L10n.t("simulator_savings", lang)
        case .emergencyFund:
            return L10n.t("simulator_contribution", lang)
        case .debtPayoff:
            return L10n.t("simulator_payment", lang)
        case .none:
            return L10n.t("simulator_monthly_amount", lang)
        }
    }
}
