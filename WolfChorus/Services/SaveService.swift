import Foundation
import Combine

final class Preferences: ObservableObject {
    @Published var music: Double { didSet { defaults.set(music, forKey: Keys.music) } }
    @Published var sfx: Double { didSet { defaults.set(sfx, forKey: Keys.sfx) } }
    @Published var ambient: Double { didSet { defaults.set(ambient, forKey: Keys.ambient) } }
    @Published var haptics: Bool { didSet { defaults.set(haptics, forKey: Keys.haptics) } }
    @Published var reduceMotion: Bool { didSet { defaults.set(reduceMotion, forKey: Keys.reduceMotion) } }
    @Published var highContrast: Bool { didSet { defaults.set(highContrast, forKey: Keys.highContrast) } }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let music = "wc_music"
        static let sfx = "wc_sfx"
        static let ambient = "wc_ambient"
        static let haptics = "wc_haptics"
        static let reduceMotion = "wc_reduce_motion"
        static let highContrast = "wc_high_contrast"
    }

    init() {
        defaults.register(defaults: [
            Keys.music: 0.75,
            Keys.sfx: 0.85,
            Keys.ambient: 0.70,
            Keys.haptics: true,
            Keys.reduceMotion: false,
            Keys.highContrast: false
        ])
        music = defaults.object(forKey: Keys.music) as? Double ?? 0.75
        sfx = defaults.object(forKey: Keys.sfx) as? Double ?? 0.85
        ambient = defaults.object(forKey: Keys.ambient) as? Double ?? 0.70
        haptics = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        reduceMotion = defaults.object(forKey: Keys.reduceMotion) as? Bool ?? false
        highContrast = defaults.object(forKey: Keys.highContrast) as? Bool ?? false
    }
}

final class SaveService: ObservableObject {
    @Published private(set) var data: SaveData
    private var needsRetry = false
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    init() {
        data = .fresh()
    }

    func load() {
        let url = Self.fileURL
        let folder = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard FileManager.default.fileExists(atPath: url.path) else {
            data = .fresh()
            write()
            return
        }
        do {
            let raw = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(SaveData.self, from: raw)
            guard decoded.schemaVersion == 1 else {
                throw CocoaError(.coderReadCorrupt)
            }
            data = decoded
            let before = data.unlockedWolfIDs
            grantCampaignWolves()
            if data.unlockedWolfIDs != before { write() }
        } catch {
            preserveCorrupt(url)
            data = .fresh()
            write()
        }
    }

    func markWelcomeSeen() {
        data.hasSeenWelcome = true
        write()
    }

    func newJourney() {
        let memories = data.unlockedMemoryIDs
        let owned = data.whiteMoonOwnedCache
        let theme = data.whiteMoonThemeEnabled
        let endlessBest = data.endlessBestMeters
        let difficulty = data.lastEndlessDifficulty
        let pack = data.lastEndlessPack
        let welcomed = data.hasSeenWelcome
        data = .fresh()
        data.hasSeenWelcome = welcomed
        data.unlockedMemoryIDs = memories
        data.whiteMoonOwnedCache = owned
        data.whiteMoonThemeEnabled = theme
        data.endlessBestMeters = endlessBest
        data.lastEndlessDifficulty = difficulty
        data.lastEndlessPack = pack
        if owned && !data.unlockedWolfIDs.contains("lumi") {
            data.unlockedWolfIDs.append("lumi")
        }
        write()
    }

    func resetCampaign() {
        let owned = data.whiteMoonOwnedCache
        let theme = data.whiteMoonThemeEnabled
        let welcomed = data.hasSeenWelcome
        let endlessBest = data.endlessBestMeters
        let difficulty = data.lastEndlessDifficulty
        let pack = data.lastEndlessPack
        data = .fresh()
        data.hasSeenWelcome = welcomed
        data.whiteMoonOwnedCache = owned
        data.whiteMoonThemeEnabled = theme
        data.endlessBestMeters = endlessBest
        data.lastEndlessDifficulty = difficulty
        data.lastEndlessPack = pack
        if owned && !data.unlockedWolfIDs.contains("lumi") {
            data.unlockedWolfIDs.append("lumi")
        }
        write()
    }

    func setOwned(_ owned: Bool, enableThemeIfNew: Bool) {
        let wasOwned = data.whiteMoonOwnedCache
        data.whiteMoonOwnedCache = owned
        if owned && !data.unlockedWolfIDs.contains("lumi") {
            data.unlockedWolfIDs.append("lumi")
        }
        if owned && enableThemeIfNew && !wasOwned {
            data.whiteMoonThemeEnabled = true
        }
        if !owned {
            data.unlockedWolfIDs.removeAll { $0 == "lumi" }
        }
        write()
    }

