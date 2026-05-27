import Foundation

@MainActor
@Observable
final class BudgetViewModel {

    // MARK: - State

    var budgets: [Budget] = []
    var budgetAlerts: [BudgetAlertResponse] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Form State

    var selectedCategory: TransactionCategory = .food
    var amountLimit = ""
    var period: BudgetPeriod = .monthly
    var alertThreshold = "0.8"

    // MARK: - Editing

    var editingBudget: Budget?

    // MARK: - Actions

    func loadBudgets(coupleId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            budgets = try await BudgetService.getBudgets(coupleId: coupleId)
            await loadAlerts(coupleId: coupleId)
        } catch {
            errorMessage = "No se pudieron cargar los presupuestos. Intenta de nuevo."
        }
    }

    func createBudget(coupleId: UUID) async {
        guard validateForm() else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let parsedLimit = parseDecimal(amountLimit)
            let parsedThreshold = parseDecimal(alertThreshold)

            let newBudget = Budget(
                id: UUID(),
                coupleId: coupleId,
                category: selectedCategory,
                amountLimit: parsedLimit,
                period: period,
                currentSpent: 0,
                alertThreshold: parsedThreshold,
                isActive: true,
                startDate: Date(),
                createdAt: Date(),
                updatedAt: Date()
            )
            let created = try await BudgetService.createBudget(newBudget)
            budgets.append(created)
            resetForm()
        } catch {
            errorMessage = "No se pudo crear el presupuesto. Intenta de nuevo."
        }
    }

    func updateBudget() async {
        guard var editing = editingBudget else { return }
        guard validateForm() else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let parsedLimit = parseDecimal(amountLimit)
            let parsedThreshold = parseDecimal(alertThreshold)

            editing.category = selectedCategory
            editing.amountLimit = parsedLimit
            editing.period = period
            editing.alertThreshold = parsedThreshold
            editing.updatedAt = Date()

            try await BudgetService.updateBudget(editing)
            if let index = budgets.firstIndex(where: { $0.id == editing.id }) {
                budgets[index] = editing
            }
            resetForm()
        } catch {
            errorMessage = "No se pudo actualizar el presupuesto. Intenta de nuevo."
        }
    }

    func deleteBudget(id: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await BudgetService.deleteBudget(id: id)
            budgets.removeAll { $0.id == id }
        } catch {
            errorMessage = "No se pudo eliminar el presupuesto. Intenta de nuevo."
        }
    }

    func prepareForEditing(budget: Budget) {
        editingBudget = budget
        selectedCategory = budget.category
        amountLimit = "\(budget.amountLimit)"
        period = budget.period
        alertThreshold = "\(budget.alertThreshold)"
    }

    func resetForm() {
        editingBudget = nil
        selectedCategory = .food
        amountLimit = ""
        period = .monthly
        alertThreshold = "0.8"
    }

    // MARK: - Private Helpers

    private func loadAlerts(coupleId: UUID) async {
        do {
            budgetAlerts = try await BudgetService.checkBudgetAlerts(coupleId: coupleId)
        } catch {
            budgetAlerts = []
        }
    }

    private func validateForm() -> Bool {
        if amountLimit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "El limite del presupuesto es obligatorio."
            return false
        }

        let parsedLimit = parseDecimal(amountLimit)
        if parsedLimit <= 0 {
            errorMessage = "El limite debe ser mayor a cero."
            return false
        }

        let parsedThreshold = parseDecimal(alertThreshold)
        if parsedThreshold <= 0 || parsedThreshold > 1 {
            errorMessage = "El umbral de alerta debe estar entre 0.01 y 1.0."
            return false
        }

        return true
    }

    /// Acepta digitos y un separador decimal ('.' o ','). Normaliza a punto.
    /// Bug fix #1: antes hacia `text.filter(\.isNumber)` y descartaba el separador,
    /// lo que rompia valores como "0.8" para alertThreshold.
    private func parseDecimal(_ text: String) -> Decimal {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .zero }

        // Permitir digitos y un solo separador decimal.
        var hasSeparator = false
        let cleaned: String = trimmed.reduce(into: "") { acc, char in
            if char.isNumber {
                acc.append(char)
            } else if (char == "." || char == ",") && !hasSeparator {
                acc.append(".")
                hasSeparator = true
            }
        }

        return Decimal(string: cleaned) ?? .zero
    }
}
