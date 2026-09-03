import Foundation
import StoreKit

/// One-time sponsor unlock. Product must exist in App Store Connect (and optionally
/// `Configuration.storekit` for local Xcode testing).
enum SponsorProduct {
    /// Non-consumable unlock for LLM + fuzzy toggle.
    static let unlockID = "com.jo1project.t9bopomofo.sponsor"
}

@MainActor
final class SponsorStore: ObservableObject {
    static let shared = SponsorStore()

    @Published private(set) var product: Product?
    @Published private(set) var isSponsored: Bool = AppSettings.shared.isSponsored
    @Published private(set) var statusMessage: String = ""
    @Published private(set) var isLoading: Bool = false

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { await listenForTransactions() }
        Task { await refresh() }
    }

    deinit {
        updatesTask?.cancel()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        await refreshEntitlements()
        do {
            let products = try await Product.products(for: [SponsorProduct.unlockID])
            product = products.first
            if product == nil {
                statusMessage = "找不到商品（請在 App Store Connect 建立 \(SponsorProduct.unlockID)）"
            } else {
                statusMessage = ""
            }
        } catch {
            statusMessage = "載入商品失敗：\(error.localizedDescription)"
        }
    }

    func purchase() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if product == nil {
                await refresh()
            }
            guard let product else {
                statusMessage = "尚無可用商品"
                return
            }
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                AppSettings.shared.isSponsored = true
                isSponsored = true
                statusMessage = "感謝贊助！"
            case .userCancelled:
                statusMessage = "已取消"
            case .pending:
                statusMessage = "購買處理中…"
            @unknown default:
                statusMessage = "未知結果"
            }
        } catch {
            statusMessage = "購買失敗：\(error.localizedDescription)"
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            statusMessage = isSponsored ? "已還原贊助資格" : "此帳號尚無贊助紀錄"
        } catch {
            statusMessage = "還原失敗：\(error.localizedDescription)"
        }
    }

    func unlockForTesting(note: String = "測試解鎖：已開啟贊助內容與 LLM 開關") {
        AppSettings.shared.isSponsored = true
        AppSettings.shared.llmEnabled = true
        isSponsored = true
        statusMessage = note
    }

    func clearTestingUnlock() {
        AppSettings.shared.isSponsored = false
        AppSettings.shared.llmEnabled = false
        isSponsored = false
        statusMessage = "已清除測試解鎖"
    }

    private func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == SponsorProduct.unlockID {
                entitled = true
                break
            }
        }
        // Keep manual / StoreKit-config unlocks already written to App Group.
        if entitled {
            AppSettings.shared.isSponsored = true
        } else if AppSettings.shared.isSponsored {
            // Local flag may be from StoreKit testing; keep it unless we explicitly cleared.
            entitled = true
        }
        isSponsored = entitled || AppSettings.shared.isSponsored
        if isSponsored {
            AppSettings.shared.isSponsored = true
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result),
               transaction.productID == SponsorProduct.unlockID {
                AppSettings.shared.isSponsored = true
                await MainActor.run {
                    self.isSponsored = true
                    self.statusMessage = "感謝贊助！"
                }
                await transaction.finish()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
