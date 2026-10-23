import SwiftUI

struct PauseView: View {
    let onResume: () -> Void
    let onRestart: () -> Void
    let onSettings: () -> Void
    let onLeave: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("NIGHT PAUSED")
                    .font(Theme.screenTitle())
                    .tracking(1.2)
                    .foregroundStyle(Theme.primaryText)
                    .padding(.bottom, 8)
                ChorusButton(title: "RESUME", action: onResume)
                ChorusButton(title: "RESTART ENCOUNTER", kind: .secondary, action: onRestart)
                ChorusButton(title: "SETTINGS", kind: .secondary, action: onSettings)
                ChorusButton(title: "LEAVE CHAPTER", kind: .danger, action: onLeave)
            }
            .padding(24)
        }
        .accessibilityAddTraits(.isModal)
    }
}

struct ResultView: View {
    let result: GameResult
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var save: SaveService
    @EnvironmentObject private var purchase: PurchaseService
    @EnvironmentObject private var audio: AudioService
    @State private var confirmReplay = false

    var body: some View {
        let chapter = ContentCatalog.chapter(result.chapterID)
        ZStack {
            ArtImage(name: chapter?.background ?? "bg_chapter_10_red_moon")
                .scaledToFill()
                .ignoresSafeArea()
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("CHAPTER COMPLETE")
                    .font(Theme.screenTitle())
                    .tracking(1.2)
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.center)
                Text(chapter?.title ?? "")
                    .font(Theme.sectionTitle())
                    .foregroundStyle(Theme.iceWhite)
                Text(result.result.badge)
                    .font(Theme.buttonLabel())
                    .foregroundStyle(result.result.packStayedTogether ? Theme.moonCyan : Theme.emberGold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .overlay(Capsule().stroke(Theme.iceWhite.opacity(0.4), lineWidth: 1))
                if result.chapterID == 11 {
                    Text("WHITE MOON — THE FROZEN VOICE")
                        .font(Theme.caption())
                        .foregroundStyle(Theme.iceWhite)
                        .multilineTextAlignment(.center)
                }
                VStack(alignment: .leading, spacing: 8) {
                    row("Pack stayed together", result.result.packStayedTogether ? "Yes" : "No")
                    row("Memories found", "\(result.result.memoriesFound) / \(result.result.memoriesTotal)")
                    row("Forest attention", result.result.forestAttention)
                }
                .frame(maxWidth: 320, alignment: .leading)
                .padding(.vertical, 8)
                if let next = nextChapter {
                    ChorusButton(title: "NEXT CHAPTER") {
                        router.setStack([.briefing(chapterID: next)])
                    }
                }
                if result.chapterID == 10 {
                    ChorusButton(title: "VIEW FINAL MEMORY", kind: .secondary) {
                        router.focusMemoryID = 8
                        router.returnHomeAfterMemory = true
                        router.setStack([.memories])
                    }
                }
                ChorusButton(title: "REPLAY", kind: .secondary) { confirmReplay = true }
                ChorusButton(title: "CHAPTERS", kind: .secondary) { router.setStack([.chapterSelect]) }
                ChorusButton(title: "HOME", kind: .secondary) {
                    audio.playMusic("music_home", loop: true)
                    audio.stopAmbient()
                    router.setStack([])
                }
            }
            .padding(24)
        }
        .confirmationDialog("REPLAY CHAPTER", isPresented: $confirmReplay, titleVisibility: .visible) {
            Button("REPLAY CHAPTER") {
                router.openGame(
                    mode: .campaign(chapterID: result.chapterID, resumeSuspended: false),
                    music: chapter?.music ?? "music_exploration",
                    ambient: chapter?.ambient ?? "amb_blue_forest",
                    audio: audio
                )
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var nextChapter: Int? {
        let id = result.chapterID
        guard id < 10 else { return nil }
        let next = id + 1
        return save.isPlayable(next, ownsWhiteMoon: purchase.owned) ? next : nil
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.body())
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            Text(value)
                .font(Theme.buttonLabel())
                .foregroundStyle(Theme.primaryText)
        }
    }
}
