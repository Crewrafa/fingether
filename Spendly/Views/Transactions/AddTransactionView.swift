import SwiftUI

struct AddTransactionView: View {

    @Environment(\.dismiss) private var dismiss

    let coupleId: UUID
    let userId: UUID
    var editingTransaction: Transaction?

    @State private var viewModel = TransactionViewModel()
    @State private var preferences = AppPreferences.shared
    private var lang: AppLanguage { preferences.language }
    @State private var customSplitPercent: Double = 50
    @State private var onePaysPayer: UUID?
    @State private var selectedSplitCategory: SplitCategory = .equal
    @State private var paymentScope: PaymentScope = .me
    @State private var isAlreadyPaid = true
    @State private var selectedGoalId: UUID?
    @State private var goalContribution = ""
    @State private var showVoiceInput = false
    @State private var paywallFeature: PremiumFeature?  // P6: voice gate

    private var isEditing: Bool { editingTransaction != nil }

    private var accentColor: Color {
        viewModel.selectedType == .income ? Color.fingetherPrimary : Color.fingetherDanger
    }

    // Categories filtered by type
    private var expenseCategories: [TransactionCategory] {
        [.food, .transport, .housing, .utilities, .entertainment, .health, .education, .shopping, .travel, .gifts, .savings, .debt, .investments, .freelance, .other]
    }

    private var incomeCategories: [TransactionCategory] {
        [.salary, .freelance, .gifts, .investments, .other]
    }

    private var visibleCategories: [TransactionCategory] {
        viewModel.selectedType == .income ? incomeCategories : expenseCategories
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        errorBanner
                        typeSelector
                        amountHero
                        categoryGrid
                        descriptionField
                        dateSection
                        if viewModel.selectedType == .expense {
                            whoPaysSection
                        }
                        if viewModel.selectedType == .income {
                            savingsGoalsSection
                        }
                        recurringSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.interactively)

