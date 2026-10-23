import SwiftUI
import UIKit

struct AppRootView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var save: SaveService
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var haptics: HapticsService
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var purchase: PurchaseService
    @Environment(\.scenePhase) private var scenePhase
    @State private var launched = false
    @State private var welcome = false

    var body: some View {
        ZStack {
            Theme.nightNavy.ignoresSafeArea()
            if launched {
                ZStack {
                    if router.routes.isEmpty, router.modal == nil {
                        HomeView()
                    }
                    ForEach(Array(router.routes.enumerated()), id: \.offset) { index, route in
                        if shouldShow(index) {
                            destination(route)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Theme.nightNavy.ignoresSafeArea())
                                .transition(.opacity)
                        }
                    }
                }
            }
            if !launched {
                LaunchView()
            }
            if router.black > 0.01 {
                Color.black.opacity(router.black)
                    .ignoresSafeArea()
                    .allowsHitTesting(router.black > 0.4)
            }
            if router.modal == .settings {
                SettingsView()
                    .transition(.opacity)
            }
            if let banner = router.banner {
                VStack {
                    Text(banner)
                        .font(Theme.buttonLabel())
                        .foregroundStyle(Theme.nightNavy)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Theme.emberGold))
                        .padding(.top, 72)
                    Spacer()
                }
                .allowsHitTesting(false)
            }
            if launched, !isGame {
                edgeBack
            }
        }
        .animation(.easeInOut(duration: 0.25), value: router.routes)
        .animation(.easeInOut(duration: 0.25), value: router.modal)
        .preferredColorScheme(.dark)
        .task { await startup() }
        .onChange(of: scenePhase) { _, phase in handlePhase(phase) }
        .onChange(of: router.routes) { _, routes in syncMenuAudio(routes) }
        .onChange(of: purchase.pendingBanner) { _, pending in
            guard pending, scenePhase == .active else { return }
            showUnlockBanner()
        }
        .alert("Welcome to Wolf Chorus", isPresented: $welcome) {
            Button("Begin") { save.markWelcomeSeen() }
        } message: {
            Text("Guide the pack with echoes, instinct, and trust. Headphones are recommended, but never required.")
        }
        .alert(purchase.alert?.title ?? "", isPresented: alertShown) {
            Button("OK", role: .cancel) { purchase.alert = nil }
        } message: {
            Text(purchase.alert?.message ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            // SpriteKit drops unreferenced textures. Keep the active chapter art by touching it.
            _ = UIImage(named: "ui_panel_dark")
        }
    }

    private var alertShown: Binding<Bool> {
        Binding(get: { purchase.alert != nil }, set: { if !$0 { purchase.alert = nil } })
    }

    private var isGame: Bool {
        if case .game = router.routes.last { return true }
        return false
    }

    private func shouldShow(_ index: Int) -> Bool {
        let routes = router.routes
        if index == routes.count - 1 { return true }
        if routes.last == .settings, index == routes.count - 2 { return true }
        return false
    }

    @ViewBuilder
    private func destination(_ route: AppRoute) -> some View {
        switch route {
        case .home:
            HomeView()
        case .chapterSelect:
            ChapterSelectView()
        case .briefing(let id):
            BriefingView(chapterID: id)
        case .game(let mode):
            GameContainerView(mode: mode)
        case .result(let result):
            ResultView(result: result)
        case .pack:
            PackView()
        case .memories:
            MemoriesView()
        case .endlessSetup:
            EndlessSetupView()
        case .endlessResult(let result):
            EndlessResultView(result: result)
        case .settings:
            SettingsView()
        case .whiteMoon:
            WhiteMoonView()
        }
    }

    private var edgeBack: some View {
        HStack {
            Color.clear
                .frame(width: 22)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20).onEnded { value in
                        guard value.translation.width > 80, router.modal == nil else { return }
                        router.pop()
                    }
                )
            Spacer()
        }
        .ignoresSafeArea()
    }

    private func startup() async {
        let start = Date()
        save.load()
        purchase.adoptCache()
        purchase.start()
        audio.start()
        haptics.enabled = preferences.haptics
        audio.setVolumes(music: preferences.music, sfx: preferences.sfx, ambient: preferences.ambient)
        let elapsed = Date().timeIntervalSince(start)
        if elapsed < 0.8 {
            try? await Task.sleep(nanoseconds: UInt64((0.8 - elapsed) * 1_000_000_000))
        }
        withAnimation(.easeInOut(duration: 0.25)) { launched = true }
        audio.playMusic("music_home", loop: true)
        if !save.data.hasSeenWelcome { welcome = true }
    }

    private func handlePhase(_ phase: ScenePhase) {
        switch phase {
        case .inactive:
            audio.noteSceneActive(false)
        case .background:
            audio.noteSceneActive(false)
            audio.enterBackground()
            save.retryIfNeeded()
            if isGame {
                NotificationCenter.default.post(name: .wolfChorusSystemPause, object: nil)
            }
        case .active:
            audio.noteSceneActive(true)
            audio.enterForeground()
            if purchase.pendingBanner { showUnlockBanner() }
        default:
            break
        }
    }

    private func showUnlockBanner() {
        purchase.pendingBanner = false
        router.banner = "White Moon Unlocked"
        audio.playSFX("sfx_ui_success")
        haptics.purchaseSuccess()
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if router.banner == "White Moon Unlocked" { router.banner = nil }
        }
    }

    private func syncMenuAudio(_ routes: [AppRoute]) {
        if case .game = routes.last { return }
        switch routes.last {
        case .whiteMoon:
            audio.playMusic("music_white_moon", loop: true)
        case .result, .endlessResult:
            audio.playMusic("music_result", loop: false)
        default:
            audio.playMusic("music_home", loop: true)
        }
    }
}

extension Notification.Name {
    static let wolfChorusSystemPause = Notification.Name("wolfChorusSystemPause")
}
