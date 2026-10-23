import Foundation

struct ChapterResultData: Codable, Hashable {
    var packStayedTogether: Bool
    var memoriesFound: Int
    var memoriesTotal: Int
    var forestAttention: String

    var badge: String {
        packStayedTogether ? "Pack Intact" : "Pack Scattered"
    }
}

struct GameResult: Codable, Hashable {
    var chapterID: Int
    var result: ChapterResultData
}

struct EndlessResult: Codable, Hashable {
    var distanceMeters: Int
    var encountersSurvived: Int
    var memoriesCollected: Int
    var bestMeters: Int
    var isNewBest: Bool
    var difficulty: String
    var wolfIDs: [String]
}

struct WolfSnapshot: Codable, Hashable {
    var id: String
    var trust: Double
    var anxiety: Double
    var node: String
    var normX: Double
    var normY: Double
}

struct EchoPointSnapshot: Codable, Hashable {
    var id: String
    var node: String
    var type: String
    var hazardKind: String
    var memoryID: Int?
    var revealed: Bool
    var remembered: Bool
    var consumed: Bool
    var revealRemaining: Double
    var offsetX: Double
    var offsetY: Double
}

struct EncounterBaseline: Codable, Hashable {
    var wolves: [WolfSnapshot]
    var attention: Double
    var countdownRemaining: Double?
    var strongHowlCount: Int
    var collectedMemoryIDs: [Int]
    var chapterMemoryFinds: [Int]
    var tutorialDone: Bool
}

struct SuspendedCampaignData: Codable, Hashable {
    var chapterID: Int
    var encounterIndex: Int
    var wolves: [WolfSnapshot]
    var attention: Double
    var collectedMemoryIDs: [Int]
    var countdownRemaining: Double?
    var strongHowlCount: Int
    var points: [EchoPointSnapshot]
    var requiredDone: Bool
    var exitSpawned: Bool
    var noTargetTime: Double
    var anxietyPulseTime: Double
    var iceArm: Double?
    var iceFrozen: Double
    var decoyRemaining: Double
    var decoyNormX: Double
    var decoyNormY: Double
    var panickedTogether: Double
    var tutorialDone: Bool
    var chapterMemoryFinds: [Int]
    var baseline: EncounterBaseline
    var backgroundPan: Int
}

struct SaveData: Codable, Hashable {
    var schemaVersion: Int
    var hasSeenWelcome: Bool
    var campaignStarted: Bool
    var currentChapter: Int
    var highestUnlockedChapter: Int
    var completedChapterIDs: [Int]
    var chapterResults: [String: ChapterResultData]
    var unlockedMemoryIDs: [Int]
    var unlockedWolfIDs: [String]
    var suspendedCampaign: SuspendedCampaignData?
    var endlessBestMeters: [String: Int]
    var lastEndlessDifficulty: String
    var lastEndlessPack: [String]
    var whiteMoonOwnedCache: Bool
    var whiteMoonThemeEnabled: Bool

    static func fresh() -> SaveData {
        SaveData(
            schemaVersion: 1,
            hasSeenWelcome: false,
            campaignStarted: false,
            currentChapter: 1,
            highestUnlockedChapter: 1,
            completedChapterIDs: [],
            chapterResults: [:],
            unlockedMemoryIDs: [],
            unlockedWolfIDs: ["arkan", "nora"],
            suspendedCampaign: nil,
            endlessBestMeters: [:],
            lastEndlessDifficulty: "wild",
            lastEndlessPack: ["arkan", "nora", "saira"],
            whiteMoonOwnedCache: false,
            whiteMoonThemeEnabled: false
        )
    }

    func result(for chapterID: Int) -> ChapterResultData? {
        chapterResults[String(chapterID)]
    }

    var hasCampaignProgress: Bool {
        campaignStarted || suspendedCampaign != nil || !completedChapterIDs.isEmpty || !chapterResults.isEmpty
    }
}

enum AttentionBand {
    static func name(for attention: Double) -> String {
        if attention < 40 { return "Quiet" }
        if attention < 70 { return "Stirred" }
        return "Alerted"
    }

    static func pips(for attention: Double) -> Int {
        if attention < 20 { return 1 }
        if attention < 40 { return 2 }
        if attention < 60 { return 3 }
        if attention < 80 { return 4 }
        return 5
    }
}
