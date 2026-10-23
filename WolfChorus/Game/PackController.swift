import CoreGraphics
import Foundation

enum NodeID: String, CaseIterable, Codable, Hashable {
    case P0, P1, P2, P3, P4, P5, P6, P7

    var normalized: CGPoint {
        switch self {
        case .P0: return CGPoint(x: 0.50, y: 0.86)
        case .P1: return CGPoint(x: 0.20, y: 0.69)
        case .P2: return CGPoint(x: 0.50, y: 0.64)
        case .P3: return CGPoint(x: 0.80, y: 0.69)
        case .P4: return CGPoint(x: 0.18, y: 0.43)
        case .P5: return CGPoint(x: 0.50, y: 0.36)
        case .P6: return CGPoint(x: 0.82, y: 0.43)
        case .P7: return CGPoint(x: 0.50, y: 0.16)
        }
    }

    static let links: [NodeID: [NodeID]] = [
        .P0: [.P1, .P2, .P3],
        .P1: [.P0, .P4, .P5],
        .P2: [.P0, .P4, .P5, .P6],
        .P3: [.P0, .P5, .P6],
        .P4: [.P1, .P2, .P7],
        .P5: [.P1, .P2, .P3, .P7],
        .P6: [.P2, .P3, .P7],
        .P7: [.P4, .P5, .P6]
    ]

    func scenePoint(in playable: CGRect) -> CGPoint {
        CGPoint(
            x: playable.minX + normalized.x * playable.width,
            y: playable.maxY - normalized.y * playable.height
        )
    }

    static func nearest(to point: CGPoint, in playable: CGRect) -> NodeID {
        allCases.min { lhs, rhs in
            distance(point, lhs.scenePoint(in: playable)) < distance(point, rhs.scenePoint(in: playable))
        } ?? .P0
    }

    static func shortestPath(from start: NodeID, to end: NodeID) -> [NodeID] {
        if start == end { return [] }
        var queue: [NodeID] = [start]
        var previous: [NodeID: NodeID] = [:]
        var seen: Set<NodeID> = [start]
        var index = 0
        while index < queue.count {
            let node = queue[index]
            index += 1
            for next in links[node] ?? [] where !seen.contains(next) {
                seen.insert(next)
                previous[next] = node
                if next == end {
                    var chain: [NodeID] = [end]
                    var cursor = end
                    while let prior = previous[cursor], prior != start {
                        chain.append(prior)
                        cursor = prior
                    }
                    return chain.reversed()
                }
                queue.append(next)
            }
        }
        return []
    }
}

struct PackWolf: Identifiable {
    var id: String
    var trust: Double
    var anxiety: Double
    var state: WolfState
    var node: NodeID
    var position: CGPoint
    var path: [NodeID]
    var cooldown: Double
    var panicLeft: Double
    var separated: Double
    var shield: Double
    var howlLeft: Double
    var recallCooldown: Double
    var fleeing: Bool
    var destinationPointID: String?
    var formX: CGFloat

    mutating func clamp() {
        trust = min(100, max(0, trust))
        anxiety = min(100, max(0, anxiety))
        state = EmotionController.state(trust: trust, anxiety: anxiety)
    }

    func snapshot(playable: CGRect) -> WolfSnapshot {
        let normX = playable.width > 0 ? (position.x - playable.minX) / playable.width : node.normalized.x
        let normY = playable.height > 0 ? (playable.maxY - position.y) / playable.height : node.normalized.y
        return WolfSnapshot(id: id, trust: trust, anxiety: anxiety, node: node.rawValue, normX: normX, normY: normY)
    }
}

enum PackController {
    static func makeWolf(id: String, trust: Double, anxiety: Double, node: NodeID, playable: CGRect) -> PackWolf {
        var wolf = PackWolf(
            id: id,
            trust: trust,
            anxiety: anxiety,
            state: .steady,
            node: node,
            position: node.scenePoint(in: playable),
            path: [],
            cooldown: 0,
            panicLeft: 0,
            separated: 0,
            shield: 0,
            howlLeft: 0,
            recallCooldown: 0,
            fleeing: false,
            destinationPointID: nil,
            formX: 0
        )
        wolf.clamp()
        return wolf
    }

    static func assign(wolf: inout PackWolf, to target: NodeID, playable: CGRect, alternate: NodeID?) {
        let destination = alternate ?? target
        let from = NodeID.nearest(to: wolf.position, in: playable)
        wolf.node = from
        wolf.path = NodeID.shortestPath(from: from, to: destination)
    }

    static func tick(wolf: inout PackWolf, dt: Double, playable: CGRect, speed: CGFloat, leaderPosition: CGPoint, threatPosition: CGPoint?) {
        wolf.cooldown = max(0, wolf.cooldown - dt)
        wolf.recallCooldown = max(0, wolf.recallCooldown - dt)
        wolf.howlLeft = max(0, wolf.howlLeft - dt)

        if wolf.state == .panicked {
            if !wolf.fleeing {
                wolf.fleeing = true
                wolf.panicLeft = 4
                wolf.path = fleePath(from: wolf, threat: threatPosition, playable: playable)
            }
            wolf.panicLeft -= dt
            if wolf.panicLeft <= 0 {
                wolf.path = []
                wolf.fleeing = false
            }
        } else {
            wolf.fleeing = false
            wolf.panicLeft = 0
        }

        guard let next = wolf.path.first else { return }
        let nodePoint = next.scenePoint(in: playable)
        let target = CGPoint(x: nodePoint.x + wolf.formX, y: nodePoint.y)
        let dx = target.x - wolf.position.x
        let dy = target.y - wolf.position.y
        let dist = hypot(dx, dy)
        let step = speed * CGFloat(dt)
        if dist <= max(6, step) {
            wolf.position = target
            wolf.node = next
            wolf.path.removeFirst()
        } else if dist > 0 {
            wolf.position.x += dx / dist * step
            wolf.position.y += dy / dist * step
        }
        _ = leaderPosition
    }

    private static func fleePath(from wolf: PackWolf, threat: CGPoint?, playable: CGRect) -> [NodeID] {
        let neighbors = NodeID.links[wolf.node] ?? []
        guard !neighbors.isEmpty else { return [] }
        let origin = wolf.position
        let chosen = neighbors.max { lhs, rhs in
            let left = lhs.scenePoint(in: playable)
            let right = rhs.scenePoint(in: playable)
            let leftScore = threat.map { distance(left, $0) } ?? distance(left, origin)
            let rightScore = threat.map { distance(right, $0) } ?? distance(right, origin)
            return leftScore < rightScore
        }
        return chosen.map { [$0] } ?? []
    }
}

func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    hypot(a.x - b.x, a.y - b.y)
}
