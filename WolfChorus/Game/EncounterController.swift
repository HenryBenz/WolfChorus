import Foundation

enum EncounterController {
    static func build(definition: EncounterDefinition, encounterNumber: Int, chapter: ChapterDefinition) -> [EchoPoint] {
        var points: [EchoPoint] = []
        let memoryOnSafe = definition.memoryID != nil
        points.append(EchoPoint(
            id: "required-\(encounterNumber)",
            node: NodeID(rawValue: definition.required) ?? .P5,
            type: .objective,
            hazardKind: definition.hazardKind,
            memoryID: nil,
            revealed: false,
            remembered: false,
            consumed: false,
            revealRemaining: 0,
            offset: .zero,
            requiredLane: true
        ))
        points.append(EchoPoint(
            id: memoryOnSafe ? "memory-\(encounterNumber)" : "safe-\(encounterNumber)",
            node: NodeID(rawValue: definition.safe) ?? .P6,
            type: memoryOnSafe ? .memory : .trail,
            hazardKind: definition.hazardKind,
            memoryID: definition.memoryID,
            revealed: false,
            remembered: false,
            consumed: false,
            revealRemaining: 0,
            offset: .zero,
            requiredLane: false
        ))
        points.append(EchoPoint(
            id: "hazard-\(encounterNumber)",
            node: NodeID(rawValue: definition.hazard) ?? .P4,
            type: hazardType(kind: definition.hazardKind),
            hazardKind: definition.hazardKind,
            memoryID: nil,
            revealed: false,
            remembered: false,
            consumed: false,
            revealRemaining: 0,
            offset: .zero,
            requiredLane: false
        ))
        _ = chapter
        return points
    }

    static func exitPoint(encounterNumber: Int) -> EchoPoint {
        EchoPoint(
            id: "exit-\(encounterNumber)",
            node: .P7,
            type: .objective,
            hazardKind: "",
            memoryID: nil,
            revealed: true,
            remembered: false,
            consumed: false,
            revealRemaining: 0,
            offset: .zero,
            requiredLane: true
        )
    }

    static func hazardType(kind: String) -> EchoType {
        switch kind {
        case "rival", "bear", "threat", "lantern":
            return .threat
        case "deer":
            return .prey
        case "fire", "ice", "ravens", "trunk":
            return .hazard
        default:
            return .hazard
        }
    }

    static func spriteName(kind: String) -> String? {
        switch kind {
        case "ravens": return "obj_ravens"
        case "trunk": return "obj_fallen_trunk"
        case "deer": return "obj_deer"
        case "rival": return "obj_rival_wolf"
        case "fire": return "obj_fire_wall"
        case "ice": return "obj_cracked_ice"
        case "bear": return "obj_bear"
        case "lantern": return "obj_hunter_lantern"
        default: return nil
        }
    }
}
