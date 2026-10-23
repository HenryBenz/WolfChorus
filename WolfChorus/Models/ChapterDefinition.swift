import Foundation

struct EncounterDefinition: Codable, Hashable {
    var required: String
    var safe: String
    var hazard: String
    var hazardKind: String
    var memoryID: Int?
}

struct ChapterDefinition: Codable, Identifiable, Hashable {
    var id: Int
    var title: String
    var story: String
    var objective: String
    var background: String
    var music: String
    var ambient: String
    var wolves: [String]
    var leaderID: String
    var joiningWolfID: String?
    var joiningEncounter: Int?
    var startingTrust: Double
    var startingAnxiety: Double
    var special: String
    var countdownSeconds: Double?
    var trailRevealSeconds: Double
    var attentionLimit: Double?
    var strongHowlLimit: Int?
    var hints: [String]
    var encounters: [EncounterDefinition]

    func activeWolfIDs(encounterNumber: Int) -> [String] {
        var ids = wolves
        if let joiningWolfID, let joiningEncounter, encounterNumber >= joiningEncounter, !ids.contains(joiningWolfID) {
            ids.append(joiningWolfID)
        }
        return ids
    }

    var rosterIDs: [String] {
        var ids = wolves
        if let joiningWolfID, !ids.contains(joiningWolfID) {
            ids.append(joiningWolfID)
        }
        return ids
    }
}

struct MemoryDefinition: Identifiable, Hashable {
    var id: Int
    var title: String
    var text: String
    var image: String
    var chapterID: Int
}

enum ContentCatalog {
    static let chapters: [ChapterDefinition] = load("chapters", as: ChapterFile.self).chapters
    static let wolves: [WolfDefinition] = load("wolves", as: WolfFile.self).wolves

    static let memories: [MemoryDefinition] = [
        MemoryDefinition(id: 1, title: "First Call", text: "Before the night divided them, one voice was enough to bring every wolf home.", image: "memory_01_first_call", chapterID: 1),
        MemoryDefinition(id: 2, title: "Rain Scent", text: "Rain erases tracks, but never the memory of those who walked beside us.", image: "memory_02_rain_scent", chapterID: 2),
        MemoryDefinition(id: 3, title: "The Hunt", text: "Hunger taught the pack to move as one creature with many hearts.", image: "memory_03_the_hunt", chapterID: 3),
        MemoryDefinition(id: 4, title: "Foreign Howl", text: "A rival voice can be a warning, a challenge, or a plea. Distance hides the difference.", image: "memory_04_foreign_howl", chapterID: 4),
        MemoryDefinition(id: 5, title: "Through Fire", text: "They escaped the flames because fear moved through them—and trust moved faster.", image: "memory_05_through_fire", chapterID: 5),
        MemoryDefinition(id: 6, title: "The Exile", text: "Mor expected teeth. Nora answered him with silence and space beside the fire.", image: "memory_06_the_exile", chapterID: 7),
        MemoryDefinition(id: 7, title: "Broken Circle", text: "A pack is not held together by obedience. It survives because each wolf chooses to return.", image: "memory_07_broken_circle", chapterID: 8),
        MemoryDefinition(id: 8, title: "Under the Red Moon", text: "At dawn, no voice belonged to one wolf alone. The forest remembered the whole pack.", image: "memory_08_final_pack", chapterID: 10)
    ]

    static func chapter(_ id: Int) -> ChapterDefinition? {
        chapters.first { $0.id == id }
    }

    static func wolf(_ id: String) -> WolfDefinition? {
        wolves.first { $0.id == id }
    }

    static func memory(_ id: Int) -> MemoryDefinition? {
        memories.first { $0.id == id }
    }

    static var endlessTemplates: [(chapterID: Int, encounter: EncounterDefinition)] {
        chapters.filter { $0.id <= 10 }.flatMap { chapter in
            chapter.encounters.map { (chapter.id, $0) }
        }
    }

    private struct ChapterFile: Codable { var chapters: [ChapterDefinition] }
    private struct WolfFile: Codable { var wolves: [WolfDefinition] }

    private static func load<T: Decodable>(_ name: String, as type: T.Type) -> T {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            fatalError("Missing \(name).json")
        }
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        } catch {
            fatalError("Invalid \(name).json: \(error)")
        }
    }
}
