import SwiftUI

struct LaunchView: View {
    var body: some View {
        ZStack {
            ArtImage(name: "img_launch_background")
                .scaledToFill()
                .ignoresSafeArea()
            ArtImage(name: "img_title_logo")
                .scaledToFit()
                .frame(width: 250)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.nightNavy)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Wolf Chorus")
    }
}

struct HomeView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var save: SaveService
    @EnvironmentObject private var purchase: PurchaseService
    @EnvironmentObject private var preferences: Preferences
    @State private var confirmNewJourney = false

    var body: some View {
        GeometryReader { geo in
            let theme = purchase.owned && save.data.whiteMoonThemeEnabled
            ZStack(alignment: .topTrailing) {
                MenuBackground(image: theme ? "bg_chapter_11_frozen_valley" : "img_home_background") {
                    VStack(spacing: 0) {
                        logo
                            .padding(.top, geo.safeAreaInsets.top + 34)
                        Spacer(minLength: 12)
                        ScrollView {
                            VStack(spacing: 10) {
                                buttons
                            }
                            .padding(.horizontal, 24)
                            .frame(maxWidth: .infinity)
                        }
                        .frame(maxHeight: geo.size.height * 0.62)
                        Text(BundleInfo.versionLabel)
                            .font(Theme.caption())
                            .foregroundStyle(Theme.secondaryText)
                            .padding(.bottom, max(12, geo.safeAreaInsets.bottom + 8))
                            .accessibilityLabel(BundleInfo.versionLabel)
                    }
                }
                IconButton(icon: "ui_icon_settings", label: "Settings", sound: .open) {
                    router.push(.settings)
                }
                .padding(.top, geo.safeAreaInsets.top + 8)
                .padding(.trailing, 16)
            }
        }
        .confirmationDialog("Begin a New Journey?", isPresented: $confirmNewJourney, titleVisibility: .visible) {
            Button("Begin Again", role: .destructive) {
                save.newJourney()
                router.push(.briefing(chapterID: 1))
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Campaign progress and chapter results will be reset. Memories and your White Moon purchase will remain.")
        }
    }

    private var logo: some View {
        ZStack {
            Circle()
                .fill(Theme.moonCyan.opacity(0.45))
                .frame(width: 180, height: 180)
                .blur(radius: 30)
                .modifier(GlowPulse(enabled: !preferences.reduceMotion))
            ArtImage(name: "img_title_logo")
                .scaledToFit()
                .frame(width: 285)
                .accessibilityLabel("Wolf Chorus")
        }
    }

    @ViewBuilder
    private var buttons: some View {
        if save.data.campaignStarted {
            let chapter = save.continueChapterID(ownsWhiteMoon: purchase.owned)
            let suspended = save.data.suspendedCampaign?.chapterID == chapter
            ChorusButton(title: suspended ? "RESUME NIGHT" : "CONTINUE") {
                router.push(.briefing(chapterID: chapter))
            }
        }
        ChorusButton(title: "NEW JOURNEY", kind: save.data.hasCampaignProgress ? .secondary : .primary) {
            if save.data.hasCampaignProgress {
                confirmNewJourney = true
            } else {
                router.push(.briefing(chapterID: 1))
            }
        }
        ChorusButton(title: "CHAPTERS", kind: .secondary) { router.push(.chapterSelect) }
        let endlessOpen = save.data.completedChapterIDs.contains(3)
        ChorusButton(
            title: endlessOpen ? "ENDLESS NIGHT" : "ENDLESS NIGHT · COMPLETE CHAPTER 3",
            kind: .secondary,
            enabled: endlessOpen
        ) { router.push(.endlessSetup) }
        ChorusButton(title: "THE PACK", kind: .secondary) { router.push(.pack) }
        ChorusButton(title: "MEMORIES", kind: .secondary) { router.push(.memories) }
        ChorusButton(title: purchase.owned ? "WHITE MOON · OWNED" : "WHITE MOON", kind: .secondary) {
            router.push(.whiteMoon)
        }
    }
}

private struct GlowPulse: ViewModifier {
    var enabled: Bool
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .opacity(enabled ? (on ? 0.85 : 0.4) : 0.55)
            .onAppear {
                guard enabled else { return }
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { on = true }
            }
    }
}