                // Bottom bar with save button
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 12) {
                        Button {
                            dismiss()
                        } label: {
                            Text(L10n.t("cancel", lang))
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(.secondarySystemGroupedBackground))
                                .foregroundStyle(Color(.label))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            saveTransaction()
                        } label: {
                            HStack(spacing: 8) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(viewModel.selectedType == .income ? L10n.t("addtx_save_income", lang) : L10n.t("addtx_save_expense", lang))
                                        .font(.subheadline.weight(.bold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                viewModel.amount.isEmpty
                                ? Color(.systemGray4)
                                : accentColor
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(viewModel.isLoading || viewModel.amount.isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(isEditing ? L10n.t("addtx_edit", lang) : (viewModel.selectedType == .income ? L10n.t("addtx_new_income", lang) : L10n.t("addtx_new_expense", lang)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                if !isEditing {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            // P6: gate voice input behind premium
                            if PaywallGate.shared.requires(.voiceInput) {
                                paywallFeature = .voiceInput
                            } else {
                                showVoiceInput = true
                            }
                        } label: {
                            Image(systemName: "mic.fill")
                                .foregroundStyle(Color.fingetherPrimary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showVoiceInput) {
                VoiceInputView(
                    onParsed: { parsed in
                        applyVoiceParsed(parsed)
                        showVoiceInput = false
                    },
                    onCancel: { showVoiceInput = false }
                )
                .presentationDetents([.medium, .large])
            }
            .paywallGate($paywallFeature)
            .onAppear {
                if let tx = editingTransaction {
                    viewModel.prepareForEditing(transaction: tx)
                    syncSplitTypeFromViewModel()
                }
            }
            .overlay {
                if viewModel.isLoading {
                    LoadingView(message: L10n.t("addtx_saving", lang))
                }
            }
        }
    }

    // MARK: - Save

    private func saveTransaction() {
        syncSplitTypeToViewModel()
        Task {
            if isEditing {
                await viewModel.updateTransaction()
            } else {
                // Bug fix #12: el owner de la transaccion (userId) SIEMPRE es el usuario actual.
                // Cuando el scope es "partner", la pareja es quien pago — pero el registro lo hace
                // el usuario actual. Marcamos la transaccion en notes para preservar la intencion
                // sin romper RLS (que requiere user_id == auth.uid()).
                if paymentScope == .partner {
                    let payerName = MockDataService.shared.currentUser2Name
                    let prefix = "[paid_by:\(payerName)]"
                    let existing = viewModel.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                    viewModel.notes = existing.isEmpty ? prefix : "\(prefix) \(existing)"
                }
                await viewModel.addTransaction(coupleId: coupleId, userId: userId)
                if paymentScope == .us && !isAlreadyPaid && viewModel.errorMessage == nil {
                    createDebtFromTransaction()
                }
            }
            if viewModel.errorMessage == nil {
                // Contribute to savings goal if selected
                if let goalId = selectedGoalId,
                   let contribution = Decimal(string: goalContribution.filter(\.isNumber)),
                   contribution > 0 {
                    MockDataService.shared.contributeMockToGoal(goalId: goalId, amount: contribution)
                }
                dismiss()
            }
        }
    }

    // MARK: - Error Banner

    @ViewBuilder
    private var errorBanner: some View {
        if let error = viewModel.errorMessage {
            ErrorBanner(message: error) {
                viewModel.errorMessage = nil
            }
        }
    }

    // MARK: - Type Selector

    private var typeSelector: some View {
        HStack(spacing: 12) {
            typeButton(type: .expense, emoji: "📉", label: L10n.t("addtx_expense", lang), color: Color.fingetherDanger)
            typeButton(type: .income, emoji: "📈", label: L10n.t("addtx_income", lang), color: Color.fingetherPrimary)
        }
    }

    private func typeButton(type: TransactionType, emoji: String, label: String, color: Color) -> some View {
        let isSelected = viewModel.selectedType == type
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedType = type
            }
        } label: {
            HStack(spacing: 8) {
                Text(emoji)
                    .font(.title3)
                Text(label)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSelected
                ? color
                : Color(.secondarySystemGroupedBackground)
            )
            .foregroundStyle(isSelected ? .white : Color(.label))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: isSelected ? color.opacity(0.3) : .black.opacity(0.04), radius: 6, y: 3)
        }
        .sensoryFeedback(.selection, trigger: viewModel.selectedType)
    }

    // MARK: - Amount Hero

    private var amountHero: some View {
        let isIncome = viewModel.selectedType == .income

        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
                Text(isIncome ? L10n.t("addtx_income", lang) : L10n.t("addtx_expense", lang))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentColor)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(AppPreferences.shared.currency.symbol)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)

                TextField("0", text: $viewModel.amount)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(.label))
                    .onChange(of: viewModel.amount) { _, newValue in
                        viewModel.amount = formatWithThousands(newValue)
                    }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.4)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentColor.opacity(0.2), lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedType)
    }

    // MARK: - Category Grid

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("addtx_category", lang))
                .font(.headline)
                .foregroundStyle(Color(.label))

            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(visibleCategories) { category in
                    categoryButton(category)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
        }
    }

    private func categoryButton(_ category: TransactionCategory) -> some View {
        let isSelected = viewModel.selectedCategory == category
        let categoryColor = Constants.categoryColors[category] ?? .gray

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.selectedCategory = category
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isSelected
                            ? categoryColor
                            : categoryColor.opacity(0.12)
                        )
                        .frame(height: 48)

                    Text(category.emoji)
                        .font(.title2)
                }

                Text(category.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? categoryColor : Color(.label))
                    .lineLimit(1)
            }
        }
        .sensoryFeedback(.selection, trigger: viewModel.selectedCategory)
    }

    // MARK: - Description Field

    private var descriptionField: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(Color.fingetherPrimary)
                    .frame(width: 20)
                TextField(L10n.t("addtx_desc_placeholder", lang), text: $viewModel.description)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

            HStack(spacing: 12) {
                Image(systemName: "note.text")
                    .foregroundStyle(Color.fingetherPrimary)
                    .frame(width: 20)
                TextField(L10n.t("addtx_notes_placeholder", lang), text: $viewModel.notes, axis: .vertical)
                    .lineLimit(2...4)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
    }

    // MARK: - Date Section

    private var dateSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .foregroundStyle(Color.fingetherPrimary)
                .frame(width: 20)
            DatePicker("Fecha", selection: $viewModel.selectedDate, displayedComponents: .date)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "es_MX"))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Who Pays Section (unified: Yo / Nosotros / Pareja)

    private var partnerDisplayName: String {
        MockDataService.shared.mockPartnerProfile?.displayName ?? "Pareja"
    }

    private var partnerId: UUID {
        MockDataService.shared.mockPartnerProfile?.id ?? UUID()
    }

    @ViewBuilder
    private var whoPaysSection: some View {
        if true { // coupleId is always present
            VStack(spacing: 12) {
                // 3-button selector
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.t("addtx_who_pays", lang))
                        .font(.headline)
                        .foregroundStyle(Color(.label))

                    HStack(spacing: 8) {
                        scopeButton(scope: .me, emoji: "🧑", label: L10n.t("addtx_me", lang), color: Color.fingetherPrimary)
                        scopeButton(scope: .us, emoji: "💕", label: L10n.t("addtx_us", lang), color: Color.fingetherRose)
                        scopeButton(scope: .partner, emoji: "👩", label: partnerDisplayName, color: Color.fingetherDanger)
                    }
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

                // When "Nosotros" is selected — show split + payment status
                if paymentScope == .us {
                    // P7: warning si la moneda del usuario es distinta a la de la pareja
                    multiCurrencyWarningIfNeeded

                    // Split type (auto-selects default)
                    splitTypeSection
                        .transition(.move(edge: .top).combined(with: .opacity))

                    // Paid or debt?
                    paymentStatusSection
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    // P7: warning sutil cuando la moneda del usuario y la de la pareja difieren.
    // No hay conversion automatica — solo informa al usuario que el total compartido
    // se mostrara en la moneda de pareja (definida como la moneda de partner1).
    @ViewBuilder
    private var multiCurrencyWarningIfNeeded: some View {
        let mock = MockDataService.shared
        let userCurrency = mock.mockProfile?.currency ?? AppPreferences.shared.currency.rawValue
        let partnerCurrency = mock.mockPartnerProfile?.currency
        if let pCur = partnerCurrency, !pCur.isEmpty, pCur != userCurrency {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.fingetherWarning)
                Text("Tu moneda personal (\(userCurrency)) es diferente a la de pareja (\(pCur)). Los totales compartidos se mostrarán en \(pCur).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(Color.fingetherWarning.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.fingetherWarning.opacity(0.4), lineWidth: 1)
            )
        }
    }

    private func scopeButton(scope: PaymentScope, emoji: String, label: String, color: Color) -> some View {
        let isSelected = paymentScope == scope
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                paymentScope = scope
                applyScope()
            }
        } label: {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.title3)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? color : Color(.systemGroupedBackground))
            .foregroundStyle(isSelected ? .white : Color(.label))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .sensoryFeedback(.selection, trigger: paymentScope)
    }

    private func applyScope() {
        switch paymentScope {
        case .me:
            viewModel.isShared = false
            viewModel.splitType = nil
            onePaysPayer = userId
        case .us:
            viewModel.isShared = true
            // Auto-apply couple's default split
            let defaultSplit = MockDataService.shared.coupleSettings.defaultSplitType
            viewModel.splitType = defaultSplit
            syncSplitCategoryFromType(defaultSplit)
            onePaysPayer = userId
        case .partner:
            viewModel.isShared = false
            viewModel.splitType = nil
            onePaysPayer = partnerId
        }
    }

    private func syncSplitCategoryFromType(_ splitType: SplitType) {
        switch splitType {
        case .equal: selectedSplitCategory = .equal
        case .proportional: selectedSplitCategory = .proportional
        case .custom(let pct):
            selectedSplitCategory = .custom
            customSplitPercent = Double(pct)
        case .onePays:
            selectedSplitCategory = .onePays
        }
    }

    // MARK: - Split Type (when "Nosotros")

    private var splitTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("addtx_split_how", lang))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                splitButton(category: .equal, emoji: "⚖️", label: "50/50")
                splitButton(category: .proportional, emoji: "📊", label: L10n.t("addtx_proportional", lang))
                splitButton(category: .custom, emoji: "✂️", label: "Custom %")
                splitButton(category: .onePays, emoji: "💳", label: L10n.t("addtx_one_pays", lang))
            }

            if case .custom = selectedSplitCategory {
                HStack {
                    Text(L10n.t("addtx_your_share", lang))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(customSplitPercent))% / \(100 - Int(customSplitPercent))%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.fingetherRose)
                }
                Slider(value: $customSplitPercent, in: 0...100, step: 5)
                    .tint(Color.fingetherRose)
                    .onChange(of: customSplitPercent) { syncSplitTypeToViewModel() }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    private func splitButton(category: SplitCategory, emoji: String, label: String) -> some View {
        let isSelected = selectedSplitCategory == category
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSplitCategory = category
                syncSplitTypeToViewModel()
            }
        } label: {
            HStack(spacing: 4) {
                Text(emoji)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.fingetherRose : Color(.systemGroupedBackground))
            .foregroundStyle(isSelected ? .white : Color(.label))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Payment Status (paid or debt)

    private var paymentStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("addtx_payment_status", lang))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    withAnimation { isAlreadyPaid = true }
                } label: {
                    HStack(spacing: 6) {
                        Text("✅")
                        Text(L10n.t("addtx_already_paid", lang))
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isAlreadyPaid ? Color.fingetherPrimary : Color(.systemGroupedBackground))
                    .foregroundStyle(isAlreadyPaid ? .white : Color(.label))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    withAnimation { isAlreadyPaid = false }
                } label: {
                    HStack(spacing: 6) {
                        Text("📝")
                        Text(L10n.t("addtx_as_debt", lang))
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(!isAlreadyPaid ? Color.fingetherDanger : Color(.systemGroupedBackground))
                    .foregroundStyle(!isAlreadyPaid ? .white : Color(.label))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            if !isAlreadyPaid {
                Text(L10n.t("addtx_debt_note", lang))
                    .font(.caption2)
                    .foregroundStyle(Color.fingetherDanger)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Savings Goals Section (shown on income)

    private var activeGoals: [SavingsGoal] {
        MockDataService.shared.mockSavingsGoals.filter { $0.status == .active }
    }

    private var savingsGoalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !activeGoals.isEmpty {
                Text(L10n.t("addtx_goal_question", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.label))

                ForEach(activeGoals) { goal in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedGoalId = selectedGoalId == goal.id ? nil : goal.id
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text(goal.emoji)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(goal.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color(.label))
                                ProgressView(value: goal.progress)
                                    .tint(Color.fingetherAmber)
                                Text("\(goal.currentAmount.currencyFormatted) / \(goal.targetAmount.currencyFormatted)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                            }

                            Spacer()

                            Image(systemName: selectedGoalId == goal.id ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedGoalId == goal.id ? Color.fingetherAmber : .secondary)
                                .font(.title3)
                        }
                        .padding(12)
                        .background(selectedGoalId == goal.id ? Color.fingetherAmber.opacity(0.1) : Color(.systemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedGoalId == goal.id ? Color.fingetherAmber : .clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if selectedGoalId != nil {
                    HStack {
                        Text(AppPreferences.shared.currency.symbol)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.fingetherAmber)
                        TextField(L10n.t("addtx_goal_amount", lang), text: $goalContribution)
                            .font(.subheadline.bold())
                            .keyboardType(.numberPad)
                            .onChange(of: goalContribution) { _, val in
                                goalContribution = formatWithThousands(val)
                            }
                    }
                    .padding(12)
                    .background(Color(.systemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Recurring Section

    private var recurringSection: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $viewModel.isRecurring.animation(.easeInOut)) {
                HStack(spacing: 8) {
                    Text("🔄")
                    Text(viewModel.selectedType == .income ? L10n.t("addtx_recurring_income", lang) : L10n.t("addtx_recurring_expense", lang))
                        .font(.subheadline)
                }
            }
            .tint(Color.fingetherPrimary)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

            if viewModel.isRecurring {
                // P5: banner clarificador — el usuario debe entender que un gasto recurrente
                // tambien aparece en la pestaña Fijos como checklist mensual.
                HStack(alignment: .top, spacing: 8) {
                    Text("💡")
                        .font(.caption)
                    Text("Los gastos recurrentes también aparecen en tu pestaña de Fijos como checklist mensual.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(Color.fingetherWarning.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.fingetherWarning.opacity(0.4), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("addtx_frequency", lang))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(.label))

                    HStack(spacing: 8) {
                        ForEach(RecurringFrequency.allCases) { frequency in
                            Button {
                                viewModel.recurringFrequency = frequency
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: frequency.iconName)
                                        .font(.caption)
                                    Text(frequency.displayName)
                                        .font(.system(size: 10))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    viewModel.recurringFrequency == frequency
                                    ? Color.fingetherPrimary
                                    : Color(.systemGroupedBackground)
                                )
                                .foregroundStyle(
                                    viewModel.recurringFrequency == frequency ? .white : .secondary
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Voice Input

    private func applyVoiceParsed(_ parsed: ParsedExpense) {
        if let amount = parsed.amount {
            let intAmount = Int(NSDecimalNumber(decimal: amount).doubleValue.rounded())
            viewModel.amount = formatWithThousands("\(intAmount)")
        }
        if let merchant = parsed.merchant {
            viewModel.description = merchant.sanitizedText
        }
        if let category = parsed.category {
            viewModel.selectedCategory = category
        }
        viewModel.selectedType = .expense
    }

    // formatWithThousands is now a global function in Extensions.swift

    // MARK: - Debt Creation

    private func createDebtFromTransaction() {
        // Parse amount by extracting only digits (formatWithThousands uses dots as thousand separators)
        let digits = viewModel.amount.filter(\.isNumber)
        guard let amount = Decimal(string: digits), amount > 0 else { return }

        // Bug fix #6: usar splitFor de MockDataService para obtener la parte exacta
        // de la pareja segun el split type real (antes hardcodeaba 45/100 para .proportional).
        let split = viewModel.splitType ?? .equal
        let parts = MockDataService.shared.splitFor(amount: amount, splitType: split)
        // user1 = devUserId; user2 = partner. La porcion que paga la pareja es user2.
        let partnerShare: Decimal = parts.user2

        guard partnerShare > 0 else { return }

        // Whoever paid is owed by the other
        let payerIsMe = onePaysPayer == nil || onePaysPayer == userId
        let debt = Debt(
            id: UUID(),
            coupleId: coupleId,
            fromUserId: payerIsMe ? partnerId : userId,
            toUserId: payerIsMe ? userId : partnerId,
            concept: viewModel.description.isEmpty ? viewModel.selectedCategory.displayName : viewModel.description,
            amount: partnerShare,
            isPaid: false,
            paidAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        _ = MockDataService.shared.addMockDebt(debt)
    }

    // MARK: - Split Type Helpers

    private func syncSplitTypeToViewModel() {
        guard viewModel.isShared else {
            viewModel.splitType = nil
            return
        }
        switch selectedSplitCategory {
        case .equal:
            viewModel.splitType = .equal
        case .proportional:
            viewModel.splitType = .proportional
        case .custom:
            viewModel.splitType = .custom(Int(customSplitPercent))
        case .onePays:
            viewModel.splitType = .onePays(onePaysPayer ?? userId)
        }
    }

    private func syncSplitTypeFromViewModel() {
        guard let split = viewModel.splitType else {
            selectedSplitCategory = .equal
            return
        }
        switch split {
        case .equal:
            selectedSplitCategory = .equal
        case .proportional:
            selectedSplitCategory = .proportional
        case .custom(let pct):
            selectedSplitCategory = .custom
            customSplitPercent = Double(pct)
        case .onePays(let payerId):
            selectedSplitCategory = .onePays
            onePaysPayer = payerId
        }
    }
}

// MARK: - Split Category (local selection enum)

private enum SplitCategory: String, CaseIterable, Equatable {
    case equal
    case proportional
    case custom
    case onePays
}

private enum PaymentScope: String, Equatable {
    case me       // Solo yo pago — gasto individual mio
    case us       // Nosotros — gasto compartido con split
    case partner  // Solo pareja — gasto individual de la pareja
}
