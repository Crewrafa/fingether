import Foundation

@MainActor
@Observable
final class TransactionViewModel {

    // MARK: - List State

    var transactions: [Transaction] = []
    var filteredTransactions: [Transaction] = []
    var isLoading = false
    var errorMessage: String?
    var searchText = ""

    // MARK: - Filter State

    var selectedFilterCategory: TransactionCategory?
    var selectedFilterType: TransactionType?
    var selectedMonth: Date = Date()

    // MARK: - Form State

    var amount = ""
    var description = ""
    var notes = ""
    var selectedCategory: TransactionCategory = .other
    var selectedType: TransactionType = .expense
    var selectedDate: Date = Date()
    var isRecurring = false
    var recurringFrequency: RecurringFrequency = .monthly
    var isShared = false
    var splitType: SplitType? = nil

    // MARK: - Editing

    var editingTransaction: Transaction?

    // MARK: - Actions

    func loadTransactions(coupleId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            transactions = try await TransactionService.getTransactions(coupleId: coupleId)
            applyFilters()
        } catch {
            errorMessage = "No se pudieron cargar las transacciones. Intenta de nuevo."
        }
    }

    func addTransaction(coupleId: UUID, userId: UUID) async {
        guard validateForm() else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let parsedAmount = parseAmount(amount)
            let newTransaction = Transaction(
                id: UUID(),
                userId: userId,
                coupleId: coupleId,
                type: selectedType,
                category: selectedCategory,
                amount: parsedAmount,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
                date: selectedDate,
                isRecurring: isRecurring,
                recurringFrequency: isRecurring ? recurringFrequency : nil,
                isShared: isShared,
                splitType: isShared ? (splitType ?? .equal) : nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            let created = try await TransactionService.addTransaction(newTransaction)
            transactions.insert(created, at: 0)
            applyFilters()
            resetForm()
            AnalyticsService.track(.transactionAdded, properties: ["type": selectedType.rawValue, "shared": String(isShared)])
        } catch {
            errorMessage = "No se pudo guardar la transaccion. Intenta de nuevo."
        }
    }

    func updateTransaction() async {
        guard var editing = editingTransaction else { return }
        guard validateForm() else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let parsedAmount = parseAmount(amount)
            editing.type = selectedType
            editing.category = selectedCategory
            editing.amount = parsedAmount
            editing.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
            editing.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
            editing.date = selectedDate
            editing.isRecurring = isRecurring
            editing.recurringFrequency = isRecurring ? recurringFrequency : nil
            editing.isShared = isShared
            editing.splitType = isShared ? (splitType ?? .equal) : nil
            editing.updatedAt = Date()

            try await TransactionService.updateTransaction(editing)
            if let index = transactions.firstIndex(where: { $0.id == editing.id }) {
                transactions[index] = editing
            }
            applyFilters()
            resetForm()
        } catch {
            errorMessage = "No se pudo actualizar la transaccion. Intenta de nuevo."
        }
    }

    func deleteTransaction(id: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await TransactionService.deleteTransaction(id: id)
            transactions.removeAll { $0.id == id }
            applyFilters()
        } catch {
            errorMessage = "No se pudo eliminar la transaccion. Intenta de nuevo."
        }
    }

    func applyFilters() {
        var result = transactions

        // Filter by month
        let calendar = Calendar.current
        let monthComponents = calendar.dateComponents([.year, .month], from: selectedMonth)
        result = result.filter { transaction in
            let txComponents = calendar.dateComponents([.year, .month], from: transaction.date)
            return txComponents.year == monthComponents.year && txComponents.month == monthComponents.month
        }

        // Filter by type
        if let filterType = selectedFilterType {
            result = result.filter { $0.type == filterType }
        }

        // Filter by category
        if let filterCategory = selectedFilterCategory {
            result = result.filter { $0.category == filterCategory }
        }

        // Filter by search text
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchText.lowercased()
            result = result.filter { tx in
                tx.description.lowercased().contains(query)
                || (tx.notes?.lowercased().contains(query) ?? false)
                || tx.category.displayName.lowercased().contains(query)
            }
        }

        // Sort by date descending
        filteredTransactions = result.sorted { $0.date > $1.date }
    }

    func prepareForEditing(transaction: Transaction) {
        editingTransaction = transaction
        amount = "\(transaction.amount)"
        description = transaction.description
        notes = transaction.notes ?? ""
        selectedCategory = transaction.category
        selectedType = transaction.type
        selectedDate = transaction.date
        isRecurring = transaction.isRecurring
        recurringFrequency = transaction.recurringFrequency ?? .monthly
        isShared = transaction.isShared
        splitType = transaction.splitType
    }

    func resetForm() {
        editingTransaction = nil
        amount = ""
        description = ""
        notes = ""
        selectedCategory = .other
        selectedType = .expense
        selectedDate = Date()
        isRecurring = false
        recurringFrequency = .monthly
        isShared = false
        splitType = nil
    }

    // MARK: - Computed Properties

    var totalIncome: Decimal {
        filteredTransactions
            .filter { $0.type == .income }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    var totalExpenses: Decimal {
        filteredTransactions
            .filter { $0.type == .expense }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    var balance: Decimal {
        totalIncome - totalExpenses
    }

    // MARK: - Private Helpers

    private func validateForm() -> Bool {
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        if amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "El monto es obligatorio."
            return false
        }

        let parsedAmount = parseAmount(amount)
        if parsedAmount <= 0 {
            errorMessage = "El monto debe ser mayor a cero."
            return false
        }

        if trimmedDescription.isEmpty {
            errorMessage = "La descripcion es obligatoria."
            return false
        }

        return true
    }

    private func parseAmount(_ text: String) -> Decimal {
        // Remove thousand separators (dots), keep only digits
        let digits = text.filter(\.isNumber)
        return Decimal(string: digits) ?? Decimal.zero
    }
}
