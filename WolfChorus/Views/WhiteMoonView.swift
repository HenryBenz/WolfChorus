import SwiftUI

struct WhiteMoonView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var save: SaveService
    @EnvironmentObject private var purchase: PurchaseService
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var haptics: HapticsService
    @State private var lastTap = Date.distantPast

    var body: some View {
        MenuBackground(image: "bg_chapter_11_frozen_valley") {
            VStack(spacing: 12) {
                TopBar(title: "WHITE MOON", back: { router.pop() })
                ScrollView {
                    VStack(spacing: 12) {
                        if let lumi = ContentCatalog.wolf("lumi") {
                            ArtImage(name: lumi.portraitCalm)
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Theme.iceWhite.opacity(0.5), lineWidth: 1))
                                .accessibilityLabel("Lumi")
                        }
                        Text("WHITE MOON")
                            .font(Theme.screenTitle())
                            .tracking(1.2)
                            .foregroundStyle(Theme.primaryText)
                        Text("A permanent expansion for Wolf Chorus")
                            .font(Theme.body())
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                        VStack(alignment: .leading, spacing: 6) {
                            feature("Lumi, a new playable wolf")
                            feature("The Frozen Voice bonus chapter")
                            feature("Frozen Echo ability in Endless Night")
                            feature("White Moon menu theme")
                            feature("A new musical theme")
                        }
                        .frame(maxWidth: 320, alignment: .leading)
                        .padding(.vertical, 8)
                        if purchase.owned {
                            Text("OWNED")
                                .font(Theme.buttonLabel())
                                .foregroundStyle(Theme.calmGreen)
                            if save.data.completedChapterIDs.contains(6) {
                                ChorusButton(title: "PLAY BONUS CHAPTER") {
                                    router.push(.briefing(chapterID: 11))
                                }
                            } else {
                                ChorusButton(title: "COMPLETE CHAPTER 6 TO PLAY", enabled: false) {}
                            }
                            Toggle(isOn: themeBinding) {
                                Text("Use White Moon Menu Theme")
                                    .font(Theme.body())
                                    .foregroundStyle(Theme.primaryText)
                            }
                            .tint(Theme.moonCyan)
                            .frame(maxWidth: 320)
                        } else {
                            ChorusButton(title: unlockTitle, enabled: canPurchase) { buy() }
                                .overlay { if purchase.isLoadingProduct || purchase.isPurchasing { ProgressView().tint(.white) } }
                            ChorusButton(title: "RESTORE PURCHASE", kind: .secondary, enabled: !purchase.isRestoring) {
                                Task {
                                    let outcome = await purchase.restore()
                                    switch outcome {
                                    case .restored: purchase.alert = .restored
                                    case .nothing: purchase.alert = .nothing
                                    case .failed: purchase.alert = .failed
                                    }
                                }
                            }
                            .overlay { if purchase.isRestoring { ProgressView().tint(.white) } }
                            Text("One-time purchase. No consumable items or subscription.")
                                .font(Theme.caption())
                                .foregroundStyle(Theme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .onAppear { Task { await purchase.loadProduct() } }
    }

    private var themeBinding: Binding<Bool> {
        Binding(
            get: { save.data.whiteMoonThemeEnabled },
            set: { save.setThemeEnabled($0) }
        )
    }

    private var canPurchase: Bool {
        purchase.product != nil && !purchase.isPurchasing && !purchase.isLoadingProduct
    }

    private var unlockTitle: String {
        if purchase.isPurchasing { return "PROCESSING…" }
        if purchase.isLoadingProduct { return "UNLOCK" }
        if let price = purchase.product?.displayPrice { return "UNLOCK · \(price)" }
        return "STORE UNAVAILABLE"
    }

    private func feature(_ text: String) -> some View {
        Text("• \(text)")
            .font(Theme.body())
            .foregroundStyle(Theme.primaryText)
    }

    private func buy() {
        let now = Date()
        guard now.timeIntervalSince(lastTap) >= 0.5 else { return }
        lastTap = now
        guard purchase.product != nil else { return }
        Task {
            let was = purchase.owned
            await purchase.purchase()
            if purchase.owned && !was {
                audio.playSFX("sfx_ui_success")
                haptics.purchaseSuccess()
            }
        }
    }
}
