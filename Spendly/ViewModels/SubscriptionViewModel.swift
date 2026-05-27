import Foundation
import StoreKit

@MainActor
@Observable
final class SubscriptionViewModel {

    // MARK: - State

    var products: [Product] = []
    var currentTier: SubscriptionTier = .free
    var isLoading = false
    var errorMessage: String?
    var purchaseSuccessMessage: String?

    // MARK: - Product IDs

    private let productIds: Set<String> = [
        "com.fingether.premium.monthly",
        "com.fingether.premium.yearly"
    ]

    // MARK: - Computed Properties

    var isPremium: Bool {
        currentTier == .premium
    }

    // MARK: - Actions

    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            products = try await Product.products(for: productIds)
                .sorted { $0.price < $1.price }
        } catch {
            errorMessage = "No se pudieron cargar los planes disponibles. Intenta de nuevo."
        }
    }

    func purchase(product: Product) async {
        isLoading = true
        errorMessage = nil
        purchaseSuccessMessage = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                currentTier = .premium
                // Bug fix #3: persist subscription locally so currentTier survives app launches
                // (and prepare the path for Supabase persistence when the table is wired up).
                persistPremium(transaction: transaction, productId: product.id)
                purchaseSuccessMessage = "Bienvenido a Fingether Premium. Disfruta todas las funciones."
                await transaction.finish()

            case .userCancelled:
                break

            case .pending:
                errorMessage = "La compra esta pendiente de aprobacion."

            @unknown default:
                errorMessage = "Resultado de compra desconocido."
            }
        } catch {
            errorMessage = "No se pudo completar la compra. Intenta de nuevo."
        }
    }

    /// Persiste la suscripcion en MockDataService y actualiza el tier del perfil mock.
    /// Cuando exista la tabla `subscriptions` en Supabase, agregar aqui la llamada a
    /// SubscriptionService.upsert(subscription) en el path real.
    private func persistPremium(transaction: StoreKit.Transaction, productId: String) {
        let mock = MockDataService.shared
        guard let profile = mock.mockProfile else { return }

        let sub = Subscription(
            id: UUID(),
            userId: profile.id,
            productId: productId,
            tier: .premium,
            isActive: true,
            originalTransactionId: String(transaction.originalID),
            purchaseDate: transaction.purchaseDate,
            expirationDate: transaction.expirationDate,
            createdAt: Date(),
            updatedAt: Date()
        )
        mock.persistMockSubscription(sub)
    }

    func restore() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()

            var foundPremium = false
            for await result in StoreKit.Transaction.currentEntitlements {
                if let transaction = try? checkVerified(result) {
                    if productIds.contains(transaction.productID) {
                        foundPremium = true
                        break
                    }
                }
            }

            if foundPremium {
                currentTier = .premium
                // Persist the restored state too (Bug fix #3).
                MockDataService.shared.markMockProfilePremium(true)
                purchaseSuccessMessage = "Se restauro tu suscripcion Premium."
            } else {
                errorMessage = "No se encontraron compras anteriores."
            }
        } catch {
            errorMessage = "No se pudieron restaurar las compras. Intenta de nuevo."
        }
    }

    func checkStatus() async {
        var foundPremium = false

        for await result in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if productIds.contains(transaction.productID) {
                    foundPremium = true
                    break
                }
            }
        }

        currentTier = foundPremium ? .premium : .free
    }

    // MARK: - Private Helpers

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
