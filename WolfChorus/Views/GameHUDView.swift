import SwiftUI

struct GameHUDView: View {
    let hud: HUDModel
    let onPause: () -> Void
    let onSelect: (String) -> Void
    let onSkip: () -> Void
    let onRetry: () -> Void
    let onLeaveFailure: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBand
                Spacer().allowsHitTesting(false)
                if let countdown = hud.countdownText {
                    Text(countdown)
                        .font(Theme.hudNumber())
                        .foregroundStyle(Theme.iceWhite)
                        .padding(.bottom, 4)
                        .allowsHitTesting(false)
                }
                bottomBand
            }
            .ignoresSafeArea()
            if hud.fade > 0 {
                Color.black.opacity(hud.fade).ignoresSafeArea().allowsHitTesting(false)
            }
            if let tutorial = hud.tutorial {
                Color.black.opacity(0.55).ignoresSafeArea().allowsHitTesting(false)
                VStack {
                    VStack(spacing: 12) {
                        Text(tutorial)
                            .font(Theme.body())
                            .foregroundStyle(Theme.primaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(16)
                    .background(Theme.panelBlack)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
                    .padding(.top, 120)
                    Spacer()
                }
                .allowsHitTesting(false)
            if hud.showSkip {
                Button("Skip Tutorial", action: onSkip)
                    .font(Theme.buttonLabel())
                    .foregroundStyle(Theme.iceWhite)
                    .frame(minWidth: 44, minHeight: 44)
                    .padding(.top, 188)
                    .accessibilityLabel("Skip Tutorial")
            }
            }
            if let number = hud.resumeNumber {
                Text("\(number)")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.iceWhite)
                    .accessibilityLabel("\(number)")
            }
            if hud.failed {
                failure
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var topBand: some View {
        HStack(alignment: .center, spacing: 8) {
            IconButton(icon: "ui_icon_pause", label: "Pause", action: onPause)
            Text(hud.objective)
                .font(Theme.hudText())
                .foregroundStyle(Theme.primaryText)
                .lineLimit(2)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .frame(maxWidth: .infinity)
            VStack(spacing: 4) {
                Text("FOREST")
                    .font(Theme.hudText())
                    .foregroundStyle(Theme.secondaryText)
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { index in
                        Circle()
                            .fill(index < AttentionBand.pips(for: hud.attention) ? Theme.alphaRed : Color.white.opacity(0.25))
                            .frame(width: 8, height: 8)
                    }
                }
                if let strong = hud.strongHowlText {
                    Text(strong)
                        .font(Theme.hudNumber())
                        .foregroundStyle(Theme.iceWhite)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Forest \(AttentionBand.name(for: hud.attention))")
        }
        .padding(.horizontal, 12)
        .padding(.top, 52)
        .frame(height: 110, alignment: .bottom)
    }

    private var bottomBand: some View {
        VStack(spacing: 4) {
            if let howl = hud.selectedHowl {
                Text(howl)
                    .font(Theme.hudText())
                    .foregroundStyle(Theme.moonCyan)
                    .allowsHitTesting(false)
            }
            HStack(spacing: 8) {
                ForEach(hud.portraits) { portrait in
                    Button {
                        onSelect(portrait.id)
                    } label: {
                        VStack(spacing: 2) {
                            ZStack {
                                ArtImage(name: portrait.image)
                                    .scaledToFill()
                                    .frame(width: 58, height: 58)
                                    .clipShape(Circle())
                                Circle()
                                    .trim(from: 0, to: portrait.trust / 100)
                                    .stroke(Theme.moonCyan, lineWidth: 3)
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 58, height: 58)
                                Circle()
                                    .trim(from: 0, to: portrait.anxiety / 100)
                                    .stroke(Theme.alphaRed, lineWidth: 2)
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 48, height: 48)
                                if portrait.recallRemaining > 0 {
                                    Circle()
                                        .trim(from: 0, to: portrait.recallRemaining)
                                        .stroke(Theme.iceWhite, lineWidth: 2)
                                        .rotationEffect(.degrees(-90))
                                        .frame(width: 64, height: 64)
                                }
                            }
                            .shadow(color: portrait.selected ? Color(hexString: portrait.colorHex) : .clear, radius: 8)
                            Text(portrait.name)
                                .font(Theme.hudText())
                                .foregroundStyle(portrait.selected ? Theme.iceWhite : Theme.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(PressScaleStyle())
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("\(portrait.name)")
                }
            }
            .frame(height: 76)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 166, alignment: .top)
        .background(
            Color.clear
                .accessibilityElement()
                .accessibilityLabel(hud.accessibility)
        )
    }

    private var failure: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("THE PACK SCATTERED")
                    .font(Theme.screenTitle())
                    .tracking(1.2)
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.center)
                Text("Return to the last encounter and call them together.")
                    .font(Theme.body())
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                ChorusButton(title: "RETRY ENCOUNTER") { onRetry() }
                ChorusButton(title: "LEAVE CHAPTER", kind: .danger) { onLeaveFailure() }
            }
            .padding(24)
        }
    }
}
