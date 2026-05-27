import SwiftUI
import Foundation

// MARK: - Money Date View

/// Monthly financial review screen for couples.
/// Shows a summary of the current month's finances, top expenses,
/// category breakdown, achievements, and discussion questions.
struct MoneyDateView: View {

    let coupleId: UUID

    @State private var preferences = AppPreferences.shared

    // MARK: - Computed Data

    private var data: MockDataService { MockDataService.shared }

    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date()).capitalizedFirst
    }

    private var currentMonthTransactions: [Transaction] {
        let now = Date()
        let startOfMonth = now.startOfMonth
        let endOfMonth = now.endOfMonth
        return data.mockTransactions.filter { tx in
            tx.date >= startOfMonth && tx.date <= endOfMonth
        }
    }

    private var totalIncome: Decimal {
        currentMonthTransactions
            .filter { $0.type == .income }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var totalExpenses: Decimal {
        currentMonthTransactions
            .filter { $0.type == .expense }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var balance: Decimal {
        totalIncome - totalExpenses
    }

    private var top3Expenses: [Transaction] {
        currentMonthTransactions
            .filter { $0.type == .expense }
            .sorted { $0.amount > $1.amount }
            .prefix(3)
            .map { $0 }
    }

    private var categoryBreakdown: [(category: TransactionCategory, total: Decimal)] {
        var totals: [TransactionCategory: Decimal] = [:]
        for tx in currentMonthTransactions where tx.type == .expense {
            totals[tx.category, default: Decimal.zero] += tx.amount
        }
        return totals
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { (category: $0.key, total: $0.value) }
    }

    private var maxCategoryAmount: Decimal {
        categoryBreakdown.first?.total ?? 1
    }

    private var topCategory: TransactionCategory? {
        categoryBreakdown.first?.category
    }

    private var activeSavingsGoals: [SavingsGoal] {
        data.mockSavingsGoals.filter { $0.status == .active }
    }

    private var discussionQuestions: [String] {
        guard let top = topCategory else {
            return [
                "Que meta financiera quieren lograr juntos este mes?",
                "Hay algun gasto que podamos reducir?",
                "Como se sienten con nuestras finanzas actuales?"
            ]
        }
        switch top {
        case .food:
            return [
                "Podemos cocinar mas en casa este mes?",
                "Cuantas veces comimos fuera y valio la pena?",
                "Que tal si fijamos un presupuesto semanal para comida?"
            ]
        case .entertainment:
            return [
                "Cuales de nuestras salidas disfrutamos mas?",
                "Hay opciones de entretenimiento mas economicas que podamos probar?",
                "Queremos reservar un monto fijo mensual para diversiernos?"
            ]
        case .transport:
            return [
                "Podemos compartir mas viajes o usar transporte publico?",
                "Vale la pena lo que gastamos en transporte?",
                "Hay alguna ruta o metodo que nos ahorre dinero?"
            ]
        case .shopping:
            return [
                "Hubo compras impulsivas que pudimos evitar?",
                "Que compra de este mes nos hizo mas felices?",
                "Queremos establecer una regla de 24 horas antes de compras grandes?"
            ]
        case .housing:
            return [
                "Hay servicios del hogar que podamos optimizar?",
                "Estamos comodos con lo que pagamos de vivienda?",
                "Hay mejoras del hogar que queramos planear juntos?"
            ]
        default:
            return [
                "Que gasto de este mes nos sorprendio mas?",
                "Hay algo en lo que gastamos de mas y podemos mejorar?",
                "Cual es nuestra prioridad financiera para el proximo mes?"
            ]
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if preferences.isCoupleMode {
                mainContent
            } else {
                ContentUnavailableView(
                    "Modo pareja requerido",
                    systemImage: "heart.fill",
                    description: Text("Money Date esta disponible solo en modo pareja.")
                )
            }
        }
        .navigationTitle("Money Date")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AnalyticsService.track(.moneyDateViewed)
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                headerCard
                summaryCard
                top3ExpensesCard
                categoryBreakdownCard
                achievementsCard
                questionsCard
                shareButton
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .trackCurrency()
    }

    // MARK: - 1. Header Card

    private var headerCard: some View {
        VStack(spacing: 8) {
            Text("\u{1F495} Money Date")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text(currentMonthName)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            LinearGradient(
                colors: [Color.fingetherPrimary, Color.fingetherRose],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.fingetherPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    // MARK: - 2. Summary Card

    private var summaryCard: some View {
        VStack(spacing: 16) {
            cardTitle("Resumen del mes")

            HStack(spacing: 0) {
                summaryItem(
                    title: "Ingresos",
                    amount: totalIncome,
                    color: Color.fingetherForest
                )
                Divider().frame(height: 50)
                summaryItem(
                    title: "Gastos",
                    amount: totalExpenses,
                    color: Color.fingetherExpense
                )
                Divider().frame(height: 50)
                summaryItem(
                    title: "Balance",
                    amount: balance,
                    color: balance >= 0 ? Color.fingetherPrimary : Color.fingetherDanger
                )
            }
        }
        .cardStyle()
    }

    private func summaryItem(title: String, amount: Decimal, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(amount.currencyFormatted)
                .font(.subheadline.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 3. Top 3 Expenses Card

    private var top3ExpensesCard: some View {
        VStack(spacing: 12) {
            cardTitle("Top 3 gastos del mes")

            if top3Expenses.isEmpty {
                Text("Sin gastos registrados este mes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(top3Expenses) { tx in
                    HStack(spacing: 12) {
                        Text(tx.category.emoji)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.description)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)

                            Text(ownerName(for: tx))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(tx.amount.currencyFormatted)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.fingetherExpense)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .cardStyle()
    }

    private func ownerName(for transaction: Transaction) -> String {
        if let profile = data.mockProfile, transaction.userId == profile.id {
            return profile.displayName
        }
        if let partner = data.mockPartnerProfile, transaction.userId == partner.id {
            return partner.displayName
        }
        return "Desconocido"
    }

    // MARK: - 4. Category Breakdown Card

    private var categoryBreakdownCard: some View {
        VStack(spacing: 12) {
            cardTitle("Desglose por categoria")

            if categoryBreakdown.isEmpty {
                Text("Sin datos de categorias este mes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(categoryBreakdown, id: \.category) { entry in
                    VStack(spacing: 4) {
                        HStack {
                            Text("\(entry.category.emoji) \(entry.category.displayName)")
                                .font(.subheadline)
                            Spacer()
                            Text(entry.total.currencyFormatted)
                                .font(.subheadline.weight(.medium))
                        }

                        GeometryReader { geo in
                            let fraction = maxCategoryAmount > 0
                                ? CGFloat(NSDecimalNumber(decimal: entry.total / maxCategoryAmount).doubleValue)
                                : 0

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.fingetherPrimary)
                                .frame(width: geo.size.width * min(fraction, 1.0))
                        }
                        .frame(height: 8)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.fingetherPrimary.opacity(0.15))
                        )
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 5. Achievements Card

    private var achievementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("Logros de este mes")

            let bullets = computeAchievementBullets()

            ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Color.fingetherWarning)
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)
                    Text(bullet)
                        .font(.subheadline)
                }
            }
        }
        .cardStyle()
    }

    private func computeAchievementBullets() -> [String] {
        var bullets: [String] = []

        // Check if expenses are lower than combined income suggests (rough heuristic)
        if totalIncome > 0 && totalExpenses > 0 {
            let expenseRatio = NSDecimalNumber(decimal: totalExpenses / totalIncome).doubleValue
            if expenseRatio < 0.5 {
                let percentage = Int((1.0 - expenseRatio) * 100)
                bullets.append("Gastaron solo \(100 - percentage)% de sus ingresos. Excelente control!")
            } else if expenseRatio < 0.8 {
                bullets.append("Mantuvieron sus gastos por debajo del 80% de sus ingresos.")
            }
        }

        // Savings goals progress
        for goal in activeSavingsGoals {
            if goal.currentAmount > 0 {
                bullets.append("Ahorraron \(goal.currentAmount.currencyFormatted) para \(goal.emoji) \(goal.name).")
            }
        }

        // Completed challenges
        let completedChallenges = data.mockChallenges.filter { $0.status == .completed }
        for challenge in completedChallenges.prefix(2) {
            bullets.append("Completaron el reto \"\(challenge.name)\" \(challenge.type.emoji)")
        }

        // Fallback message
        if bullets.isEmpty {
            bullets.append("Este mes fue dificil, pero siguen juntos en esto \u{1F4AA}")
        }

        return bullets
    }

    // MARK: - 6. Questions Card

    private var questionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("Preguntas para hablar")

            ForEach(Array(discussionQuestions.enumerated()), id: \.offset) { index, question in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1).")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.fingetherPrimary)
                        .frame(width: 20, alignment: .leading)

                    Text(question)
                        .font(.subheadline)
                }
                .padding(.vertical, 2)
            }
        }
        .cardStyle()
    }

    // MARK: - 7. Share Button

    private var shareButton: some View {
        Button {
            AnalyticsService.track(.moneyDateShared)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                Text("Compartir Money Date")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.fingetherPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func cardTitle(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.headline)
            Spacer()
        }
    }
}

// MARK: - Card Style Modifier

private struct CardStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}

private extension View {
    func cardStyle() -> some View {
        modifier(CardStyleModifier())
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MoneyDateView(coupleId: UUID())
    }
}