    func setThemeEnabled(_ enabled: Bool) {
        data.whiteMoonThemeEnabled = enabled
        write()
    }

    func unlockMemory(_ id: Int) {
        guard !data.unlockedMemoryIDs.contains(id) else { return }
        data.unlockedMemoryIDs.append(id)
        data.unlockedMemoryIDs.sort()
        write()
    }

    func unlockWolf(_ id: String) {
        guard !data.unlockedWolfIDs.contains(id) else { return }
        data.unlockedWolfIDs.append(id)
        write()
    }

    func noteChapterStarted(_ id: Int) {
        data.campaignStarted = true
        if id <= 10 {
            data.currentChapter = id
        }
        write()
    }

    func completeChapter(_ id: Int, result: ChapterResultData) {
        let key = String(id)
        if let old = data.chapterResults[key] {
            var merged = result
            if old.packStayedTogether { merged.packStayedTogether = true }
            merged.memoriesFound = max(old.memoriesFound, result.memoriesFound)
            merged.memoriesTotal = max(old.memoriesTotal, result.memoriesTotal)
            data.chapterResults[key] = merged
        } else {
            data.chapterResults[key] = result
        }
        if !data.completedChapterIDs.contains(id) {
            data.completedChapterIDs.append(id)
            data.completedChapterIDs.sort()
        }
        if id < 10 {
            data.highestUnlockedChapter = max(data.highestUnlockedChapter, id + 1)
            data.currentChapter = id + 1
        } else if id == 10 {
            data.highestUnlockedChapter = max(data.highestUnlockedChapter, 10)
            data.currentChapter = 10
        }
        data.campaignStarted = true
        if data.suspendedCampaign?.chapterID == id {
            data.suspendedCampaign = nil
        }
        grantCampaignWolves()
        write()
    }

    private func grantCampaignWolves() {
        func grant(_ id: String) {
            guard !data.unlockedWolfIDs.contains(id) else { return }
            data.unlockedWolfIDs.append(id)
        }
        grant("arkan")
        grant("nora")
        if data.completedChapterIDs.contains(1) { grant("saira") }
        if data.completedChapterIDs.contains(2) { grant("rune") }
        if data.completedChapterIDs.contains(7) { grant("mor") }
    }

    func writeSuspended(_ snapshot: SuspendedCampaignData?) {
        data.suspendedCampaign = snapshot
        if let snapshot, snapshot.chapterID <= 10 {
            data.currentChapter = snapshot.chapterID
            data.campaignStarted = true
        }
        write()
    }

    func rememberEndless(difficulty: String, pack: [String]) {
        data.lastEndlessDifficulty = difficulty
        data.lastEndlessPack = pack
        write()
    }

    @discardableResult
    func recordEndless(difficulty: String, distance: Int) -> Bool {
        let previous = data.endlessBestMeters[difficulty] ?? -1
        let isNew = distance > previous && distance > 0
        if distance > previous {
            data.endlessBestMeters[difficulty] = distance
        }
        write()
        return isNew
    }

    func retryIfNeeded() {
        if needsRetry { write() }
    }

    func continueChapterID(ownsWhiteMoon: Bool) -> Int {
        var id = data.currentChapter
        if id == 11 || !isPlayable(id, ownsWhiteMoon: ownsWhiteMoon) {
            id = min(max(1, data.highestUnlockedChapter), 10)
        }
        if !isPlayable(id, ownsWhiteMoon: ownsWhiteMoon) {
            id = 1
        }
        return id
    }

    func isPlayable(_ id: Int, ownsWhiteMoon: Bool) -> Bool {
        if id == 1 { return true }
        if id == 11 { return ownsWhiteMoon && data.completedChapterIDs.contains(6) }
        return id <= max(1, data.highestUnlockedChapter) && id <= 10
    }

    func isUnlocked(_ id: Int, ownsWhiteMoon: Bool) -> Bool {
        isPlayable(id, ownsWhiteMoon: ownsWhiteMoon)
    }

    private func write() {
        do {
            let url = Self.fileURL
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let raw = try encoder.encode(data)
            try raw.write(to: url, options: .atomic)
            needsRetry = false
        } catch {
            needsRetry = true
        }
    }

    private func preserveCorrupt(_ url: URL) {
        let stamp = Int(Date().timeIntervalSince1970)
        let dest = url.deletingLastPathComponent().appendingPathComponent("save_corrupt_\(stamp).json")
        try? FileManager.default.copyItem(at: url, to: dest)
    }

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("wolf_chorus_save_v1.json")
    }
}
