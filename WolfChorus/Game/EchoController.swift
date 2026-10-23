import CoreGraphics
import Foundation

enum EchoShape {
    case arc
    case circle
    case irregular
}

struct EchoGeometry {
    var origin: CGPoint
    var direction: CGVector
    var range: CGFloat
    var halfAngle: CGFloat
    var fullCircle: Bool
    var emotionRadius: CGFloat
}

enum EchoController {
    static func geometry(for wolf: WolfDefinition, strength: HowlStrength, origin: CGPoint, direction: CGVector) -> EchoGeometry {
        var range = strength.range
        var half: CGFloat = 35
        var circle = false
        var emotion = range
        switch wolf.echo {
        case "courage":
            emotion = 220
        case "tracker":
            range *= 1.35
            half = 19
            emotion = range
        case "calming":
            range *= 0.70
            circle = true
            half = 180
            emotion = range
        case "curious":
            half = 55
            emotion = range
        case "frozen":
            emotion = range
        default:
            emotion = range
        }
        let length = hypot(direction.dx, direction.dy)
        let dir = length > 0.001 ? CGVector(dx: direction.dx / length, dy: direction.dy / length) : CGVector(dx: 0, dy: 1)
        return EchoGeometry(origin: origin, direction: dir, range: range, halfAngle: half, fullCircle: circle, emotionRadius: emotion)
    }

    static func contains(_ point: CGPoint, geometry: EchoGeometry, irregular: Bool) -> Bool {
        let dx = point.x - geometry.origin.x
        let dy = point.y - geometry.origin.y
        let dist = hypot(dx, dy)
        guard dist <= geometry.range, dist > 0.5 else { return dist <= geometry.range }
        if geometry.fullCircle { return true }
        let angle = atan2(dy, dx)
        let aim = atan2(geometry.direction.dy, geometry.direction.dx)
        var delta = angle - aim
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        let limit = geometry.halfAngle * .pi / 180
        if irregular {
            let wobble = sin(angle * 5) * (8 * .pi / 180)
            return abs(delta) <= limit + wobble
        }
        return abs(delta) <= limit
    }

    static func occluded(howlerID: String, type: EchoType, howler: CGPoint, point: CGPoint, obstacle: CGPoint?) -> Bool {
        guard let obstacle else { return false }
        if howlerID == "saira" && (type == .trail || type == .hazard || type == .threat) {
            return false
        }
        if type == .objective || type == .memory || type == .secret || type == .prey {
            return false
        }
        return segmentDistance(howler, point, obstacle) < 48
    }

    static func segmentDistance(_ a: CGPoint, _ b: CGPoint, _ p: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        if len2 < 0.01 { return distance(a, p) }
        var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2
        t = min(1, max(0, t))
        let x = a.x + t * dx
        let y = a.y + t * dy
        return hypot(p.x - x, p.y - y)
    }
}
