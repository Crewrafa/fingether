import Foundation

@MainActor
@Observable
final class TripViewModel {

    // MARK: - State

    var trips: [Trip] = []
    var activeTrip: Trip?
    var tripExpenses: [TripExpense] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Form State

    var formName = ""
    var formEmoji = "✈️"
    var formDestination = ""
    var formStartDate = Date()
    var formEndDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    var formCurrency = "COP"
    var formCategories: [TripBudgetCategory] = TripViewModel.defaultCategories()
    var formIsShared = false
    var formSavingsMode: TripSavingsMode = .monthly
    var formMonthlySavings = ""

    // MARK: - Expense Form State

    var expenseAmount = ""
    var expenseCategory: TripBudgetCategory?
    var expenseMerchant = ""
    var expenseNotes = ""
    var expenseDate = Date()
    var expensePayerIsUser = true

    // MARK: - Computed

    var formTotalBudget: Decimal {
        formCategories.reduce(Decimal.zero) { $0 + $1.budgetAmount }
    }

    var formParsedMonthlySavings: Decimal {
        parseAmountFromFormatted(formMonthlySavings)
    }

    var formEstimatedMonths: Int? {
        guard formParsedMonthlySavings > 0, formTotalBudget > 0 else { return nil }
        return Int(ceil(NSDecimalNumber(decimal: formTotalBudget / formParsedMonthlySavings).doubleValue))
    }

    var upcomingTrips: [Trip] {
        trips.filter { $0.status == .planning }
            .sorted { $0.startDate < $1.startDate }
    }

    var pastTrips: [Trip] {
        trips.filter { $0.status == .completed }
            .sorted { $0.endDate > $1.endDate }
    }

    // MARK: - Actions

    func loadTrips(coupleId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let mock = MockDataService.shared
        guard mock.isEnabled else { return }

        trips = mock.mockTrips
        activeTrip = trips.first(where: { $0.status == .active })
        if let active = activeTrip {
            tripExpenses = mock.mockTripExpenses.filter { $0.tripId == active.id }
        }
    }

    func createTrip(coupleId: UUID) async {
        guard validateTripForm() else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let mock = MockDataService.shared
        let userId = mock.getMockProfile().id
        let monthlySavings = formParsedMonthlySavings

        var linkedTxId: UUID? = nil

        // Create the trip
        let tripId = UUID()
        let newTrip = Trip(
            id: tripId,
            coupleId: coupleId,
            name: formName.trimmingCharacters(in: .whitespacesAndNewlines),
            emoji: formEmoji.isEmpty ? "✈️" : formEmoji,
            destination: formDestination.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: formStartDate,
            endDate: formEndDate,
            totalBudget: formTotalBudget,
            currency: formCurrency,
            status: formStartDate <= Date() ? .active : .planning,
            categories: formCategories.map { cat in
                TripBudgetCategory(
                    id: cat.id,
                    name: cat.name,
                    emoji: cat.emoji,
                    budgetAmount: cat.budgetAmount,
                    spentAmount: 0
                )
            },
            isShared: formIsShared,
            savingsMode: formSavingsMode,
            monthlySavingsAmount: formSavingsMode == .monthly ? monthlySavings : 0,
            currentSaved: formSavingsMode == .alreadyHave ? formTotalBudget : 0,
            linkedTransactionId: nil,
            createdAt: Date()
        )

        // If monthly savings, create a recurring transaction linked to the trip
        if formSavingsMode == .monthly && monthlySavings > 0 {
            let txId = UUID()
            linkedTxId = txId

            // Calculate split amounts if shared
            var splitType: SplitType? = nil
            var split1: Decimal? = nil
            var split2: Decimal? = nil

            if formIsShared {
                let settings = mock.coupleSettings
                splitType = settings.defaultSplitType

                switch settings.defaultSplitType {
                case .equal:
                    split1 = monthlySavings / 2
                    split2 = monthlySavings / 2
                case .proportional:
                    let income1 = mock.mockCouple?.user1Income ?? 0
                    let income2 = mock.mockCouple?.user2Income ?? 0
                    let total = income1 + income2
                    if total > 0 {
                        split1 = monthlySavings * income1 / total
                        split2 = monthlySavings * income2 / total
                    } else {
                        split1 = monthlySavings / 2
                        split2 = monthlySavings / 2
                    }
                case .custom(let pct):
                    split1 = monthlySavings * Decimal(pct) / 100
                    split2 = monthlySavings * Decimal(100 - pct) / 100
                case .onePays(let payerId):
                    split1 = payerId == userId ? monthlySavings : 0
                    split2 = payerId == userId ? 0 : monthlySavings
                }
            }

            let savingsTx = Transaction(
                id: txId,
                userId: userId,
                coupleId: coupleId,
                type: .expense,
                category: .savings,
                amount: monthlySavings,
                description: "Ahorro: \(newTrip.name) \(newTrip.emoji)",
                notes: "trip_contribution_\(tripId.uuidString)",
                date: Date(),
                isRecurring: true,
                recurringFrequency: .monthly,
                isShared: formIsShared,
                splitType: splitType,
                splitUser1Amount: split1,
                splitUser2Amount: split2,
                createdAt: Date(),
                updatedAt: Date()
            )

            _ = mock.addMockTransaction(savingsTx)
        }

        // Save trip with linked transaction ID
        var savedTrip = newTrip
        savedTrip.linkedTransactionId = linkedTxId
        mock.mockTrips.append(savedTrip)
        trips.append(savedTrip)

        if savedTrip.status == .active {
            activeTrip = savedTrip
        }

        resetTripForm()
    }

