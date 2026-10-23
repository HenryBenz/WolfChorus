import SwiftUI

struct PressScaleStyle: ButtonStyle {
    var glow: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .shadow(color: glow && configuration.isPressed ? Theme.moonCyan.opacity(0.85) : .clear, radius: configuration.isPressed ? 12 : 0)
            .animation(.easeOut(duration: configuration.isPressed ? 0.08 : 0.12), value: configuration.isPressed)
    }
}

struct ChorusButton: View {
    enum Kind {
        case primary, secondary, danger

        var image: String {
            switch self {
            case .primary: return "ui_button_primary"
            case .secondary: return "ui_button_secondary"
            case .danger: return "ui_button_danger"
            }
        }

        var aspect: CGFloat {
            switch self {
            case .primary: return 2171.0 / 724.0
            case .secondary: return 2173.0 / 724.0
            case .danger: return 2171.0 / 724.0
            }
        }
    }

    let title: String
    var kind: Kind = .primary
    var enabled: Bool = true
    var playsTap: Bool = true
    let action: () -> Void

    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var haptics: HapticsService

    var body: some View {
        Button(action: press) {
            ZStack {
                ArtImage(name: kind.image)
                    .scaledToFit()
                Text(title)
                    .font(Theme.buttonLabel())
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 36)
            }
            .aspectRatio(kind.aspect, contentMode: .fit)
            .frame(maxWidth: 340)
        }
        .buttonStyle(PressScaleStyle(glow: kind == .primary && enabled))
        .opacity(enabled ? 1 : 0.45)
        .disabled(!enabled)
        .accessibilityLabel(title)
        .frame(minWidth: 44, minHeight: 44)
    }

    private func press() {
        guard enabled else { return }
        if playsTap {
            audio.playSFX("sfx_ui_tap")
            haptics.buttonTap()
        }
        action()
    }
}

struct IconButton: View {
    enum Sound {
        case tap, back, close, open
    }

    let icon: String
    let label: String
    var sound: Sound = .tap
    let action: () -> Void

    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var haptics: HapticsService

    var body: some View {
        Button(action: press) {
            ArtImage(name: icon)
                .scaledToFit()
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(label)
        .frame(minWidth: 44, minHeight: 44)
    }

    private func press() {
        switch sound {
        case .tap: audio.playSFX("sfx_ui_tap")
        case .back: audio.playSFX("sfx_ui_back")
        case .close: audio.playSFX("sfx_ui_modal_close")
        case .open: audio.playSFX("sfx_ui_modal_open")
        }
        haptics.buttonTap()
        action()
    }
}

struct TopBar: View {
    var title: String? = nil
    var back: (() -> Void)? = nil
    var close: (() -> Void)? = nil
    var trailing: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 56)
            ZStack {
                if let title {
                    Text(title)
                        .font(Theme.screenTitle())
                        .tracking(1.2)
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .accessibilityAddTraits(.isHeader)
                }
                HStack {
                    if let back {
                        IconButton(icon: "ui_icon_back", label: "Back", sound: .back, action: back)
                    } else {
                        Color.clear.frame(width: 48, height: 48)
                    }
                    Spacer()
                    if let close {
                        IconButton(icon: "ui_icon_close", label: "Close", sound: .close, action: close)
                    } else if let trailing {
                        Text(trailing)
                            .font(Theme.hudNumber())
                            .foregroundStyle(Theme.iceWhite)
                            .frame(minWidth: 48, minHeight: 48)
                    } else {
                        Color.clear.frame(width: 48, height: 48)
                    }
                }
            }
            .frame(height: 48)
            .padding(.horizontal, 16)
        }
    }
}

struct MenuBackground<Content: View>: View {
    let image: String
    var dim: Double = 0.32
    var dimColor: Color = .black
    var blur: CGFloat = 0
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            ArtImage(name: image)
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .blur(radius: blur)
                .clipped()
                .ignoresSafeArea()
            dimColor.opacity(dim)
                .ignoresSafeArea()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.nightNavy)
    }
}

struct PanelCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background {
                ArtImage(name: "ui_panel_dark")
                    .scaledToFit()
            }
    }
}
