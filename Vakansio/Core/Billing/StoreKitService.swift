import Foundation
import Combine
import StoreKit

/// StoreKit 2 implementation for the Starter / Pro / Business subscriptions.
/// Prepared for later activation in App Store Connect.
/// No StoreKit configuration or entitlement is added to the project yet.
enum VakansioStoreProduct: String, CaseIterable, Identifiable {
    case starter = "com.kvuua.vakansio.starter"
    case pro = "com.kvuua.vakansio.pro"
    case business = "com.kvuua.vakansio.business"

    var id: String { rawValue }

    var tier: SubscriptionTier {
        switch self {
        case .starter: return .start
        case .pro: return .pro
        case .business: return .business
        }
    }

    var rank: Int {
        switch self {
        case .starter: return 0
        case .pro: return 1
        case .business: return 2
        }
    }
}

enum StoreKitServiceError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        "Не вдалося перевірити транзакцію App Store."
    }
}

@MainActor
final class StoreKitService: ObservableObject {
    static let isEnabled = true

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedTier: SubscriptionTier = .start
    @Published private(set) var isLoading = false
    @Published private(set) var latestJWS: String?
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    func startListening() {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let identifiers = VakansioStoreProduct.allCases.map(\.rawValue)
            let loadedProducts = try await Product.products(for: identifiers)
            products = loadedProducts.sorted { lhs, rhs in
                rank(for: lhs) < rank(for: rhs)
            }
            await refreshEntitlements()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchase(_ product: Product) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                latestJWS = verification.jwsRepresentation
                await transaction.finish()
                await refreshEntitlements()

            case .userCancelled:
                break

            case .pending:
                errorMessage = "Покупка очікує підтвердження."

            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var activeProduct: VakansioStoreProduct?

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard let product = VakansioStoreProduct(rawValue: transaction.productID) else { continue }

            if activeProduct == nil || product.rank > activeProduct!.rank {
                activeProduct = product
            }
        }

        purchasedTier = activeProduct?.tier ?? .start
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            do {
                let transaction = try checkVerified(result)
                latestJWS = result.jwsRepresentation
                await transaction.finish()
                await refreshEntitlements()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitServiceError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func rank(for product: Product) -> Int {
        VakansioStoreProduct(rawValue: product.id)?.rank ?? 0
    }
}
