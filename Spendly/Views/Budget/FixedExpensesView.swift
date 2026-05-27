import SwiftUI

struct FixedExpensesView: View {

    let userId: UUID
    let coupleId: UUID?

    @State private var items: [Transaction] = []
    @State private var monthIncome: Decimal = 0
    @State private var selectedMonth = Date()
    @State private var preferences = AppPreferences.shared
    @State private var mockData = MockDataService.shared

    // Form
    @State private var showForm = false
    @State private var formAmount = ""
    @State private var formDesc = ""
    @State private var formCategory: TransactionCategory = .housing
    @State private var formIsShared = false
    @State private var formIsIncome = false
    @State private var formIsCoupleContribution = false

    // Budget editor
    @State private var showBudgetEditor = false
    @State private var budgetEditorText = ""

    // Bug fix #5: paidKeys persiste en MockDataService.shared.paidFixedKeys
    // para sobrevivir cierres y reaperturas de la vista. Antes era @State local.

    private var isCoupleMode: Bool { preferences.isCoupleMode && coupleId != nil }

    private var tealColor: Color { Color.fingetherPrimary }
    private var expenseColor: Color { Color.fingetherExpense }
    private var redColor: Color { Color.fingetherDanger }
    private var individualColor: Color { Color.fingetherSky }
    private var sharedColor: Color { Color.fingetherRose }
    private var modeColor: Color { isCoupleMode ? tealColor : individualColor }
    private var modeBorderColor: Color { isCoupleMode ? tealColor : individualColor }

    // MARK: - Effective Amount

    /// In couple mode shows full amount; in individual mode shows user's split portion
    private func effectiveAmount(for tx: Transaction) -> Decimal {
        if isCoupleMode {
            return tx.amount
        }
        // Individual mode: show my portion
        guard tx.isShared else { return tx.amount }

        // Use pre-calculated split amounts if available
        let isUser1 = tx.userId == mockData.mockCouple?.partner1Id || userId == mockData.mockCouple?.partner1Id
        if isUser1, let amount = tx.splitUser1Amount {
            return amount
        }
        if !isUser1, let amount = tx.splitUser2Amount {
            return amount
        }

        // Fallback to splitType calculation
        switch tx.splitType ?? .equal {
        case .equal:
            return tx.amount / 2
        case .custom(let pct):
            let myPct = isUser1 ? pct : (100 - pct)
            return tx.amount * Decimal(myPct) / 100
        case .onePays(let payerId):
            return payerId == userId ? tx.amount : 0
        case .proportional:
            return tx.amount / 2
        }
    }

    private var fixedExpenses: [Transaction] { items.filter { $0.type == .expense } }
    private var fixedIncome: [Transaction] { items.filter { $0.type == .income } }

    private var totalExpenses: Decimal {
        fixedExpenses.reduce(Decimal.zero) { $0 + effectiveAmount(for: $1) }
    }

    private var totalFixedIncome: Decimal {
        fixedIncome.reduce(Decimal.zero) { $0 + effectiveAmount(for: $1) }
    }

    // Reference = raw income (couple: combined, individual: user1).
    // Available = income - totalExpenses (from displayed items).
    private var referenceAmount: Decimal {
        let mode: BudgetMode = isCoupleMode ? .couple : .individual
        let calc = BudgetCalculator.calculate(for: mode)
        return calc.totalIncome
    }

    private var availableAmount: Decimal {
        referenceAmount - totalExpenses
    }

    private var percentUsed: Double {
        guard referenceAmount > 0 else { return 0 }
        return min(NSDecimalNumber(decimal: totalExpenses / referenceAmount).doubleValue * 100, 100)
    }

    // MARK: - Paid Tracking

