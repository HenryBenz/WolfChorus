import SwiftUI

enum AppRoute: Hashable {
    case home
    case chapterSelect
    case briefing(chapterID: Int)
    case game(mode: GameMode)
    case result(GameResult)
    case pack
    case memories
    case endlessSetup
    case endlessResult(EndlessResult)
    case settings
    case whiteMoon
}

enum AppModal: String, Identifiable {
    case settings
    var id: String { rawValue }
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var routes: [AppRoute] = []
    @Published var modal: AppModal?
    @Published var black: Double = 0
    @Published var focusMemoryID: Int?
    @Published var returnHomeAfterMemory = false
    @Published var banner: String?
    private var lastNavigation = Date.distantPast
    private var transitioning = false

    func push(_ route: AppRoute) {
        let now = Date()
        guard now.timeIntervalSince(lastNavigation) >= 0.5 else { return }
        guard routes.last != route else { return }
        lastNavigation = now
        routes.append(route)
    }

    func pop() {
        let now = Date()
        guard now.timeIntervalSince(lastNavigation) >= 0.5 else { return }
        guard !routes.isEmpty else { return }
        lastNavigation = now
        routes.removeLast()
    }

    func setStack(_ routes: [AppRoute]) {
        lastNavigation = Date()
        self.routes = routes
    }

    func closeSettings() {
        if modal != nil {
            modal = nil
        } else {
            pop()
        }
    }

    func openGame(mode: GameMode, music: String, ambient: String, audio: AudioService) {
        guard !transitioning else { return }
        transitioning = true
        Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.6)) { black = 1 }
            try? await Task.sleep(nanoseconds: 600_000_000)
            audio.playMusic(music, loop: true)
            audio.playAmbient(ambient)
            routes.append(.game(mode: mode))
            withAnimation(.easeInOut(duration: 0.6)) { black = 0 }
            lastNavigation = Date()
            transitioning = false
        }
    }
}
