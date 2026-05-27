import Foundation
import Supabase

// MARK: - Budget Alert

struct BudgetAlertResponse: Codable, Identifiable, Sendable {
    var id: UUID { budgetId }
    let budgetId: UUID
    let category: TransactionCategory
    let percentageUsed: Decimal
    let amountLimit: Decimal
    let currentSpent: Decimal

    enum CodingKeys: String, CodingKey {
        case budgetId = "budget_id"
        case category
        case percentageUsed = "percentage_used"
        case amountLimit = "amount_limit"
        case currentSpent = "current_spent"
    }
}

// MARK: - Budget Service

enum BudgetService {

    private static var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    // MARK: - Create Budget

    /// Crea un nuevo presupuesto
    static func createBudget(_ budget: Budget) async throws -> Budget {
        if MockDataService.shared.isEnabled {
            return MockDataService.shared.addMockBudget(budget)
        }

        let created: Budget = try await client
            .from("budgets")
            .insert(budget)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    // MARK: - Update Budget

    /// Actualiza un presupuesto existente
    static func updateBudget(_ budget: Budget) async throws {
        if MockDataService.shared.isEnabled {
            MockDataService.shared.updateMockBudget(budget)
            return
        }

        try await client
            .from("budgets")
            .update(budget)
            .eq("id", value: budget.id.uuidString)
            .execute()
    }

    // MARK: - Delete Budget

    /// Elimina un presupuesto por su ID
    static func deleteBudget(id: UUID) async throws {
        if MockDataService.shared.isEnabled {
            MockDataService.shared.deleteMockBudget(id: id)
            return
        }

        try await client
            .from("budgets")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Get Budgets

    /// Obtiene todos los presupuestos de la pareja
    static func getBudgets(coupleId: UUID) async throws -> [Budget] {
        if MockDataService.shared.isEnabled {
            return MockDataService.shared.getMockBudgets(coupleId: coupleId)
        }

        let budgets: [Budget] = try await client
            .from("budgets")
            .select()
            .eq("couple_id", value: coupleId.uuidString)
            .eq("is_active", value: true)
            .order("category", ascending: true)
            .execute()
            .value

        return budgets
    }

    // MARK: - Check Budget Alerts

    /// Verifica qué presupuestos han superado su umbral de alerta
    static func checkBudgetAlerts(coupleId: UUID) async throws -> [BudgetAlertResponse] {
        if MockDataService.shared.isEnabled {
            return MockDataService.shared.getMockBudgetAlerts(coupleId: coupleId)
        }

        let params: [String: AnyJSON] = [
            "p_couple_id": .string(coupleId.uuidString)
        ]

        let alerts: [BudgetAlertResponse] = try await client
            .rpc("check_budget_alerts", params: params)
            .execute()
            .value

        return alerts
    }
}
