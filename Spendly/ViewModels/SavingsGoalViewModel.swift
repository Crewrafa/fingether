import Foundation

@MainActor
@Observable
final class SavingsGoalViewModel {

    // MARK: - State

    var goals: [SavingsGoal] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Form State

    var name = ""
    var description = ""
    var targetAmount = ""
    var targetDate: Date? = nil
    var emoji = "🎯"

    // MARK: - Editing

    var editingGoal: SavingsGoal?

    // MARK: - Actions

    func loadGoals(coupleId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            goals = try await SavingsGoalService.getGoals(coupleId: coupleId)
        } catch {
            errorMessage = "No se pudieron cargar las metas de ahorro. Intenta de nuevo."
        }
    }

    func createGoal(coupleId: UUID) async {
        guard validateForm() else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let parsedTarget = parseDecimal(targetAmount)
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

            let newGoal = SavingsGoal(
                id: UUID(),
                coupleId: coupleId,
                name: trimmedName,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                targetAmount: parsedTarget,
                currentAmount: 0,
                targetDate: targetDate,
                emoji: emoji,
                status: .active,
                createdAt: Date(),
                updatedAt: Date()
            )
            let created = try await SavingsGoalService.createGoal(newGoal)
            goals.append(created)
            resetForm()
        } catch {
            errorMessage = "No se pudo crear la meta de ahorro. Intenta de nuevo."
        }
    }

    func updateGoal() async {
        guard var editing = editingGoal else { return }
        guard validateForm() else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let parsedTarget = parseDecimal(targetAmount)
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

            editing.name = trimmedName
            editing.description = trimmedDescription.isEmpty ? nil : trimmedDescription
            editing.targetAmount = parsedTarget
            editing.targetDate = targetDate
            editing.emoji = emoji
            editing.updatedAt = Date()

            try await SavingsGoalService.updateGoal(editing)
            if let index = goals.firstIndex(where: { $0.id == editing.id }) {
                goals[index] = editing
            }
            resetForm()
        } catch {
            errorMessage = "No se pudo actualizar la meta de ahorro. Intenta de nuevo."
        }
    }

    func deleteGoal(id: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await SavingsGoalService.deleteGoal(id: id)
            goals.removeAll { $0.id == id }
        } catch {
            errorMessage = "No se pudo eliminar la meta de ahorro. Intenta de nuevo."
        }
    }

    func contribute(goalId: UUID, amount: Decimal) async {
        guard amount > 0 else {
            errorMessage = "El monto de contribucion debe ser mayor a cero."
            return
        }

        errorMessage = nil

        do {
            try await SavingsGoalService.contributeToGoal(goalId: goalId, amount: amount)
            // Reload the goal to get updated amount
            if let index = goals.firstIndex(where: { $0.id == goalId }) {
                goals[index].currentAmount += amount
                if goals[index].currentAmount >= goals[index].targetAmount {
                    goals[index].status = .completed
                }
            }
        } catch {
            errorMessage = "No se pudo registrar la contribucion. Intenta de nuevo."
        }
    }

    func prepareForEditing(goal: SavingsGoal) {
        editingGoal = goal
        name = goal.name
        description = goal.description ?? ""
        targetAmount = "\(goal.targetAmount)"
        targetDate = goal.targetDate
        emoji = goal.emoji
    }

    func resetForm() {
        editingGoal = nil
        name = ""
        description = ""
        targetAmount = ""
        targetDate = nil
        emoji = "🎯"
    }

    // MARK: - Computed Properties

    var activeGoals: [SavingsGoal] {
        goals.filter { $0.status == .active }
    }

    var completedGoals: [SavingsGoal] {
        goals.filter { $0.status == .completed }
    }

    var totalSaved: Decimal {
        goals
            .filter { $0.status == .active }
            .reduce(Decimal.zero) { $0 + $1.currentAmount }
    }

    var totalTarget: Decimal {
        goals
            .filter { $0.status == .active }
            .reduce(Decimal.zero) { $0 + $1.targetAmount }
    }

    // MARK: - Private Helpers

    private func validateForm() -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            errorMessage = "El nombre de la meta es obligatorio."
            return false
        }

        if targetAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "El monto objetivo es obligatorio."
            return false
        }

        let parsedTarget = parseDecimal(targetAmount)
        if parsedTarget <= 0 {
            errorMessage = "El monto objetivo debe ser mayor a cero."
            return false
        }

        return true
    }

    private func parseDecimal(_ text: String) -> Decimal {
        let digits = text.filter(\.isNumber)
        return Decimal(string: digits) ?? Decimal.zero
    }
}
