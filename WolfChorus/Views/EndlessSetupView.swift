import SwiftUI

struct EndlessSetupView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var save: SaveService
    @EnvironmentObject private var purchase: PurchaseService
    @EnvironmentObject private var audio: AudioService
    @State private var difficulty: String
    @State private var order: [String]

    init() {
        _difficulty = State(initialValue: "wild")
        _order = State(initialValue: ["arkan", "nora", "saira"])
    }

    private let choices = ["calm", "wild", "relentless"]

    var body: some View {
        MenuBackground(image: "bg_chapter_10_red_moon", dim: 0.55, dimColor: Theme.nightNavy) {
            VStack(spacing: 16) {
                TopBar(title: "ENDLESS NIGHT", back: { router.pop() })
                Picker("Difficulty", selection: $difficulty) {
                    Text("CALM").tag("calm")
                    Text("WILD").tag("wild")
                    Text("RELENTLESS").tag("relentless")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .accessibilityLabel("Difficulty")
                HStack(spacing: 10) {
                    ForEach(available, id: \.self) { id in
                        if let wolf = ContentCatalog.wolf(id) {
                            Button {
                                toggle(id)
                            } label: {
                                ArtImage(name: wolf.portraitCalm)
                                    .scaledToFill()
                                    .frame(width: 58, height: 58)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(order.contains(id) ? Theme.moonCyan : Color.clear, lineWidth: 2))
                                    .opacity(id == "arkan" || order.contains(id) ? 1 : 0.55)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel(wolf.name)
                        }
                    }
                }
                Text("Travel as far as possible before the pack scatters.")
                    .font(Theme.body())
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Text("\(save.data.endlessBestMeters[difficulty] ?? 0) m")
                    .font(Theme.hudNumber())
                    .foregroundStyle(Theme.iceWhite)
                    .accessibilityLabel("Best distance \(save.data.endlessBestMeters[difficulty] ?? 0) meters")
                Spacer()
                ChorusButton(title: "ENTER THE NIGHT", enabled: order.count == 3) {
                    save.rememberEndless(difficulty: difficulty, pack: order)
                    router.openGame(
                        mode: .endless(difficulty: difficulty, wolfIDs: order),
                        music: "music_danger",
                        ambient: "amb_open_valley",
                        audio: audio
                    )
                }
                .padding(.bottom, 24)
            }
        }
        .onAppear(perform: restore)
    }

    private var available: [String] {
        var ids = ["arkan", "nora", "saira", "rune", "mor"]
        ids = ids.filter { save.data.unlockedWolfIDs.contains($0) || $0 == "arkan" }
        if purchase.owned && save.data.unlockedWolfIDs.contains("lumi") {
            ids.append("lumi")
        }
        return ids
    }

    private func restore() {
        let savedDifficulty = save.data.lastEndlessDifficulty
        if choices.contains(savedDifficulty) { difficulty = savedDifficulty }
        let saved = save.data.lastEndlessPack.filter { available.contains($0) }
        if saved.contains("arkan"), saved.count == 3 {
            order = saved
        } else {
            var next = ["arkan"]
            for id in available where id != "arkan" && next.count < 3 {
                next.append(id)
            }
            order = next
        }
    }

    private func toggle(_ id: String) {
        if id == "arkan" { return }
        if let index = order.firstIndex(of: id) {
            order.remove(at: index)
            return
        }
        if order.count >= 3, let oldest = order.firstIndex(where: { $0 != "arkan" }) {
            order.remove(at: oldest)
        }
        order.append(id)
    }
}

struct EndlessResultView: View {
    let result: EndlessResult
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var preferences: Preferences
    @State private var pulse = false

    var body: some View {
        ZStack {
            ArtImage(name: "bg_chapter_10_red_moon")
                .scaledToFill()
                .ignoresSafeArea()
            Theme.nightNavy.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("THE NIGHT ENDS")
                    .font(Theme.screenTitle())
                    .tracking(1.2)
                    .foregroundStyle(Theme.primaryText)
                row("Distance traveled", "\(result.distanceMeters) m")
                row("Encounters survived", "\(result.encountersSurvived)")
                row("Memories collected", "\(result.memoriesCollected)")
                row("Best distance", "\(result.bestMeters) m")
                if result.isNewBest {
                    Text("NEW BEST")
                        .font(Theme.screenTitle(22))
                        .foregroundStyle(Theme.emberGold)
                        .scaleEffect(preferences.reduceMotion ? 1 : (pulse ? 1.06 : 1))
                        .onAppear {
                            guard !preferences.reduceMotion else { return }
                            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
                        }
                }
                ChorusButton(title: "TRY AGAIN") {
                    router.openGame(
                        mode: .endless(difficulty: result.difficulty, wolfIDs: result.wolfIDs),
                        music: "music_danger",
                        ambient: "amb_open_valley",
                        audio: audio
                    )
                }
                ChorusButton(title: "CHANGE PACK", kind: .secondary) {
                    router.setStack([.endlessSetup])
                }
                ChorusButton(title: "HOME", kind: .secondary) {
                    audio.playMusic("music_home", loop: true)
                    audio.stopAmbient()
                    router.setStack([])
                }
            }
            .padding(24)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(Theme.body())
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            Text(value)
                .font(Theme.hudNumber())
                .foregroundStyle(Theme.primaryText)
        }
        .frame(maxWidth: 320)
    }
}
