import SwiftUI

struct PackView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var save: SaveService
    @EnvironmentObject private var purchase: PurchaseService
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var haptics: HapticsService
    @State private var selected = "arkan"
    @State private var howling = false
    @State private var showHowl = false

    private var order: [WolfDefinition] { ContentCatalog.wolves }

    var body: some View {
        let wolf = ContentCatalog.wolf(selected)
        let unlocked = save.data.unlockedWolfIDs.contains(selected) || (selected == "lumi" && purchase.owned)
        MenuBackground(image: "bg_pack_den") {
            VStack(spacing: 0) {
                TopBar(title: "THE PACK", back: { router.pop() })
                Spacer(minLength: 0)
                ZStack {
                    if let wolf {
                        ArtImage(name: showHowl ? wolf.bodyHowl : wolf.bodyIdle)
                            .scaledToFit()
                            .frame(maxWidth: 320, maxHeight: 360)
                            .opacity(unlocked ? 1 : 0.45)
                            .rotationEffect(.degrees(showHowl ? -3 : 0))
                            .animation(.easeInOut(duration: 0.12), value: showHowl)
                            .id(wolf.id + (showHowl ? "-howl" : "-idle"))
                            .transition(.opacity)
                    }
                    if !unlocked {
                        ArtImage(name: "ui_icon_lock")
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(swipe)
                .onTapGesture { playHowl(wolf) }
                .animation(.easeInOut(duration: 0.25), value: selected)
                if let wolf {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(wolf.name) · \(wolf.role)")
                            .font(Theme.sectionTitle())
                            .foregroundStyle(Theme.primaryText)
                        if unlocked {
                            Text(wolf.howlName)
                                .font(Theme.caption())
                                .foregroundStyle(Theme.moonCyan)
                            Text(wolf.biography)
                                .font(Theme.body())
                                .foregroundStyle(Theme.secondaryText)
                                .lineLimit(2)
                            bar("Trust", wolf.trust, Theme.moonCyan)
                            bar("Instinct", wolf.instinct, Theme.emberGold)
                        } else {
                            Text(wolf.unlockInstruction(save: save.data))
                                .font(Theme.body())
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(order) { item in
                            let open = isUnlocked(item.id)
                            Button {
                                if item.id == "lumi", !open {
                                    router.push(.whiteMoon)
                                    return
                                }
                                if !open {
                                    audio.playSFX("sfx_ui_locked")
                                    haptics.locked()
                                    selected = item.id
                                    return
                                }
                                withAnimation(.easeInOut(duration: 0.25)) { selected = item.id }
                            } label: {
                                ZStack {
                                    ArtImage(name: item.portraitCalm)
                                        .scaledToFill()
                                        .frame(width: 58, height: 58)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(selected == item.id ? Theme.moonCyan : Color.clear, lineWidth: 2))
                                        .opacity(open ? 1 : 0.45)
                                    if !open {
                                        ArtImage(name: "ui_icon_lock")
                                            .scaledToFit()
                                            .frame(width: 18, height: 18)
                                    }
                                }
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel(open ? item.name : "\(item.name), \(item.unlockInstruction(save: save.data))")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private func isUnlocked(_ id: String) -> Bool {
        if id == "lumi" { return purchase.owned && save.data.unlockedWolfIDs.contains("lumi") }
        return save.data.unlockedWolfIDs.contains(id)
    }

    private func playHowl(_ wolf: WolfDefinition?) {
        guard let wolf, isUnlocked(wolf.id), !howling else { return }
        howling = true
        showHowl = true
        audio.playSFX(wolf.vocalMedium)
        haptics.wolfSelect()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            showHowl = false
            howling = false
        }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24).onEnded { value in
            let unlocked = order.filter { isUnlocked($0.id) }
            guard let index = unlocked.firstIndex(where: { $0.id == selected }) else { return }
            if value.translation.width < -40, index + 1 < unlocked.count {
                withAnimation(.easeInOut(duration: 0.25)) { selected = unlocked[index + 1].id }
            } else if value.translation.width > 40, index > 0 {
                withAnimation(.easeInOut(duration: 0.25)) { selected = unlocked[index - 1].id }
            }
        }
    }

    private func bar(_ title: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.caption())
                .foregroundStyle(Theme.secondaryText)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule().fill(color).frame(width: geo.size.width * value / 100)
                }
            }
            .frame(height: 8)
            .accessibilityLabel("\(title)")
        }
    }
}
