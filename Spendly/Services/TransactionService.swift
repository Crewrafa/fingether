import Foundation
import Supabase

// MARK: - Transaction Service

enum TransactionService {

    private static var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    // MARK: - Add Transaction

    /// Crea una nueva transacción
    static func addTransaction(_ transaction: Transaction) async throws -> Transaction {
        if MockDataService.shared.isEnabled {
            return MockDataService.shared.addMockTransaction(transaction)
        }

        let created: Transaction = try await client
            .from("transactions")
            .insert(transaction)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    // MARK: - Update Transaction

    /// Actualiza una transacción existente
    static func updateTransaction(_ transaction: Transaction) async throws {
        if MockDataService.shared.isEnabled {
            MockDataService.shared.updateMockTransaction(transaction)
            return
        }

        try await client
            .from("transactions")
            .update(transaction)
            .eq("id", value: transaction.id.uuidString)
            .execute()
    }

    // MARK: - Delete Transaction

    /// Elimina una transacción por su ID
    static func deleteTransaction(id: UUID) async throws {
        if MockDataService.shared.isEnabled {
            MockDataService.shared.deleteMockTransaction(id: id)
            return
        }

        try await client
            .from("transactions")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Get Transactions (filtered)

    /// Obtiene transacciones de la pareja con filtros opcionales
    static func getTransactions(
        coupleId: UUID,
        month: Date? = nil,
        category: TransactionCategory? = nil,
        type: TransactionType? = nil
    ) async throws -> [Transaction] {
        if MockDataService.shared.isEnabled {
            return MockDataService.shared.getMockTransactions(coupleId: coupleId, month: month, category: category, type: type)
        }

        var query = client
            .from("transactions")
            .select()
            .eq("couple_id", value: coupleId.uuidString)

        if let month {
            let start = month.startOfMonth.apiFormatted
            let end = month.endOfMonth.apiFormatted
            query = query
                .gte("date", value: start)
                .lte("date", value: end)
        }

        if let category {
            query = query.eq("category", value: category.rawValue)
        }

        if let type {
            query = query.eq("type", value: type.rawValue)
        }

        let transactions: [Transaction] = try await query
            .order("date", ascending: false)
            .execute()
            .value

        return transactions
    }

    // MARK: - Get Recent Transactions

    /// Obtiene las transacciones más recientes de la pareja
    static func getRecentTransactions(coupleId: UUID, limit: Int = 10) async throws -> [Transaction] {
        if MockDataService.shared.isEnabled {
            return MockDataService.shared.getMockRecentTransactions(coupleId: coupleId, limit: limit)
        }

        let transactions: [Transaction] = try await client
            .from("transactions")
            .select()
            .eq("couple_id", value: coupleId.uuidString)
            .order("date", ascending: false)
            .limit(limit)
            .execute()
            .value

        return transactions
    }
}
