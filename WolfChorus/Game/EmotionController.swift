import Foundation

enum EmotionController {
    static func state(trust: Double, anxiety: Double) -> WolfState {
        if trust >= 50 && anxiety < 60 { return .steady }
        if trust >= 50 && anxiety >= 60 { return .guarded }
        if trust < 50 && anxiety < 60 { return .independent }
        return .panicked
    }

    static func applyHazard(anxiety: inout Double, shield: inout Double, amount: Double) {
        let incoming = max(0, amount)
        let blocked = min(shield, incoming)
        shield -= blocked
        anxiety = min(100, anxiety + (incoming - blocked))
    }
}
