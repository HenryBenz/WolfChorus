import Foundation

struct WolfDefinition: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var role: String
    var howlName: String
    var biography: String
    var trust: Double
    var instinct: Double
    var speed: Double
    var colorHex: String
    var echo: String
    var facesLeft: Bool

    var portraitCalm: String { "wolf_\(id)_portrait_calm" }
    var portraitStressed: String { "wolf_\(id)_portrait_stressed" }
    var bodyIdle: String { "wolf_\(id)_body_idle" }
    var bodyHowl: String { "wolf_\(id)_body_howl" }
    var vocalSoft: String { "wolf_\(id)_soft" }
    var vocalMedium: String { "wolf_\(id)_medium" }
    var vocalStrong: String { "wolf_\(id)_strong" }

    var howlLabel: String { howlName.uppercased() }

    func vocal(for strength: HowlStrength) -> (name: String, duration: Double) {
        switch strength {
        case .soft: return (vocalSoft, 1.5)
        case .medium: return (vocalMedium, 2.6)
        case .strong: return (vocalStrong, 4.0)
        }
    }

    func unlockInstruction(save: SaveData) -> String {
        switch id {
        case "saira":
            return "Complete Chapter 1 first"
        case "rune":
            return "Complete Chapter 2 first"
        case "mor":
            if save.highestUnlockedChapter < 7 && !save.completedChapterIDs.contains(7) {
                return "Complete Chapter 6 first"
            }
            return "Find Mor and escape the bear."
        case "lumi":
            return "A permanent expansion for Wolf Chorus"
        default:
            return ""
        }
    }
}

enum HowlStrength: String, Codable {
    case soft, medium, strong

    var range: CGFloat {
        switch self {
        case .soft: return 260
        case .medium: return 420
        case .strong: return 620
        }
    }

    var attentionCost: Double {
        switch self {
        case .soft: return 6
        case .medium: return 12
        case .strong: return 22
        }
    }

    var emotion: Double {
        switch self {
        case .soft: return 8
        case .medium: return 14
        case .strong: return 22
        }
    }

    var echoSound: String {
        switch self {
        case .soft: return "sfx_echo_release_soft"
        case .medium: return "sfx_echo_release_medium"
        case .strong: return "sfx_echo_release_strong"
        }
    }

    static func from(charge: Double) -> HowlStrength? {
        if charge < 0.25 { return nil }
        if charge < 0.70 { return .soft }
        if charge < 1.10 { return .medium }
        return .strong
    }
}

enum WolfState: String, Codable {
    case steady, guarded, independent, panicked

    var spoken: String {
        switch self {
        case .steady: return "Steady"
        case .guarded: return "Guarded"
        case .independent: return "Independent"
        case .panicked: return "Panicked"
        }
    }
}
