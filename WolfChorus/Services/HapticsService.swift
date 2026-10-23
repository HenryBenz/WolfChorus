import UIKit

final class HapticsService: ObservableObject {
    var enabled = true
    private var lastLocked = Date.distantPast

    func buttonTap() { impact(.light) }
    func wolfSelect() { impact(.soft) }
    func mediumHowl() { impact(.medium) }
    func strongHowl() {
        impact(.rigid)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.impact(.soft)
        }
    }
    func memoryFound() { note(.success) }
    func chapterFailure() { note(.warning) }
    func purchaseSuccess() { note(.success) }

    func locked() {
        let now = Date()
        guard now.timeIntervalSince(lastLocked) >= 0.5 else { return }
        lastLocked = now
        impact(.soft)
    }

    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard enabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    private func note(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard enabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
