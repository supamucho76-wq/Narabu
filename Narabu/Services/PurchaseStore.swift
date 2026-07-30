import Foundation
import Observation
import StoreKit

/// 意味のない行列を、お金を払って進む仕組み。
@MainActor
@Observable
final class PurchaseStore {
    static let skipProductID = "io.github.supamucho76wq.narabu.skip100"
    /// 一度の購入で追い抜ける人数。
    static let skipAmount = 100

    private(set) var skipProduct: Product?
    private(set) var isPurchasing = false
    var errorMessage: String?

    var priceLabel: String {
        skipProduct?.displayPrice ?? "¥160"
    }

    init() {
        guard !AppRuntime.isUITesting else { return }
        Task { await loadProducts() }
    }

    func loadProducts() async {
        do {
            skipProduct = try await Product.products(for: [Self.skipProductID]).first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 購入が成立したら true を返す。呼び出し側が実際に列を進める。
    func purchaseSkip() async -> Bool {
        #if DEBUG
        // 開発ビルドでは課金なしで追い抜ける。
        return true
        #else
        guard let skipProduct else {
            errorMessage = "商品を読み込めませんでした。通信環境を確認してください。"
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            switch try await skipProduct.purchase() {
            case .success(let verification):
                let transaction = try verified(verification)
                await transaction.finish()
                return true
            case .pending:
                errorMessage = "購入は承認待ちです。承認されると反映されます。"
            case .userCancelled:
                break
            @unknown default:
                errorMessage = "購入状態を確認できませんでした。"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        return false
        #endif
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): value
        case .unverified: throw PurchaseError.failedVerification
        }
    }
}

enum PurchaseError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        "購入情報を検証できませんでした。"
    }
}