    private func paidKey(for tx: Transaction) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: selectedMonth)
        return "\(tx.id)-\(comps.year ?? 0)-\(comps.month ?? 0)"
    }

    private func isPaid(_ tx: Transaction) -> Bool {
        MockDataService.shared.isFixedPaid(paidKey(for: tx))
    }

    private func togglePaid(_ tx: Transaction) {
        let key = paidKey(for: tx)
        let wasPaid = MockDataService.shared.isFixedPaid(key)
        MockDataService.shared.togglePaidFixed(key)

        // If this is a trip contribution, update trip progress
        if let notes = tx.notes, notes.hasPrefix("trip_contribution_") {
            let tripIdStr = String(notes.dropFirst("trip_contribution_".count))
            if let tripId = UUID(uuidString: tripIdStr) {
                let mock = MockDataService.shared
                if let idx = mock.mockTrips.firstIndex(where: { $0.id == tripId }) {
                    let amount = effectiveAmount(for: tx)
                    if wasPaid {
                        mock.mockTrips[idx].currentSaved -= amount
                    } else {
                        mock.mockTrips[idx].currentSaved += amount
                    }
                }
            }
        }
    }

    // Checklist sections
    private var pendingIncome: [Transaction] {
        fixedIncome.filter { !isPaid($0) }
    }
    private var receivedIncome: [Transaction] {
        fixedIncome.filter { isPaid($0) }
    }
    private var pendingExpenses: [Transaction] {
        fixedExpenses.filter { !isPaid($0) }
    }
    private var paidExpenses: [Transaction] {
        fixedExpenses.filter { isPaid($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 16) {
                        headerRow
                        // P5: subtitulo clarificador "Pagos que se repiten cada mes"
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.caption2)
                            Text("Pagos que se repiten cada mes")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        summaryCard
                        progressBar

                        if !fixedIncome.isEmpty {
                            checklistSection(
                                pendingTitle: "Por recibir",
                                doneTitle: "Recibidos",
                                pending: pendingIncome,
                                done: receivedIncome,
                                color: tealColor,
                                isIncome: true
                            )
                        }

                        if !fixedExpenses.isEmpty {
                            checklistSection(
                                pendingTitle: "Por pagar",
                                doneTitle: "Pagados",
                                pending: pendingExpenses,
                                done: paidExpenses,
                                color: expenseColor,
                                isIncome: false
                            )
                        }

                        if items.isEmpty {
                            VStack(spacing: 12) {
                                Text("📌").font(.system(size: 44))
                                Text(L10n.t("fixed_empty_title", preferences.language))
                                    .font(.subheadline.weight(.medium))
                                Text(L10n.t("fixed_empty_subtitle", preferences.language))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 90)
                }

                // FAB
                Button {
                    showForm = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(
                                colors: [expenseColor, redColor],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: expenseColor.opacity(0.4), radius: 10, y: 5)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .trackCurrency()
            .navigationTitle(isCoupleMode
                ? L10n.t("fixed_title_couple", preferences.language)
                : L10n.t("fixed_title_mine", preferences.language))
            .navigationBarTitleDisplayMode(.large)
            .onAppear { reload() }
            .sheet(isPresented: $showForm, onDismiss: { reload() }) {
                fixedFormSheet
            }
            .sheet(isPresented: $showBudgetEditor) {
                budgetEditorSheet
            }
        }
    }

    // MARK: - Header Row (mode pill + month selector on same line)

    private var headerRow: some View {
        HStack {
            if coupleId != nil {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        preferences.isCoupleMode.toggle()
                    }
                    reload()
                } label: {
                    HStack(spacing: 6) {
                        Text(isCoupleMode ? "💕" : "👤")
                            .font(.caption)
                        Text(isCoupleMode
                            ? L10n.t("mode_couple", preferences.language)
                            : L10n.t("mode_individual", preferences.language))
                            .font(.caption.weight(.semibold))
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(modeColor.opacity(0.15))
                    .foregroundStyle(modeColor)
                    .clipShape(Capsule())
                }
                .sensoryFeedback(.selection, trigger: isCoupleMode)
            }

            Spacer()

            HStack(spacing: 12) {
                Button { changeMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(expenseColor)
                }

                Text(selectedMonth.formattedMonth.capitalizedFirst)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.interpolate)

                Button { changeMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(expenseColor)
                }
            }
        }
    }

    // MARK: - Summary Card (compact 3-column)

    private var summaryCard: some View {
        HStack(spacing: 0) {
            // Column 1: Income / Budget
            VStack(spacing: 4) {
                Text(isCoupleMode
                    ? L10n.t("fixed_budget", preferences.language)
                    : L10n.t("fixed_income", preferences.language))
                    .font(.caption2).foregroundStyle(.white.opacity(0.7))
                if isCoupleMode && (mockData.mockCouple?.coupleMonthlyBudget == nil) {
                    Button {
                        showBudgetEditor = true
                    } label: {
                        Text(L10n.t("fixed_define", preferences.language))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .underline()
                    }
                } else {
                    Text(referenceAmount.currencyFormatted)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.5)
                }
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 36)

            // Column 2: Fixed Expenses
            VStack(spacing: 4) {
                Text(L10n.t("fixed_expenses", preferences.language))
                    .font(.caption2).foregroundStyle(.white.opacity(0.7))
                Text(totalExpenses.currencyFormatted)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 36)

            // Column 3: Available
            VStack(spacing: 4) {
                Text(L10n.t("fixed_available", preferences.language))
                    .font(.caption2).foregroundStyle(.white.opacity(0.7))
                Text(referenceAmount > 0 ? availableAmount.currencyFormatted : "—")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: isCoupleMode
                    ? [tealColor, Color.fingetherPrimaryDark]
                    : [individualColor, Color(hex: "A29BFE")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(modeBorderColor.opacity(0.3), lineWidth: 2)
        )
    }

    // MARK: - Progress Bar (20px, gradient zones)

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("📊 " + L10n.t("fixed_vs_income", preferences.language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(referenceAmount > 0 ? "\(Int(percentUsed))%" : "—")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(percentColorForValue(percentUsed))
            }

            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    // Background with zone colors
                    HStack(spacing: 0) {
                        Rectangle().fill(Color.green.opacity(0.15))
                            .frame(width: w * 0.3)
                        Rectangle().fill(Color.yellow.opacity(0.15))
                            .frame(width: w * 0.2)
                        Rectangle().fill(Color.orange.opacity(0.15))
                            .frame(width: w * 0.2)
                        Rectangle().fill(Color.fingetherDanger.opacity(0.15))
                            .frame(width: w * 0.3)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .frame(height: 20)

                    // Filled bar
                    RoundedRectangle(cornerRadius: 10)
                        .fill(percentColorForValue(percentUsed))
                        .frame(width: max(CGFloat(percentUsed / 100) * w, 2), height: 20)
                        .animation(.easeInOut(duration: 0.3), value: percentUsed)
                }
            }
            .frame(height: 20)

            // Zone labels
            HStack {
                Text("<30%").font(.system(size: 8)).foregroundStyle(.green)
                Spacer()
                Text("30-50%").font(.system(size: 8)).foregroundStyle(.yellow)
                Spacer()
                Text("50-70%").font(.system(size: 8)).foregroundStyle(.orange)
                Spacer()
                Text(">70%").font(.system(size: 8)).foregroundStyle(Color.fingetherDanger)
            }

            // Status message
            Text(statusMessage)
                .font(.caption2)
                .foregroundStyle(percentColorForValue(percentUsed))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func percentColorForValue(_ pct: Double) -> Color {
        if pct < 30 { return .green }
        if pct < 50 { return .yellow }
        if pct < 70 { return .orange }
        return Color.fingetherDanger
    }

    private var statusMessage: String {
        guard referenceAmount > 0 else {
            return L10n.t("fixed_add_income_hint", preferences.language)
        }
        if percentUsed < 30 {
            return "✅ " + L10n.t("fixed_status_good", preferences.language)
        } else if percentUsed < 50 {
            return "⚠️ " + L10n.t("fixed_status_caution", preferences.language)
        } else if percentUsed < 70 {
            return "🟠 " + L10n.t("fixed_status_warning", preferences.language)
        } else {
            return "🔴 " + L10n.t("fixed_status_alert", preferences.language)
        }
    }

    // MARK: - Checklist Section

    private func checklistSection(
        pendingTitle: String,
        doneTitle: String,
        pending: [Transaction],
        done: [Transaction],
        color: Color,
        isIncome: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !pending.isEmpty {
                HStack {
                    Text(isIncome ? "📈" : "📉")
                    Text(pendingTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    let total = pending.reduce(Decimal.zero) { $0 + effectiveAmount(for: $1) }
                    Text(total.currencyFormatted)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color)
                        .lineLimit(1).minimumScaleFactor(0.5)
                }

                ForEach(Array(pending.enumerated()), id: \.element.id) { index, tx in
                    checklistRow(tx: tx, color: color)
                    if index < pending.count - 1 {
                        Divider().padding(.leading, 40)
                    }
                }
            }

            if !done.isEmpty {
                if !pending.isEmpty {
                    Divider().padding(.vertical, 4)
                }
                HStack {
                    Text("✅")
                    Text(doneTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    let total = done.reduce(Decimal.zero) { $0 + effectiveAmount(for: $1) }
                    Text(total.currencyFormatted)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.5)
                }

                ForEach(Array(done.enumerated()), id: \.element.id) { index, tx in
                    checklistRow(tx: tx, color: color)
                    if index < done.count - 1 {
                        Divider().padding(.leading, 40)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func checklistRow(tx: Transaction, color: Color) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { togglePaid(tx) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isPaid(tx) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isPaid(tx) ? tealColor : .secondary)
                    .font(.title3)

                Text(tx.category.emoji)
                    .font(.title3)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tx.description.isEmpty ? tx.category.displayName : tx.description)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isPaid(tx) ? Color(.secondaryLabel) : Color(.label))
                        .strikethrough(isPaid(tx))
                        .lineLimit(1)
                    if tx.isShared && isCoupleMode {
                        Text("💕 Compartido")
                            .font(.caption2).foregroundStyle(sharedColor)
                        let split = mockData.splitFor(amount: tx.amount, splitType: tx.splitType ?? mockData.coupleSettings.defaultSplitType)
                        let myName = mockData.currentUser1Name
                        let partnerN = mockData.currentUser2Name
                        Text("\(myName): \(split.user1.currencyFormatted) | \(partnerN): \(split.user2.currencyFormatted)")
                            .font(.system(size: 9)).foregroundStyle(.secondary)
                    } else if tx.isShared {
                        Text("💕 Mi parte")
                            .font(.caption2).foregroundStyle(sharedColor)
                    } else if isCoupleMode && tx.userId != userId {
                        Text("👤 \(mockData.currentUser2Name)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(effectiveAmount(for: tx).currencyFormatted)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(isPaid(tx) ? Color(.secondaryLabel) : color)
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: MockDataService.shared.paidFixedKeys.count)
    }

    // MARK: - Form Sheet

    private var fixedFormSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    formView
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(L10n.t("fixed_new", preferences.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showForm = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Budget Editor Sheet

    // v1.4: Budget editor now shows smart auto-calculated budget (same as Dashboard)
    private var budgetEditorSheet: some View {
        let mode: BudgetMode = isCoupleMode ? .couple : .individual
        let calc = BudgetCalculator.calculate(for: mode)

        return NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("📊").font(.system(size: 48))
                    Text("Presupuesto inteligente")
                        .font(.headline)

                    // Breakdown
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("💰 Ingresos").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Text(calc.totalIncome.currencyFormatted)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.fingetherIncome)
                        }
                        Divider()
                        HStack {
                            Text("📌 Gastos fijos").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Text((-calc.totalFixedExpenses).currencyFormatted)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.fingetherExpense)
                        }
                        Divider()
                        HStack {
                            Text("Disponible")
                                .font(.subheadline.weight(.bold))
                            Spacer()
                            Text(calc.calculatedAvailable.currencyFormatted)
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(tealColor)
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Limit toggle
                    VStack(spacing: 12) {
                        Toggle(isOn: Binding(
                            get: { mockData.budgetLimitEnabled },
                            set: { val in
                                mockData.budgetLimitEnabled = val
                                if val && mockData.userBudgetLimit == nil {
                                    mockData.userBudgetLimit = calc.calculatedAvailable * 8 / 10
                                }
                                mockData.saveAll()
                            }
                        )) {
                            Text("Poner límite de gasto")
                                .font(.subheadline.weight(.semibold))
                        }
                        .tint(tealColor)

                        if mockData.budgetLimitEnabled, calc.calculatedAvailable > 0 {
                            let savings = calc.calculatedAvailable - (mockData.userBudgetLimit ?? calc.calculatedAvailable)
                            if savings > 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "leaf.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.fingetherIncome)
                                    Text("Ahorro: \(savings.currencyFormatted)/mes")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.fingetherIncome)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    Spacer()
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Presupuesto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        mockData.mockCouple?.coupleMonthlyBudget = calc.effectiveBudget
                        showBudgetEditor = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(tealColor)
                }
            }
        }
    }

    // MARK: - Reload

    private func reload() {
        let cal = Calendar.current
        let selectedComps = cal.dateComponents([.year, .month], from: selectedMonth)
        let endOfSelected = cal.date(from: DateComponents(year: selectedComps.year, month: (selectedComps.month ?? 1) + 1, day: 0)) ?? selectedMonth

        // Fixed items: filter by mode
        // Couple mode: only shared (isShared == true)
        // Individual mode: personal (isShared == false) + shared items (shown with effectiveAmount)
        let allRecurring = MockDataService.shared.mockTransactions
            .filter { tx in
                guard tx.isRecurring else { return false }
                return tx.createdAt <= endOfSelected
            }

        if isCoupleMode {
            // Couple mode: ALL recurring items (both partners, shared + personal)
            items = allRecurring
                .sorted { $0.amount > $1.amount }
        } else {
            // Individual mode: only my items + shared items (shown with effectiveAmount)
            items = allRecurring
                .filter { $0.userId == userId || $0.isShared }
                .sorted { $0.amount > $1.amount }
        }

        // Income calculation based on mode
        let allTx = MockDataService.shared.mockTransactions
        if isCoupleMode {
            // Couple mode: ALL income (both partners)
            let allRecurringIncome = allRecurring.filter { $0.type == .income }
            monthIncome = allRecurringIncome.reduce(Decimal.zero) { $0 + $1.amount }
        } else {
            // Individual mode: personal income + my share of shared income
            let nonRecurringIncome = allTx.filter {
                let tc = cal.dateComponents([.year, .month], from: $0.date)
                return tc.year == selectedComps.year && tc.month == selectedComps.month && $0.type == .income && !$0.isRecurring
            }
            let recurringIncome = allRecurring.filter { $0.type == .income }
            monthIncome = nonRecurringIncome.reduce(Decimal.zero) { $0 + effectiveAmount(for: $1) }
                + recurringIncome.reduce(Decimal.zero) { $0 + effectiveAmount(for: $1) }
        }
    }

    private func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newDate
            reload()
        }
    }

    // MARK: - Inline Form

    private var formAccentColor: Color {
        formIsIncome ? tealColor : expenseColor
    }

    private var formView: some View {
        VStack(spacing: 16) {
            // Type selector
            HStack(spacing: 12) {
                formTypeButton(isIncome: false, emoji: "📉", label: L10n.t("expense", preferences.language), color: redColor)
                formTypeButton(isIncome: true, emoji: "📈", label: L10n.t("income", preferences.language), color: tealColor)
            }

            // Amount hero
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle().fill(formAccentColor).frame(width: 8, height: 8)
                    Text(formIsIncome ? L10n.t("fixed_income_label", preferences.language) : L10n.t("fixed_expense_label", preferences.language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(formAccentColor)
                }

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(AppPreferences.shared.currency.symbol)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(formAccentColor)
                    TextField("0", text: $formAmount)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(.label))
                        .onChange(of: formAmount) { _, val in
                            formAmount = formatWithThousands(val)
                        }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(formAccentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(formAccentColor.opacity(0.2), lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.2), value: formIsIncome)

            // Category grid
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.t("category", preferences.language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.label))

                let cats: [TransactionCategory] = formIsIncome
                    ? [.salary, .freelance, .investments, .other]
                    : [.housing, .utilities, .entertainment, .health, .education, .transport, .food, .debt, .other]
                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(cats, id: \.self) { cat in
                        Button { withAnimation(.easeInOut(duration: 0.15)) { formCategory = cat } } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(formCategory == cat
                                            ? (Constants.categoryColors[cat] ?? .gray)
                                            : (Constants.categoryColors[cat] ?? .gray).opacity(0.12))
                                        .frame(height: 42)
                                    Text(cat.emoji).font(.title3)
                                }
                                Text(cat.displayName)
                                    .font(.system(size: 10, weight: formCategory == cat ? .semibold : .regular))
                                    .foregroundStyle(formCategory == cat ? (Constants.categoryColors[cat] ?? .gray) : Color(.label))
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.selection, trigger: formCategory)
                    }
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Description
            HStack(spacing: 10) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(formAccentColor)
                    .frame(width: 20)
                TextField(L10n.t("fixed_desc_placeholder", preferences.language), text: $formDesc)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Shared toggle
            if coupleId != nil && !formIsIncome {
                Toggle(isOn: $formIsShared.animation(.easeInOut)) {
                    HStack(spacing: 8) {
                        Text(formIsShared ? "💕" : "🧑")
                        VStack(alignment: .leading, spacing: 1) {
                            Text(formIsShared ? L10n.t("fixed_shared", preferences.language) : L10n.t("fixed_personal", preferences.language))
                                .font(.subheadline)
                            Text(formIsShared ? L10n.t("fixed_shared_desc", preferences.language) : L10n.t("fixed_personal_desc", preferences.language))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(sharedColor)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Couple contribution toggle
            if coupleId != nil && formIsIncome {
                Toggle(isOn: $formIsCoupleContribution.animation(.easeInOut)) {
                    HStack(spacing: 8) {
                        Text(formIsCoupleContribution ? "💕" : "🧑")
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L10n.t("fixed_couple_contribution", preferences.language))
                                .font(.subheadline)
                            Text(L10n.t("fixed_couple_contribution_desc", preferences.language))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(sharedColor)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Save button
            Button { save() } label: {
                HStack(spacing: 8) {
                    Text(formIsIncome
                        ? "💰 " + L10n.t("fixed_save_income", preferences.language)
                        : "✅ " + L10n.t("fixed_save_expense", preferences.language))
                        .font(.subheadline.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(formAmount.isEmpty ? Color(.systemGray4) : formAccentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: formAmount.isEmpty ? .clear : formAccentColor.opacity(0.3), radius: 6, y: 3)
            }
            .disabled(formAmount.isEmpty)
        }
        .padding(16)
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func formTypeButton(isIncome: Bool, emoji: String, label: String, color: Color) -> some View {
        let isSelected = formIsIncome == isIncome
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { formIsIncome = isIncome }
        } label: {
            HStack(spacing: 8) {
                Text(emoji).font(.title3)
                Text(label).font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? color : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .white : Color(.label))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: isSelected ? color.opacity(0.3) : .black.opacity(0.04), radius: 6, y: 3)
        }
        .sensoryFeedback(.selection, trigger: formIsIncome)
    }

    // MARK: - Save

    private func save() {
        let digits = formAmount.filter(\.isNumber)
        guard let amount = Decimal(string: digits), amount > 0 else { return }

        let isShared = formIsShared || formIsCoupleContribution
        // Use .equal for split (NOT .onePays)
        let splitType: SplitType? = isShared ? .equal : nil

        // Calculate split amounts
        var splitUser1: Decimal? = nil
        var splitUser2: Decimal? = nil
        if isShared {
            let half = amount / 2
            splitUser1 = half
            splitUser2 = half
        }

        let tx = Transaction(
            id: UUID(),
            userId: userId,
            coupleId: coupleId,
            type: formIsIncome ? .income : .expense,
            category: formCategory,
            amount: amount,
            description: formDesc.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: nil,
            date: Date(),
            isRecurring: true,
            recurringFrequency: .monthly,
            isShared: isShared,
            splitType: splitType,
            splitUser1Amount: splitUser1,
            splitUser2Amount: splitUser2,
            createdAt: Date(),
            updatedAt: Date()
        )

        _ = MockDataService.shared.addMockTransaction(tx)
        reload()

        // Reset
        formAmount = ""
        formDesc = ""
        formCategory = .housing
        formIsShared = false
        formIsIncome = false
        formIsCoupleContribution = false
        withAnimation { showForm = false }
    }
}

// MARK: - Split Picker Sheet (kept for other views)

struct SplitPickerSheet: View {
    let transaction: Transaction
    let myName: String
    let partnerName: String
    let onDismiss: () -> Void
    @State private var selectedIndex: Int = 0
    private let opts: [(String, String, String)] = [
        ("⚖️", "50/50", "Cada quien paga la mitad"),
        ("📊", "Proporcional", "Segun ingreso"),
        ("✂️", "Custom %", "Tu eliges"),
        ("💳", "Uno paga", "Una persona cubre todo"),
    ]
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ForEach(0..<opts.count, id: \.self) { i in
                    Button { selectedIndex = i } label: {
                        HStack(spacing: 12) {
                            Text(opts[i].0).font(.title2)
                            VStack(alignment: .leading) {
                                Text(opts[i].1).font(.subheadline.weight(.semibold)).foregroundStyle(Color(.label))
                                Text(opts[i].2).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: selectedIndex == i ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedIndex == i ? Color.fingetherPrimary : .secondary)
                        }.padding(.horizontal).padding(.vertical, 8)
                    }
                }
                Spacer()
            }
            .padding(.top, 16)
            .navigationTitle("División").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        var u = transaction
                        switch selectedIndex {
                        case 0: u.isShared = true; u.splitType = .equal
                        case 1: u.isShared = true; u.splitType = .proportional
                        case 2: u.isShared = true; u.splitType = .custom(50)
                        default: u.isShared = false; u.splitType = .onePays(transaction.userId)
                        }
                        u.updatedAt = Date()
                        MockDataService.shared.updateMockTransaction(u)
                        onDismiss()
                    }.foregroundStyle(Color.fingetherPrimary).fontWeight(.semibold)
                }
            }
            .onAppear {
                guard let s = transaction.splitType else { selectedIndex = transaction.isShared ? 0 : 3; return }
                switch s { case .equal: selectedIndex = 0; case .proportional: selectedIndex = 1; case .custom: selectedIndex = 2; case .onePays: selectedIndex = 3 }
            }
        }
    }
}
