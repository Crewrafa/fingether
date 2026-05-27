import Foundation
import Supabase

// MARK: - Monthly Summary

struct MonthlySummary: Sendable {
    let totalIncome: Decimal
    let totalExpenses: Decimal
    let netBalance: Decimal
    let categoryBreakdown: [TransactionCategory: Decimal]
    let transactionCount: Int
    let topCategory: TransactionCategory?
}

// MARK: - Dashboard Service

enum DashboardService {

    private static var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    // MARK: - Get Monthly Summary

    /// Obtiene el resumen mensual de la pareja llamando al RPC get_monthly_summary
    static func getMonthlySummary(coupleId: UUID, month: Date) async throws -> MonthlySummary {
        if MockDataService.shared.isEnabled {
            return MockDataService.shared.getMockMonthlySummary(coupleId: coupleId, month: month)
        }
        struct RawSummary: Decodable {
            let totalIncome: Decimal
            let totalExpenses: Decimal
            let netBalance: Decimal
            let categoryBreakdown: [String: Decimal]
            let transactionCount: Int
            let topCategory: String?

            enum CodingKeys: String, CodingKey {
                case totalIncome = "total_income"
                case totalExpenses = "total_expenses"
                case netBalance = "net_balance"
                case categoryBreakdown = "category_breakdown"
                case transactionCount = "transaction_count"
                case topCategory = "top_category"
            }
        }

        let params: [String: AnyJSON] = [
            "p_couple_id": .string(coupleId.uuidString),
            "p_month": .string(month.apiFormatted)
        ]

        let results: [RawSummary] = try await client
            .rpc("get_monthly_summary", params: params)
            .execute()
            .value

        guard let raw = results.first else {
            return MonthlySummary(
                totalIncome: 0,
                totalExpenses: 0,
                netBalance: 0,
                categoryBreakdown: [:],
                transactionCount: 0,
                topCategory: nil
            )
        }

        // Convert string keys to TransactionCategory
        var breakdown: [TransactionCategory: Decimal] = [:]
        for (key, value) in raw.categoryBreakdown {
            if let category = TransactionCategory(rawValue: key) {
                breakdown[category] = value
            }
        }

        let topCategory: TransactionCategory? = raw.topCategory.flatMap { TransactionCategory(rawValue: $0) }

        return MonthlySummary(
            totalIncome: raw.totalIncome,
            totalExpenses: raw.totalExpenses,
            netBalance: raw.netBalance,
            categoryBreakdown: breakdown,
            transactionCount: raw.transactionCount,
            topCategory: topCategory
        )
    }
}
