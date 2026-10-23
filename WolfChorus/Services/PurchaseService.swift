import Combine
import StoreKit

enum RestoreOutcome: Equatable {
    case restored
    case nothing
    case failed
}

@MainActor
final class PurchaseService: ObservableObject {
    static let productID = "com.northmoon.wolfchorus.white_moon"

    @Published private(set) var product: Product?
    @Published private(set) var owned = false
    @Published private(set) var isLoadingProduct = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published var pendingBanner = false
    @Published var alert: PurchaseAlert?

    private var updates: Task<Void, Never>?
    private var intents: Task<Void, Never>?
    private var purchasingInternally = false
    private let save: SaveService

    init(save: SaveService) {
        self.save = save
        owned = save.data.whiteMoonOwnedCache
        listen()
    }

    func adoptCache() {
        owned = save.data.whiteMoonOwnedCache
    }

    func start() {
        listen()
        Task { await refreshEntitlements() }
        Task { await loadProduct() }
    }

    private func listen() {
        guard updates == nil, intents == nil else { return }
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        intents = Task { [weak self] in
            for await intent in PurchaseIntent.intents {
                await self?.handle(intent)
            }
        }
    }

    func loadProduct() async {
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            product = nil
        }
    }

    func refreshEntitlements() async {
        var found = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.productID else { continue }
            if transaction.revocationDate == nil {
                found = true
            }
        }
        applyOwnership(found, external: false)
    }

    func purchase() async {
        if product == nil { await loadProduct() }
        guard let product else { return }
        await purchase(product, options: [])
    }

    private func purchase(_ product: Product, options: Set<Product.PurchaseOption>) async {
        guard product.id == Self.productID else { return }
        guard !isPurchasing else { return }
        self.product = product
        isPurchasing = true
        purchasingInternally = true
        defer {
            isPurchasing = false
            purchasingInternally = false
        }
        do {
            let result = try await product.purchase(options: options)
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    applyOwnership(true, external: false)
                    alert = nil
                case .unverified:
                    alert = .unverified
                }
            case .userCancelled:
                break
            case .pending:
                alert = .pending
            @unknown default:
                break
            }
        } catch {
            alert = nil
        }
    }

    private func handle(_ intent: PurchaseIntent) async {
        guard intent.product.id == Self.productID else { return }
        var options: Set<Product.PurchaseOption> = []
        if #available(iOS 18.0, *) {
            if let offer = intent.offer, offer.type == .winBack {
                options.insert(.winBackOffer(offer))
            }
        }
        await purchase(intent.product, options: options)
    }

    func restore() async -> RestoreOutcome {
        guard !isRestoring else { return .failed }
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return owned ? .restored : .nothing
        } catch {
            return .failed
        }
    }

    private func handle(_ update: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = update else { return }
        guard transaction.productID == Self.productID else { return }
        await transaction.finish()
        if transaction.revocationDate != nil {
            applyOwnership(false, external: false)
        } else {
            applyOwnership(true, external: !purchasingInternally)
        }
    }

    private func applyOwnership(_ owned: Bool, external: Bool) {
        let was = self.owned
        self.owned = owned
        save.setOwned(owned, enableThemeIfNew: owned && !was)
        if owned && !was && external {
            pendingBanner = true
        }
    }
}

enum PurchaseAlert: Identifiable, Equatable {
    case pending
    case unverified
    case restored
    case nothing
    case failed

    var id: String { title + message }
    var title: String {
        switch self {
        case .pending: return "Purchase Pending"
        case .unverified: return "Purchase Could Not Be Verified"
        case .restored: return "Purchases Restored"
        case .nothing: return "Nothing to Restore"
        case .failed: return "Restore Failed"
        }
    }
    var message: String {
        switch self {
        case .pending: return "The purchase requires approval. White Moon will unlock automatically when approved."
        case .unverified: return "No chargeable content was unlocked. Please try again later."
        case .restored: return "Your White Moon content is available."
        case .nothing: return "No previous White Moon purchase was found for this Apple ID."
        case .failed: return "Please try again later."
        }
    }
}
