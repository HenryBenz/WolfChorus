import SpriteKit
import SwiftUI

final class GameBox {
    let session: GameSession
    let scene: ForestScene

    init(mode: GameMode, save: SaveService, audio: AudioService, haptics: HapticsService, preferences: Preferences, ownsWhiteMoon: Bool) {
        session = GameSession(mode: mode, save: save, audio: audio, haptics: haptics, ownsWhiteMoon: ownsWhiteMoon)
        session.apply(preferences: preferences)
        scene = ForestScene(session: session)
        scene.scaleMode = .resizeFill
    }
}

struct GameContainerView: View {
    let mode: GameMode
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var save: SaveService
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var haptics: HapticsService
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var purchase: PurchaseService
    @State private var box: GameBox?
    @State private var confirmRestart = false
    @State private var confirmLeave = false
    @State private var confirmReplay = false

    var body: some View {
        ZStack {
            if let box {
                GameScreen(
                    session: box.session,
                    scene: box.scene,
                    confirmRestart: $confirmRestart,
                    confirmLeave: $confirmLeave
                )
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .onAppear(perform: setup)
        .onReceive(NotificationCenter.default.publisher(for: .wolfChorusSystemPause)) { _ in
            box?.session.systemPause()
        }
        .onChange(of: preferences.reduceMotion) { _, _ in box?.session.apply(preferences: preferences) }
        .onChange(of: preferences.highContrast) { _, _ in box?.session.apply(preferences: preferences) }
        .onChange(of: preferences.haptics) { _, _ in box?.session.apply(preferences: preferences) }
        .alert("Restart this encounter from its beginning?", isPresented: $confirmRestart) {
            Button("Cancel", role: .cancel) {}
            Button("Restart", role: .destructive) { box?.session.restartEncounter() }
        }
        .alert("Leave now? Your current encounter will be saved.", isPresented: $confirmLeave) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) { box?.session.leaveChapter() }
        }
    }

    private func setup() {
        guard box == nil else { return }
        let created = GameBox(
            mode: mode,
            save: save,
            audio: audio,
            haptics: haptics,
            preferences: preferences,
            ownsWhiteMoon: purchase.owned
        )
        created.session.onCampaignResult = { result in
            Task { @MainActor in
                audio.playMusic("music_result", loop: false)
                var next = router.routes
                next.removeAll {
                    if case .game = $0 { return true }
                    if case .result = $0 { return true }
                    return false
                }
                next.append(.result(result))
                router.setStack(next)
            }
        }
        created.session.onEndlessResult = { result in
            Task { @MainActor in
                audio.playMusic("music_result", loop: false)
                var next = router.routes
                next.removeAll {
                    if case .game = $0 { return true }
                    if case .endlessResult = $0 { return true }
                    return false
                }
                next.append(.endlessResult(result))
                router.setStack(next)
            }
        }
        created.session.onLeave = {
            Task { @MainActor in
                audio.playMusic(homeMusic, loop: true)
                audio.stopAmbient()
                router.setStack([])
            }
        }
        box = created
    }

    private var homeMusic: String { "music_home" }
}

private struct GameScreen: View {
    @ObservedObject var session: GameSession
    let scene: ForestScene
    @Binding var confirmRestart: Bool
    @Binding var confirmLeave: Bool
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack {
            SpriteView(scene: scene, options: [.allowsTransparency])
                .ignoresSafeArea()
            GameHUDView(
                hud: session.hud,
                onPause: { session.pauseFromUser() },
                onSelect: { session.selectWolf($0) },
                onSkip: { session.skipTutorial() },
                onRetry: { session.retryFromFailure() },
                onLeaveFailure: { session.leaveFromFailure() }
            )
            if session.hud.paused {
                PauseView(
                    onResume: { session.beginResume() },
                    onRestart: { confirmRestart = true },
                    onSettings: { router.modal = .settings },
                    onLeave: { confirmLeave = true }
                )
            }
        }
    }
}
