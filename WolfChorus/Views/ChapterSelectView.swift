import SwiftUI

struct ChapterSelectView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var save: SaveService
    @EnvironmentObject private var purchase: PurchaseService
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var haptics: HapticsService

    var body: some View {
        MenuBackground(image: "bg_chapter_01_blue_pines", blur: 8) {
            VStack(spacing: 0) {
                TopBar(title: "CHAPTERS", back: { router.pop() })
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(visibleChapters) { chapter in
                            card(chapter)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var visibleChapters: [ChapterDefinition] {
        ContentCatalog.chapters.filter { chapter in
            if chapter.id == 11 {
                return purchase.owned && save.data.completedChapterIDs.contains(6)
            }
            return chapter.id <= 10
        }
    }

    private func card(_ chapter: ChapterDefinition) -> some View {
        let unlocked = save.isUnlocked(chapter.id, ownsWhiteMoon: purchase.owned)
        let completed = save.data.completedChapterIDs.contains(chapter.id)
        let current = chapter.id == save.data.currentChapter && unlocked && !completed
        let result = save.data.result(for: chapter.id)
        return Button {
            if unlocked {
                router.push(.briefing(chapterID: chapter.id))
            } else {
                audio.playSFX("sfx_ui_locked")
                haptics.locked()
            }
        } label: {
            Color.clear
                .aspectRatio(1838.0 / 856.0, contentMode: .fit)
                .frame(maxWidth: 335)
                .overlay {
                    ArtImage(name: "ui_panel_dark")
                        .scaledToFit()
                }
                .overlay {
                    GeometryReader { geo in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(chapter.id == 11 ? "WHITE MOON — THE FROZEN VOICE" : chapter.title)
                                    .font(Theme.buttonLabel())
                                    .foregroundStyle(Theme.primaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text(chapter.objective)
                                    .font(Theme.caption())
                                    .foregroundStyle(Theme.secondaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                if completed, let result {
                                    Text(result.badge)
                                        .font(Theme.caption())
                                        .foregroundStyle(Theme.moonCyan)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                } else if current {
                                    Text("Current Night")
                                        .font(Theme.caption())
                                        .foregroundStyle(Theme.emberGold)
                                        .lineLimit(1)
                                } else if !unlocked {
                                    Text("Complete Chapter \(max(1, chapter.id - 1)) first")
                                        .font(Theme.caption())
                                        .foregroundStyle(Theme.secondaryText)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Text(String(format: "%02d", chapter.id))
                                .font(Theme.hudNumber())
                                .foregroundStyle(Theme.iceWhite)
                            if !unlocked {
                                ArtImage(name: "ui_icon_lock")
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(.leading, geo.size.width * 0.18)
                        .padding(.trailing, geo.size.width * 0.17)
                        .padding(.top, geo.size.height * 0.30)
                        .padding(.bottom, geo.size.height * 0.34)
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                .opacity(unlocked ? 1 : 0.45)
        }
        .buttonStyle(PressScaleStyle())
        .frame(minHeight: 44)
        .accessibilityLabel(accessibility(chapter, unlocked: unlocked, completed: completed, current: current, result: result))
    }

    private func accessibility(_ chapter: ChapterDefinition, unlocked: Bool, completed: Bool, current: Bool, result: ChapterResultData?) -> String {
        if !unlocked { return "\(chapter.title). Complete Chapter \(max(1, chapter.id - 1)) first" }
        if completed, let result { return "\(chapter.title). \(result.badge)" }
        if current { return "\(chapter.title). Current Night" }
        return chapter.title
    }
}
