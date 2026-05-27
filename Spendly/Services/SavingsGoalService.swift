import Foundation
import Supabase

// MARK: - Savings Goal Service

enum SavingsGoalService {

    private static var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    // MARK: - Create Goal

    /// Crea una nueva meta de ahorro
    static func createGoal(_ goal: SavingsGoal) async throws -> SavingsGoal {
        if MockDataService.shared.isEnabled {
            return MockDataService.shared.addMockGoal(goal)
        }

        let created: SavingsGoal = try await client
            .from("savings_goals")
            .insert(goal)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    // MARK: - Update Goal

    /// Actualiza una meta de ahorro existente
    static func updateGoal(_ goal: SavingsGoal) async throws {
        if MockDataService.shared.isEnabled {
            MockDataService.shared.updateMockGoal(goal)
            return
        }

        try await client
            .from("savings_goals")
            .update(goal)
            .eq("id", value: goal.id.uuidString)
            .execute()
    }

    // MARK: - Delete Goal

    /// Elimina una meta de ahorro por su ID
    static func deleteGoal(id: UUID) async throws {
        if MockDataService.shared.isEnabled {
            MockDataService.shared.deleteMockGoal(id: id)
            return
        }

        try await client
            .from("savings_goals")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Get Goals

    /// Obtiene todas las metas de ahorro de la pareja
    static func getGoals(coupleId: UUID) async throws -> [SavingsGoal] {
        if MockDataService.shared.isEnabled {
            return MockDataService.shared.getMockGoals(coupleId: coupleId)
        }

        let goals: [SavingsGoal] = try await client
            .from("savings_goals")
            .select()
            .eq("couple_id", value: coupleId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        return goals
    }

    // MARK: - Contribute to Goal

    /// Agrega una contribución a una meta de ahorro
    static func contributeToGoal(goalId: UUID, amount: Decimal) async throws {
        if MockDataService.shared.isEnabled {
            MockDataService.shared.contributeMockToGoal(goalId: goalId, amount: amount)
            return
        }

        // Primero obtener el monto actual
        let goal: SavingsGoal = try await client
            .from("savings_goals")
            .select()
            .eq("id", value: goalId.uuidString)
            .single()
            .execute()
            .value

        let newAmount = goal.currentAmount + amount
        let newStatus: String = newAmount >= goal.targetAmount ? "completed" : goal.status.rawValue

        try await client
            .from("savings_goals")
            .update([
                "current_amount": AnyJSON.double(newAmount.doubleValue),
                "status": AnyJSON.string(newStatus)
            ])
            .eq("id", value: goalId.uuidString)
            .execute()
    }
}
