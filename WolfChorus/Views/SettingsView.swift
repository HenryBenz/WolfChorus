import SwiftUI

struct SettingsView: View {
    var onClose: (() -> Void)? = nil
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var save: SaveService
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var haptics: HapticsService
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var purchase: PurchaseService
    @State private var confirmReset = false

    var body: some View {
        ZStack {
            Theme.nightNavy.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBar(title: "SETTINGS", close: { close() })
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        slider("Music", value: preferences.music, icon: preferences.music > 0, set: { preferences.music = $0 }, preview: .music)
                        slider("Sound Effects", value: preferences.sfx, icon: preferences.sfx > 0, set: { preferences.sfx = $0 }, preview: .sfx)
                        slider("Ambient Sound", value: preferences.ambient, icon: preferences.ambient > 0, set: { preferences.ambient = $0 }, preview: .ambient)
                        toggle("Haptics", isOn: $preferences.haptics)
                        toggle("Reduce Motion", isOn: $preferences.reduceMotion)
                        toggle("High Contrast Echoes", isOn: $preferences.highContrast)
                        ChorusButton(title: "Restore Purchase", kind: .secondary, enabled: !purchase.isRestoring) {
                            Task {
                                let outcome = await purchase.restore()
                                switch outcome {
                                case .restored: purchase.alert = .restored
                                case .nothing: purchase.alert = .nothing
                                case .failed: purchase.alert = .failed
                                }
                            }
                        }
                        .overlay { if purchase.isRestoring { ProgressView().tint(Theme.iceWhite) } }
                        ChorusButton(title: "Reset Campaign", kind: .danger) { confirmReset = true }
                    }
                    .padding(24)
                    .background(Theme.panelBlack)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .onChange(of: preferences.music) { _, _ in pushVolumes() }
        .onChange(of: preferences.sfx) { _, _ in pushVolumes() }
        .onChange(of: preferences.ambient) { _, _ in pushVolumes() }
        .onChange(of: preferences.haptics) { _, value in haptics.enabled = value }
        .confirmationDialog("Reset Campaign?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                save.resetCampaign()
                audio.playMusic("music_home", loop: true)
                router.modal = nil
                router.setStack([])
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Chapters, results, and discovered memories will be erased. Settings and purchases will remain.")
        }
    }

    private func close() {
        audio.endPreview()
        if let onClose { onClose() } else { router.closeSettings() }
    }

    private func pushVolumes() {
        audio.setVolumes(music: preferences.music, sfx: preferences.sfx, ambient: preferences.ambient)
    }

    private func slider(_ title: String, value: Double, icon: Bool, set: @escaping (Double) -> Void, preview: AudioService.PreviewChannel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.body())
                .foregroundStyle(Theme.primaryText)
            HStack(spacing: 10) {
                ArtImage(name: icon ? "ui_icon_sound_on" : "ui_icon_sound_off")
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
                Slider(value: Binding(get: { value }, set: set), in: 0...1, onEditingChanged: { editing in
                    if editing { audio.beginPreview(preview) } else { audio.endPreview() }
                })
                .accessibilityLabel(title)
                Text("\(Int((value * 100).rounded()))%")
                    .font(Theme.hudNumber())
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }

    private func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(Theme.body())
                .foregroundStyle(Theme.primaryText)
        }
        .tint(Theme.moonCyan)
        .frame(minHeight: 44)
    }
}
