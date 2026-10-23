import CoreGraphics
import Foundation

enum EchoType: String, Codable, Hashable {
    case trail
    case objective
    case prey
    case threat
    case hazard
    case memory
    case secret

    var spoken: String {
        switch self {
        case .trail: return "trail"
        case .objective: return "objective"
        case .prey: return "prey"
        case .threat: return "threat"
        case .hazard: return "hazard"
        case .memory: return "memory"
        case .secret: return "secret route"
        }
    }

    var tintHex: String {
        switch self {
        case .trail: return "74E7FF"
        case .objective: return "F5B83D"
        case .prey: return "F5B83D"
        case .threat: return "FF493D"
        case .hazard: return "A988FF"
        case .memory: return "EAF8FF"
        case .secret: return "7DDBB5"
        }
    }
}

struct EchoPoint: Identifiable, Hashable {
    var id: String
    var node: NodeID
    var type: EchoType
    var hazardKind: String
    var memoryID: Int?
    var revealed: Bool
    var remembered: Bool
    var consumed: Bool
    var revealRemaining: Double
    var offset: CGPoint
    var requiredLane: Bool

    var isVisible: Bool {
        if id.hasPrefix("exit") { return !consumed }
        return !consumed && (remembered || (revealed && revealRemaining > 0))
    }

    func snapshot() -> EchoPointSnapshot {
        EchoPointSnapshot(
            id: id,
            node: node.rawValue,
            type: type.rawValue,
            hazardKind: hazardKind,
            memoryID: memoryID,
            revealed: revealed,
            remembered: remembered,
            consumed: consumed,
            revealRemaining: revealRemaining,
            offsetX: offset.x,
            offsetY: offset.y
        )
    }

    static func from(_ snapshot: EchoPointSnapshot) -> EchoPoint? {
        guard let node = NodeID(rawValue: snapshot.node), let type = EchoType(rawValue: snapshot.type) else { return nil }
        return EchoPoint(
            id: snapshot.id,
            node: node,
            type: type,
            hazardKind: snapshot.hazardKind,
            memoryID: snapshot.memoryID,
            revealed: snapshot.revealed,
            remembered: snapshot.remembered,
            consumed: snapshot.consumed,
            revealRemaining: snapshot.revealRemaining,
            offset: CGPoint(x: snapshot.offsetX, y: snapshot.offsetY),
            requiredLane: snapshot.id.hasPrefix("required") || snapshot.id.hasPrefix("exit")
        )
    }
}

struct EchoBurst: Identifiable {
    var id = UUID()
    var origin: CGPoint
    var direction: CGVector
    var range: CGFloat
    var halfAngle: CGFloat
    var fullCircle: Bool
    var colorHex: String
    var age: Double = 0
}

struct AimRender {
    var active = false
    var origin: CGPoint = .zero
    var finger: CGPoint = .zero
    var charge: Double = 0
}
