import SwiftUI

struct DashboardView: View {

    let userId: UUID
    let coupleId: UUID?

    @State private var viewModel = DashboardViewModel()
    @State private var mockData = MockDataService.shared
    @State private var showAddTransaction = false
    @State private var preferences = AppPreferences.shared
    @State private var selectedMonth = Date()
    @State private var showBudgetEditor = false
    @State private var showSplitEditor = false
    @State private var budgetEditorText = ""
    @Environment(\.colorScheme) private var colorScheme

    private var showCoupleBalance: Bool { preferences.isCoupleMode }

    private let tealColor = Color.fingetherPrimary
    private let expenseColor = Color.fingetherExpense
    private let redColor = Color.fingetherDanger
    private let individualColor = Color.fingetherSky
    private let sharedColor = Color.fingetherRose

    private var myName: String {
        mockData.mockProfile?.displayName ?? "Yo"
    }

    private var partnerName: String {
        mockData.mockPartnerProfile?.displayName ?? "Pareja"
    }

    private var myEmoji: String {
        genderEmoji(mockData.mockProfile?.gender)
    }

    private var partnerEmoji: String {
        genderEmoji(mockData.mockPartnerProfile?.gender)
    }

    private func genderEmoji(_ gender: String?) -> String {
        switch gender?.lowercased() {
        case "masculino": return "🧑"
        case "femenino": return "👩"
        default: return "🧑"
        }
    }

    // MARK: - My portion of a shared transaction

    private func myPortionOf(_ tx: Transaction) -> Decimal {
        guard tx.isShared else { return tx.amount }
        let isUser1 = userId == mockData.mockCouple?.partner1Id
        if isUser1, let amount = tx.splitUser1Amount { return amount }
        if !isUser1, let amount = tx.splitUser2Amount { return amount }

        switch tx.splitType ?? .equal {
        case .equal: return tx.amount / 2
        case .custom(let pct):
            let myPct = isUser1 ? pct : (100 - pct)
            return tx.amount * Decimal(myPct) / 100
        case .onePays(let payerId):
            return payerId == userId ? tx.amount : 0
        case .proportional:
            return tx.amount / 2
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 20) {
                        // C1: Trial banner when trial is active (not premium, not dev-bypass)
                        if AppPreferences.shared.isTrialActive && !MockDataService.shared.isEnabled
                           && MockDataService.shared.mockProfile?.subscriptionTier != .premium {
                            trialBanner
                        }
                        compactHeader
                        balanceHeroCard
                        if showCoupleBalance {
                            coupleConfigCards
                            whoOwesWhoCard
                            if let cid = coupleId {
                                scoreWidgetCard(coupleId: cid)
                            }
                        }
                        savingsPreviewCard
                        recentTransactionsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 90)
                }
                .trackCurrency()
                .refreshable {
                    await loadData()
                }

