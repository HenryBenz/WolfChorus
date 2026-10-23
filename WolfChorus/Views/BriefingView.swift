import SwiftUI

struct BriefingView: View {
    let chapterID: Int
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var save: SaveService
    @EnvironmentObject private var audio: AudioService

    var body: some View {
        GeometryReader { geo in
            let chapter = ContentCatalog.chapter(chapterID)
            ZStack(alignment: .bottom) {
                ArtImage(name: chapter?.background ?? "bg_chapter_01_blue_pines")
                    .scaledToFill()
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black.opacity(0.55), Color.black.opacity(0.94)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: geo.size.height * 0.46)
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(chapter?.title ?? "")
                                .font(Theme.screenTitle())
                                .tracking(1.2)
                                .foregroundStyle(Theme.primaryText)
                            Text(chapter?.story ?? "")
                                .font(Theme.body())
                                .foregroundStyle(Theme.primaryText)
                            Text("OBJECTIVE")
                                .font(Theme.caption())
                                .foregroundStyle(Theme.secondaryText)
                            Text(chapter?.objective ?? "")
                                .font(Theme.body())
                                .foregroundStyle(Theme.iceWhite)
                            HStack(spacing: 8) {
                                ForEach(chapter?.rosterIDs ?? [], id: \.self) { id in
                                    if let wolf = ContentCatalog.wolf(id) {
                                        ArtImage(name: wolf.portraitCalm)
                                            .scaledToFill()
                                            .frame(width: 46, height: 46)
                                            .clipShape(Circle())
                                            .overlay(
                                                ArtImage(name: "ui_portrait_frame")
                                                    .scaledToFit()
                                                    .frame(width: 46, height: 46)
                                            )
                                            .accessibilityLabel(wolf.name)
                                    }
                                }
                            }
                            ForEach(chapter?.hints ?? [], id: \.self) { hint in
                                Text(hint)
                                    .font(Theme.caption())
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                    }
                    ChorusButton(title: buttonTitle) { start(chapter) }
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, geo.safeAreaInsets.bottom + 12)
                .frame(height: geo.size.height * 0.46, alignment: .bottom)
            }
            .background(Theme.nightNavy)
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                TopBar(back: { router.pop() }, trailing: "\(chapterID)")
            }
        }
    }

    private var buttonTitle: String {
        if save.data.suspendedCampaign?.chapterID == chapterID { return "RESUME" }
        if save.data.completedChapterIDs.contains(chapterID) { return "REPLAY CHAPTER" }
        return "BEGIN CHAPTER"
    }

    private func start(_ chapter: ChapterDefinition?) {
        let resume = buttonTitle == "RESUME"
        router.openGame(
            mode: .campaign(chapterID: chapterID, resumeSuspended: resume),
            music: chapter?.music ?? "music_exploration",
            ambient: chapter?.ambient ?? "amb_blue_forest",
            audio: audio
        )
    }
}
