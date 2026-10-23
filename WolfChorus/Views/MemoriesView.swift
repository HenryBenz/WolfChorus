import SwiftUI

struct MemoriesView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var save: SaveService
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var haptics: HapticsService
    @State private var viewerID: Int?
    @State private var banner: String?

    var body: some View {
        MenuBackground(image: "bg_pack_den", dim: 0.65) {
            VStack(spacing: 0) {
                TopBar(title: "MEMORIES", back: { close() })
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(ContentCatalog.memories) { memory in
                                card(memory)
                                    .id(memory.id)
                            }
                        }
                        .padding(20)
                    }
                    .onAppear {
                        if let focus = router.focusMemoryID {
                            proxy.scrollTo(focus, anchor: .center)
                            if save.data.unlockedMemoryIDs.contains(focus) {
                                viewerID = focus
                            }
                        }
                    }
                }
            }
            if let banner {
                VStack {
                    Spacer()
                    Text(banner)
                        .font(Theme.caption())
                        .foregroundStyle(Theme.primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.8)))
                        .padding(.bottom, 24)
                }
                .transition(.opacity)
            }
        }
        .fullScreenCover(item: viewerBinding) { memory in
            MemoryViewer(memory: memory, unlocked: unlockedMemories, onClose: { viewerID = nil })
        }
    }

    private var unlockedMemories: [MemoryDefinition] {
        ContentCatalog.memories.filter { save.data.unlockedMemoryIDs.contains($0.id) }
    }

    private var viewerBinding: Binding<MemoryDefinition?> {
        Binding(
            get: { viewerID.flatMap(ContentCatalog.memory) },
            set: { viewerID = $0?.id }
        )
    }

    private func card(_ memory: MemoryDefinition) -> some View {
        let open = save.data.unlockedMemoryIDs.contains(memory.id)
        return Button {
            if open {
                viewerID = memory.id
            } else {
                audio.playSFX("sfx_ui_locked")
                haptics.locked()
                banner = requirement(memory)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if banner == requirement(memory) { banner = nil }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    ArtImage(name: memory.image)
                        .scaledToFill()
                        .frame(height: 180)
                        .clipped()
                        .saturation(open ? 1 : 0)
                        .opacity(open ? 1 : 0.8)
                    if !open {
                        ArtImage(name: "ui_icon_lock")
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(memory.title)
                    .font(Theme.caption())
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                if !open {
                    Text(requirement(memory))
                        .font(Theme.caption())
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(2)
                }
            }
        }
        .buttonStyle(PressScaleStyle())
        .frame(minHeight: 44)
        .accessibilityLabel(open ? memory.title : "\(memory.title). \(requirement(memory))")
    }

    private func requirement(_ memory: MemoryDefinition) -> String {
        let chapter = ContentCatalog.chapter(memory.chapterID)
        if memory.chapterID > 1 && !save.isUnlocked(memory.chapterID, ownsWhiteMoon: false) {
            return "Complete Chapter \(memory.chapterID - 1) first"
        }
        return chapter?.title ?? memory.title
    }

    private func close() {
        if router.returnHomeAfterMemory {
            router.returnHomeAfterMemory = false
            router.focusMemoryID = nil
            router.setStack([])
        } else {
            router.focusMemoryID = nil
            router.pop()
        }
    }
}

private struct MemoryViewer: View {
    let memory: MemoryDefinition
    let unlocked: [MemoryDefinition]
    let onClose: () -> Void
    @State private var current: MemoryDefinition

    init(memory: MemoryDefinition, unlocked: [MemoryDefinition], onClose: @escaping () -> Void) {
        self.memory = memory
        self.unlocked = unlocked
        self.onClose = onClose
        _current = State(initialValue: memory)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                ArtImage(name: current.image)
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(current.title)
                    .font(Theme.sectionTitle())
                    .foregroundStyle(Theme.primaryText)
                Text(current.text)
                    .font(Theme.body())
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                if let index = unlocked.firstIndex(of: current) {
                    Text("\(index + 1) / \(unlocked.count)")
                        .font(Theme.caption())
                        .foregroundStyle(Theme.secondaryText)
                }
                IconButton(icon: "ui_icon_close", label: "Close", sound: .close, action: onClose)
                    .padding(.bottom, 12)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                guard let index = unlocked.firstIndex(of: current) else { return }
                if value.translation.width < -40, index + 1 < unlocked.count {
                    current = unlocked[index + 1]
                } else if value.translation.width > 40, index > 0 {
                    current = unlocked[index - 1]
                }
            }
        )
    }
}