                addTransactionFAB
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddTransaction, onDismiss: { Task { await loadData() } }) {
                if let cid = coupleId {
                    AddTransactionView(coupleId: cid, userId: userId)
                }
            }
            .sheet(isPresented: $showBudgetEditor) {
                coupleBudgetEditorSheet
            }
            .sheet(isPresented: $showSplitEditor) {
                splitEditorSheet
            }
            .task {
                await loadData()
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        if let cid = coupleId {
            await viewModel.loadDashboard(coupleId: cid, userId: userId)
        } else {
            await viewModel.loadSoloDashboard(userId: userId)
        }
    }

    // MARK: - Trial Banner (C1)

    private var trialBanner: some View {
        let days = AppPreferences.shared.trialDaysRemaining
        return HStack(spacing: 10) {
            Image(systemName: "gift.fill")
                .font(.title3)
                .foregroundStyle(Color.fingetherPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Prueba gratuita")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(.label))
                Text("\(days) días restantes")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("✨")
                .font(.title3)
        }
        .padding(12)
        .background(Color.fingetherPrimary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.fingetherPrimary.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Compact Header (single line)

    private var compactHeader: some View {
        HStack {
            // Left: user/couple name
            if showCoupleBalance, mockData.mockPartnerProfile != nil {
                Text("💕 \(myName) & \(partnerName)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(.label))
            } else {
                Text("\(myEmoji) \(myName)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(.label))
            }

            Spacer()

            // Right: month selector
            HStack(spacing: 12) {
                Button {
                    withAnimation { changeMonth(by: -1) }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tealColor)
                }

                Text(selectedMonth.formattedMonth.capitalizedFirst)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.interpolate)

                Button {
                    withAnimation { changeMonth(by: 1) }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isCurrentMonth ? .secondary.opacity(0.3) : tealColor)
                }
                .disabled(isCurrentMonth)
            }
        }
        .padding(.bottom, 0)
    }

    private var isCurrentMonth: Bool {
        let cal = Calendar.current
        return cal.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    private func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newDate
        }
    }

    // MARK: - Month-filtered transactions

    private var monthTransactions: [Transaction] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: selectedMonth)
        let endOfSelected = cal.date(from: DateComponents(year: comps.year, month: (comps.month ?? 1) + 1, day: 0)) ?? selectedMonth

        // Non-recurring transactions for this month
        let nonRecurring = mockData.mockTransactions.filter {
            !$0.isRecurring &&
            cal.dateComponents([.year, .month], from: $0.date).year == comps.year &&
            cal.dateComponents([.year, .month], from: $0.date).month == comps.month
        }

        // Recurring transactions created on or before this month
        let recurring = mockData.mockTransactions.filter {
            $0.isRecurring && $0.createdAt <= endOfSelected
        }

        return nonRecurring + recurring
    }

    private var monthIncome: Decimal {
        monthTransactions.filter { $0.type == .income }.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var monthExpenses: Decimal {
        monthTransactions.filter { $0.type == .expense }.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var monthMyExpenses: Decimal {
        monthTransactions.filter { $0.type == .expense && $0.userId == userId && !$0.isShared }.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var monthSharedExpenses: Decimal {
        monthTransactions.filter { $0.type == .expense && $0.isShared }.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var monthPartnerExpenses: Decimal {
        monthTransactions.filter { $0.type == .expense && $0.userId != userId && !$0.isShared }.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var myIncome: Decimal {
        monthTransactions.filter { $0.userId == userId && $0.type == .income }.reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// "Mis gastos" includes personal expenses PLUS my portion of paid fixed expenses
    private var myTotalExpenses: Decimal {
        let personalNonRecurring = monthTransactions.filter {
            $0.type == .expense && $0.userId == userId && !$0.isShared && !$0.isRecurring
        }.reduce(Decimal.zero) { $0 + $1.amount }

        let mySharedPortion = monthTransactions.filter {
            $0.type == .expense && $0.isShared
        }.reduce(Decimal.zero) { $0 + myPortionOf($1) }

        // Personal recurring expenses (not shared)
        let personalRecurring = monthTransactions.filter {
            $0.type == .expense && $0.isRecurring && !$0.isShared && $0.userId == userId
        }.reduce(Decimal.zero) { $0 + $1.amount }

        return personalNonRecurring + personalRecurring + mySharedPortion
    }

    private var myBalance: Decimal {
        myIncome - myTotalExpenses
    }

    private var monthRecentTransactions: [Transaction] {
        Array(monthTransactions
            .filter { !$0.isRecurring }
            .sorted { $0.date > $1.date }
            .prefix(2))
    }

    // MARK: - Balance Hero Card

    private var balanceHeroCard: some View {
        VStack(spacing: 16) {
            // Mode pill
            HStack(spacing: 0) {
                Text(showCoupleBalance ? "💕 " + L10n.t("mode_couple", preferences.language) : "\(myEmoji) " + L10n.t("mode_individual", preferences.language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.leading, 6)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.white.opacity(0.15))
            .clipShape(Capsule())

            if showCoupleBalance {
                Text(monthSharedExpenses.currencyFormatted)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())

                Text(L10n.t("dashboard_shared_expenses", preferences.language))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))

                HStack(spacing: 20) {
                    VStack(spacing: 3) {
                        Text("\(myEmoji) \(myName)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(monthMyExpenses.currencyFormatted)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.5)
                        Text(L10n.t("individual", preferences.language))
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 36)

                    VStack(spacing: 3) {
                        Text("💕 " + L10n.t("together", preferences.language))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(monthSharedExpenses.currencyFormatted)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.5)
                        Text(L10n.t("shared", preferences.language))
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 36)

                    VStack(spacing: 3) {
                        Text("\(partnerEmoji) \(partnerName)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(monthPartnerExpenses.currencyFormatted)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.5)
                        Text(L10n.t("individual", preferences.language))
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            } else {
                // Individual mode
                Text(myBalance.currencyFormatted)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())

                Text(L10n.t("dashboard_my_balance", preferences.language))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))

                HStack(spacing: 24) {
                    VStack(spacing: 3) {
                        Text("📈 " + L10n.t("dashboard_my_income", preferences.language))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(myIncome.currencyFormatted)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.5)
                    }

                    Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 30)

                    VStack(spacing: 3) {
                        Text("📉 " + L10n.t("dashboard_my_expenses", preferences.language))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(myTotalExpenses.currencyFormatted)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.5)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            LinearGradient(
                colors: showCoupleBalance
                    ? [tealColor, Color.fingetherPrimaryDark]
                    : [individualColor, Color(hex: "A29BFE")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: (showCoupleBalance ? tealColor : individualColor).opacity(0.3), radius: 14, y: 8)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                preferences.isCoupleMode.toggle()
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: preferences.isCoupleMode)
    }

    // MARK: - Couple Config Cards (between balance and who-owes-who)

    private var coupleConfigCards: some View {
        let mode: BudgetMode = showCoupleBalance ? .couple : .individual
        let calc = BudgetCalculator.calculate(for: mode)

        return VStack(spacing: 12) {
            // ── Smart Budget Card (v1.4) ──
            if calc.totalIncome <= 0 {
                // No income data → can't calculate budget
                HStack(spacing: 10) {
                    Text("📊").font(.title3)
                    Text("Registra tu ingreso y gastos fijos para ver tu presupuesto")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
            Button { showBudgetEditor = true } label: {
                VStack(spacing: 12) {
                    // Header
                    HStack {
                        Text("📊")
                            .font(.title3)
                        Text("Presupuesto del mes")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color(.label))
                        Spacer()
                        Text("\(Int(calc.percentUsed))%")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(budgetZoneColor(calc.zone))
                            .contentTransition(.numericText())
                    }

                    // Progress bar with zones
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(budgetZoneColor(calc.zone))
                                .frame(width: min(geo.size.width * CGFloat(calc.percentUsed / 100), geo.size.width), height: 8)
                                .animation(.easeOut(duration: 0.4), value: calc.percentUsed)
                        }
                    }
                    .frame(height: 8)

                    // Numbers
                    HStack(spacing: 0) {
                        VStack(spacing: 2) {
                            Text("Disponible")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Text(calc.effectiveBudget.currencyFormatted)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(tealColor)
                                .lineLimit(1).minimumScaleFactor(0.5)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 2) {
                            Text("Gastado")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Text(calc.spentThisMonth.currencyFormatted)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.fingetherExpense)
                                .lineLimit(1).minimumScaleFactor(0.5)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 2) {
                            Text("Quedan")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Text(calc.remaining.currencyFormatted)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(calc.remaining >= 0 ? Color.fingetherIncome : Color.fingetherDanger)
                                .lineLimit(1).minimumScaleFactor(0.5)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if calc.hasCustomLimit {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.system(size: 9))
                            Text("Límite: \(calc.effectiveBudget.currencyFormatted) · Ahorro: \(calc.impliedMonthlySavings.currencyFormatted)/mes")
                                .font(.system(size: 9))
                        }
                        .foregroundStyle(Color.fingetherIncome)
                    }
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            } // end if calc.totalIncome > 0

            // ── Contextual insight ──
            if let insight = BudgetCalculator.contextualInsight(from: calc) {
                HStack(spacing: 8) {
                    Text(insight.emoji)
                        .font(.caption)
                    Text(insight.text)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(budgetZoneColor(calc.zone).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // ── Split settings card (unchanged) ──
            Button { showSplitEditor = true } label: {
                HStack(spacing: 8) {
                    Text("⚖️").font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("dashboard_split_settings", preferences.language))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(mockData.coupleSettings.defaultSplitType.displayName)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(tealColor)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }

    private func budgetZoneColor(_ zone: BudgetZone) -> Color {
        switch zone {
        case .good: return Color.fingetherPrimary
        case .attention: return Color.fingetherPrimaryDark
        case .warning: return Color.fingetherWarning
        case .exceeded: return Color.fingetherDanger
        }
    }

    // MARK: - Who Owes Who

    private var whoOwesWhoCard: some View {
        let unpaidDebts = mockData.mockDebts.filter { !$0.isPaid }
        let theyOweMe = unpaidDebts
            .filter { $0.toUserId == userId }
            .reduce(Decimal.zero) { $0 + $1.amount }
        let iOweThem = unpaidDebts
            .filter { $0.fromUserId == userId }
            .reduce(Decimal.zero) { $0 + $1.amount }
        let difference = theyOweMe - iOweThem

        return NavigationLink {
            DebtDetailView(
                userId: userId,
                debts: mockData.mockDebts,
                partnerName: partnerName
            )
        } label: {
            HStack(spacing: 8) {
                if unpaidDebts.isEmpty || abs(NSDecimalNumber(decimal: difference).doubleValue) < 1.0 {
                    Text("✅").font(.title2)
                    Text(L10n.t("dashboard_settled", preferences.language))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tealColor)
                    Spacer()
                } else if difference > 0 {
                    Text("💰").font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(partnerName) " + L10n.t("dashboard_owes_you", preferences.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(difference.currencyFormatted)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(tealColor)
                            .lineLimit(1).minimumScaleFactor(0.5)
                    }
                    Spacer()
                } else {
                    Text("💰").font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("dashboard_you_owe", preferences.language) + " \(partnerName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(abs(difference).currencyFormatted)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(redColor)
                            .lineLimit(1).minimumScaleFactor(0.5)
                    }
                    Spacer()
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Savings Goal Preview

    private var savingsPreviewCard: some View {
        Group {
            if let goal = viewModel.topSavingsGoal {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("🎯 " + L10n.t("dashboard_savings_goal", preferences.language))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if viewModel.activeSavingsGoalsCount > 1 {
                            Text("\(viewModel.activeSavingsGoalsCount) " + L10n.t("dashboard_active_goals", preferences.language))
                                .font(.caption)
                                .foregroundStyle(tealColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(goal.emoji)
                                .font(.title3)
                            Text(goal.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(.label))
                            Spacer()
                            Text("\(Int(goal.progress * 100))%")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.fingetherWarning)
                        }

                        ProgressView(value: goal.progress)
                            .tint(Color.fingetherWarning)

                        HStack {
                            Text(goal.currentAmount.currencyFormatted)
                                .font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).minimumScaleFactor(0.5)
                            Spacer()
                            Text(goal.targetAmount.currencyFormatted)
                                .font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).minimumScaleFactor(0.5)
                        }
                    }
                    .padding(14)
                    .background(Color.fingetherWarning.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    // MARK: - Recent Transactions

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("📋 " + L10n.t("dashboard_recent", preferences.language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                NavigationLink {
                    TransactionListView(userId: userId, coupleId: coupleId)
                } label: {
                    Text(L10n.t("dashboard_see_all", preferences.language) + " →")
                        .font(.caption)
                        .foregroundStyle(tealColor)
                }
            }

            let recent = Array(monthRecentTransactions)
            if recent.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: L10n.t("dashboard_no_transactions", preferences.language),
                    subtitle: L10n.t("dashboard_add_first", preferences.language),
                    actionTitle: L10n.t("dashboard_add", preferences.language),
                    action: { showAddTransaction = true }
                )
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, transaction in
                        TransactionRow(transaction: transaction, currentUserId: userId)
                            .padding(.vertical, 6)

                        if index < recent.count - 1 {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - FAB

    private var addTransactionFAB: some View {
        Button {
            showAddTransaction = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(
                    LinearGradient(
                        colors: [tealColor, Color.fingetherPrimaryDark],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: tealColor.opacity(0.4), radius: 10, y: 5)
        }
        .sensoryFeedback(.impact(flexibility: .solid), trigger: showAddTransaction)
    }

    // MARK: - Smart Budget Editor Sheet (v1.4)

    private var coupleBudgetEditorSheet: some View {
        let mode: BudgetMode = showCoupleBalance ? .couple : .individual
        let calc = BudgetCalculator.calculate(for: mode)

        return NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("📊").font(.system(size: 48))
                    Text("Presupuesto inteligente")
                        .font(.headline)

                    // Breakdown card
                    VStack(alignment: .leading, spacing: 10) {
                        budgetBreakdownRow(emoji: "💰", label: "Ingresos", value: calc.totalIncome, color: Color.fingetherIncome)
                        Divider()
                        budgetBreakdownRow(emoji: "📌", label: "Gastos fijos", value: -calc.totalFixedExpenses, color: Color.fingetherExpense)
                        if calc.totalSavingsContributions > 0 {
                            Divider()
                            budgetBreakdownRow(emoji: "🎯", label: "Aportes a metas", value: -calc.totalSavingsContributions, color: Color.fingetherAmber)
                        }
                        Divider()
                        HStack {
                            Text("Disponible para gastar")
                                .font(.subheadline.weight(.bold))
                            Spacer()
                            Text(calc.calculatedAvailable.currencyFormatted)
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(Color.fingetherPrimary)
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Optional limit toggle
                    VStack(spacing: 14) {
                        Toggle(isOn: Binding(
                            get: { mockData.budgetLimitEnabled },
                            set: { val in
                                mockData.budgetLimitEnabled = val
                                if val && mockData.userBudgetLimit == nil {
                                    // Default limit = 80% of available
                                    mockData.userBudgetLimit = calc.calculatedAvailable * 8 / 10
                                }
                                mockData.saveAll()
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Poner límite de gasto")
                                    .font(.subheadline.weight(.semibold))
                                Text("Ahorra automáticamente la diferencia")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(Color.fingetherPrimary)

                        if mockData.budgetLimitEnabled, calc.calculatedAvailable > 0 {
                            let limitBinding = Binding<Double>(
                                get: {
                                    let lim = mockData.userBudgetLimit ?? calc.calculatedAvailable
                                    return NSDecimalNumber(decimal: lim).doubleValue
                                },
                                set: { val in
                                    mockData.userBudgetLimit = Decimal(Int(val))
                                    mockData.saveAll()
                                }
                            )
                            let maxVal = NSDecimalNumber(decimal: calc.calculatedAvailable).doubleValue
                            let minVal = maxVal * 0.5

                            VStack(spacing: 8) {
                                Slider(value: limitBinding, in: minVal...maxVal, step: 10000)
                                    .tint(Color.fingetherPrimary)

                                HStack {
                                    Text("Límite: \((mockData.userBudgetLimit ?? 0).currencyFormatted)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.fingetherPrimary)
                                    Spacer()
                                    let savings = calc.calculatedAvailable - (mockData.userBudgetLimit ?? calc.calculatedAvailable)
                                    if savings > 0 {
                                        Text("💡 Ahorro: \(savings.currencyFormatted)/mes")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.fingetherIncome)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color.fingetherPrimary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
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
                        // Sync to legacy coupleMonthlyBudget for backwards compat
                        mockData.mockCouple?.coupleMonthlyBudget = calc.effectiveBudget
                        showBudgetEditor = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.fingetherPrimary)
                }
            }
        }
    }

    private func budgetBreakdownRow(emoji: String, label: String, value: Decimal, color: Color) -> some View {
        HStack {
            Text("\(emoji) \(label)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.currencyFormatted)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(color)
        }
    }

    // MARK: - Split Editor Sheet

    @State private var splitSelection: Int = 0
    @State private var customSliderValue: Double = 50

    private var splitEditorSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("⚖️").font(.system(size: 48))
                Text(L10n.t("dashboard_split_title", preferences.language))
                    .font(.headline)

                VStack(spacing: 12) {
                    splitOption(index: 0, emoji: "⚖️", title: "50/50", desc: L10n.t("split_equal_desc", preferences.language))
                    splitOption(index: 1, emoji: "📊", title: L10n.t("split_proportional", preferences.language), desc: L10n.t("split_proportional_desc", preferences.language))
                    splitOption(index: 2, emoji: "✂️", title: L10n.t("split_custom", preferences.language), desc: L10n.t("split_custom_desc", preferences.language))
                    splitOption(index: 3, emoji: "💳", title: L10n.t("split_one_pays", preferences.language), desc: L10n.t("split_one_pays_desc", preferences.language))
                }

                // Custom slider (only when custom selected)
                if splitSelection == 2 {
                    VStack(spacing: 8) {
                        Slider(value: $customSliderValue, in: 1...99, step: 1)
                            .tint(tealColor)
                        HStack {
                            Text("\(myName): \(Int(customSliderValue))%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(tealColor)
                            Spacer()
                            Text("\(partnerName): \(100 - Int(customSliderValue))%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(tealColor)
                        }
                    }
                    .padding(14)
                    .background(tealColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Real-time preview
                let previewSplit = previewSplitType
                let sampleAmount: Decimal = 100000
                let preview = previewAmounts(for: sampleAmount, splitType: previewSplit)
                VStack(spacing: 4) {
                    Text(L10n.t("split_preview", preferences.language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("\(myName): \(preview.0.currencyFormatted)")
                            .font(.caption).foregroundStyle(tealColor)
                        Spacer()
                        Text("\(partnerName): \(preview.1.currencyFormatted)")
                            .font(.caption).foregroundStyle(tealColor)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Spacer()
            }
            .padding(24)
            .navigationTitle(L10n.t("dashboard_split_settings", preferences.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("cancel", preferences.language)) { showSplitEditor = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("save", preferences.language)) {
                        mockData.coupleSettings.defaultSplitType = previewSplitType
                        mockData.recalculateAllSharedFixedSplits()
                        showSplitEditor = false
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                switch mockData.coupleSettings.defaultSplitType {
                case .equal: splitSelection = 0
                case .proportional: splitSelection = 1
                case .custom(let pct): splitSelection = 2; customSliderValue = Double(pct)
                case .onePays: splitSelection = 3
                }
            }
        }
    }

    private var previewSplitType: SplitType {
        switch splitSelection {
        case 0: return .equal
        case 1: return .proportional
        case 2: return .custom(Int(customSliderValue))
        case 3: return .onePays(userId)
        default: return .equal
        }
    }

    private func previewAmounts(for total: Decimal, splitType: SplitType) -> (Decimal, Decimal) {
        switch splitType {
        case .equal:
            return (total / 2, total / 2)
        case .proportional:
            return (total / 2, total / 2)
        case .custom(let pct):
            let user1 = total * Decimal(pct) / 100
            return (user1, total - user1)
        case .onePays:
            return (total, 0)
        }
    }

    // MARK: - Score Widget Card

    private func scoreWidgetCard(coupleId: UUID) -> some View {
        let score = MockDataService.shared.calculateFinancialScore(coupleId: coupleId)
        return NavigationLink {
            ScoreView(coupleId: coupleId, userId: userId)
        } label: {
            HStack(spacing: 12) {
                // Mini ring
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 4)
                        .frame(width: 42, height: 42)
                    Circle()
                        .trim(from: 0, to: Double(score.score) / 100.0)
                        .stroke(score.scoreColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 42, height: 42)
                        .rotationEffect(.degrees(-90))
                    Text("\(score.score)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(score.scoreColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Score Fingether")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text(score.scoreLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(.label))
                        Image(systemName: score.trend.iconName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(score.trend.color)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func splitOption(index: Int, emoji: String, title: String, desc: String) -> some View {
        Button { withAnimation { splitSelection = index } } label: {
            HStack(spacing: 12) {
                Text(emoji).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.label))
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: splitSelection == index ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(splitSelection == index ? tealColor : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(splitSelection == index ? tealColor.opacity(0.08) : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(splitSelection == index ? tealColor.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: splitSelection)
    }
}