    func addTripExpense(tripId: UUID) async {
        guard validateExpenseForm() else { return }

        let amount = parseAmountFromFormatted(expenseAmount)
        let mock = MockDataService.shared

        let expense = TripExpense(
            id: UUID(),
            tripId: tripId,
            userId: mock.getMockProfile().id,
            amount: amount,
            currency: formCurrency,
            categoryId: expenseCategory?.id ?? UUID(),
            merchant: expenseMerchant.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: expenseNotes.isEmpty ? nil : expenseNotes,
            date: expenseDate,
            splitType: nil,
            splitUser1Amount: nil,
            splitUser2Amount: nil,
            createdAt: Date()
        )

        mock.mockTripExpenses.append(expense)
        tripExpenses.append(expense)

        // Update category spent amount
        if let tripIdx = trips.firstIndex(where: { $0.id == tripId }),
           let catIdx = trips[tripIdx].categories.firstIndex(where: { $0.id == expenseCategory?.id }) {
            trips[tripIdx].categories[catIdx].spentAmount += amount
            mock.mockTrips = trips
            if trips[tripIdx].status == .active {
                activeTrip = trips[tripIdx]
            }
        }

        resetExpenseForm()
    }

    /// Called when a trip's monthly savings is marked as paid in FixedExpensesView
    func recordSavingsPayment(tripId: UUID, amount: Decimal) {
        if let idx = trips.firstIndex(where: { $0.id == tripId }) {
            trips[idx].currentSaved += amount
            MockDataService.shared.mockTrips = trips
        }
    }

    func completeTrip(tripId: UUID) async {
        if let idx = trips.firstIndex(where: { $0.id == tripId }) {
            trips[idx].status = .completed

            // Deactivate linked recurring transaction
            if let txId = trips[idx].linkedTransactionId,
               let txIdx = MockDataService.shared.mockTransactions.firstIndex(where: { $0.id == txId }) {
                MockDataService.shared.mockTransactions[txIdx].isRecurring = false
            }

            MockDataService.shared.mockTrips = trips
            if activeTrip?.id == tripId {
                activeTrip = nil
            }
        }
    }

    func expensesForTrip(_ tripId: UUID) -> [TripExpense] {
        MockDataService.shared.mockTripExpenses
            .filter { $0.tripId == tripId }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Category Management

    func updateCategoryBudget(at index: Int, amount: Decimal) {
        guard index < formCategories.count else { return }
        formCategories[index].budgetAmount = amount
    }

    func addCustomCategory(name: String, emoji: String) {
        let cat = TripBudgetCategory(id: UUID(), name: name, emoji: emoji, budgetAmount: 0, spentAmount: 0)
        formCategories.append(cat)
    }

    func removeCategory(at index: Int) {
        guard index < formCategories.count, formCategories.count > 1 else { return }
        formCategories.remove(at: index)
    }

    // MARK: - Helpers

    static func defaultCategories() -> [TripBudgetCategory] {
        [
            TripBudgetCategory(id: UUID(), name: "Hospedaje", emoji: "🏨", budgetAmount: 0, spentAmount: 0),
            TripBudgetCategory(id: UUID(), name: "Comida", emoji: "🍽️", budgetAmount: 0, spentAmount: 0),
            TripBudgetCategory(id: UUID(), name: "Transporte", emoji: "🚕", budgetAmount: 0, spentAmount: 0),
            TripBudgetCategory(id: UUID(), name: "Actividades", emoji: "🎭", budgetAmount: 0, spentAmount: 0),
            TripBudgetCategory(id: UUID(), name: "Compras", emoji: "🛍️", budgetAmount: 0, spentAmount: 0),
            TripBudgetCategory(id: UUID(), name: "Otros", emoji: "📦", budgetAmount: 0, spentAmount: 0),
        ]
    }

    func suggestMonthlySavings() -> Decimal {
        guard formTotalBudget > 0 else { return 0 }
        let monthsUntilTrip = max(Calendar.current.dateComponents([.month], from: Date(), to: formStartDate).month ?? 1, 1)
        return formTotalBudget / Decimal(monthsUntilTrip)
    }

    func resetTripForm() {
        formName = ""
        formEmoji = "✈️"
        formDestination = ""
        formStartDate = Date()
        formEndDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        formCurrency = "COP"
        formCategories = TripViewModel.defaultCategories()
        formIsShared = false
        formSavingsMode = .monthly
        formMonthlySavings = ""
    }

    func resetExpenseForm() {
        expenseAmount = ""
        expenseCategory = nil
        expenseMerchant = ""
        expenseNotes = ""
        expenseDate = Date()
        expensePayerIsUser = true
    }

    private func validateTripForm() -> Bool {
        if formName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "El nombre del viaje es obligatorio."
            return false
        }
        if formDestination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "El destino es obligatorio."
            return false
        }
        if formTotalBudget <= 0 {
            errorMessage = "Agrega presupuesto a al menos una categoria."
            return false
        }
        if formEndDate <= formStartDate {
            errorMessage = "La fecha de fin debe ser posterior a la de inicio."
            return false
        }
        if formSavingsMode == .monthly && formParsedMonthlySavings <= 0 {
            errorMessage = "El aporte mensual debe ser mayor a cero."
            return false
        }
        return true
    }

    private func validateExpenseForm() -> Bool {
        let amount = parseAmountFromFormatted(expenseAmount)
        if amount <= 0 {
            errorMessage = "El monto debe ser mayor a cero."
            return false
        }
        if expenseCategory == nil {
            errorMessage = "Selecciona una categoria."
            return false
        }
        return true
    }
}
