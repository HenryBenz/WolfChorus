import AVFoundation
import Combine

final class AudioService: ObservableObject {
    private let engine = AVAudioEngine()
    private let musicMixer = AVAudioMixerNode()
    private let ambientMixer = AVAudioMixerNode()
    private let sfxMixer = AVAudioMixerNode()
    private var musicPlayers: [AVAudioPlayerNode] = []
    private var ambientPlayers: [AVAudioPlayerNode] = []
    private var sfxPlayers: [AVAudioPlayerNode] = []
    private var positionalPlayers: [AVAudioPlayerNode] = []
    private var positionalMixers: [AVAudioMixerNode] = []
    private var pitches: [AVAudioUnitTimePitch] = []
    private var connected: Set<ObjectIdentifier> = []
    private var started = false
    private var musicIndex = 0
    private var ambientIndex = 0
    private var sfxIndex = 0
    private var positionalIndex = 0
    private var currentMusic: String?
    private var currentAmbient: String?
    private var musicShouldLoop = true
    private var wasRunning = false
    private var inBackground = false
    private var sceneActive = true
    private var volumes = (music: Float(0.75), sfx: Float(0.85), ambient: Float(0.70))
    private var ambientScale: Float = 1
    private var previewing: PreviewChannel?
    private var fadeTask: Task<Void, Never>?
    private let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
    private let monoFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    enum PreviewChannel { case music, sfx, ambient }

    func start() {
        guard !started else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [])
            try session.setActive(true)
            configureGraph()
            engine.prepare()
            try engine.start()
            started = true
            NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: session)
            NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: session)
        } catch {
            print("Audio engine failed to start")
        }
    }

    func setVolumes(music: Double, sfx: Double, ambient: Double) {
        volumes = (Float(music), Float(sfx), Float(ambient))
        applyBusVolumes()
    }

    func playMusic(_ name: String, loop: Bool) {
        start()
        guard started else { return }
        if currentMusic == name, musicShouldLoop == loop, musicPlayers[musicIndex].isPlaying { return }
        musicShouldLoop = loop
        crossfade(name: name, players: musicPlayers, index: &musicIndex, mixer: musicMixer, duration: 1.5, loop: loop)
        currentMusic = name
    }

    func playAmbient(_ name: String) {
        start()
        guard started else { return }
        if currentAmbient == name, ambientPlayers[ambientIndex].isPlaying { return }
        crossfade(name: name, players: ambientPlayers, index: &ambientIndex, mixer: ambientMixer, duration: 0.8, loop: true)
        currentAmbient = name
    }

    func stopAmbient() {
        ambientPlayers.forEach { safeStop($0) }
        currentAmbient = nil
    }

    func playSFX(_ name: String) {
        guard previewing != .music && previewing != .ambient else { return }
        guard let buffer = buffer(named: name) else { return }
        play(buffer: buffer, on: &sfxPlayers, index: &sfxIndex, mixer: sfxMixer, loop: false)
    }

    func playPositional(_ name: String, pan: Float, pitch: Float = 0) {
        guard started || startAndCheck(), engine.isRunning else { return }
        guard let buffer = buffer(named: name), matches(buffer, monoFormat) else { return }
        let slot = positionalIndex
        positionalIndex = (positionalIndex + 1) % max(1, positionalPlayers.count)
        guard slot < positionalPlayers.count else { return }
        let player = positionalPlayers[slot]
        let mixer = positionalMixers[slot]
        let pitchNode = pitches[slot]
        mixer.pan = max(-0.75, min(0.75, pan))
        let cents = 1200 * log2f(max(0.5, min(2, 1 + pitch)))
        pitchNode.pitch = max(-2400, min(2400, cents))
        safeStop(player)
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        safePlay(player)
    }

    func beginPreview(_ channel: PreviewChannel) {
        previewing = channel
        applyBusVolumes()
        switch channel {
        case .music:
            if let currentMusic { playMusic(currentMusic, loop: true) }
            else { playMusic("music_home", loop: true) }
        case .ambient:
            if let currentAmbient { playAmbient(currentAmbient) }
            else { playAmbient("amb_blue_forest") }
        case .sfx:
            playSFX("sfx_ui_tap")
        }
    }

    func endPreview() {
        previewing = nil
        applyBusVolumes()
    }

    func pauseGameplayAudio() {
        ambientScale = 0.25
        applyBusVolumes()
        for player in positionalPlayers where player.isPlaying {
            safePause(player)
        }
    }

    func resumeGameplayAudio() {
        ambientScale = 1
        applyBusVolumes()
    }

    func noteSceneActive(_ active: Bool) {
        sceneActive = active
    }

    func enterBackground() {
        inBackground = true
        fadeTask?.cancel()
        if engine.isRunning {
            wasRunning = true
            engine.pause()
        }
    }

    func enterForeground() {
        let shouldResume = wasRunning || inBackground
        inBackground = false
        guard shouldResume else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            if !engine.isRunning {
                try engine.start()
            }
            guard engine.isRunning else { return }
            resumeLoop(name: currentMusic, players: musicPlayers, index: musicIndex, mixer: musicMixer, loop: musicShouldLoop)
            resumeLoop(name: currentAmbient, players: ambientPlayers, index: ambientIndex, mixer: ambientMixer, loop: true)
            wasRunning = true
        } catch {
            recoverEngine()
        }
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        let resume = {
            if type == .began {
                if self.engine.isRunning {
                    self.wasRunning = true
                    self.engine.pause()
                }
            } else if type == .ended {
                let options = AVAudioSession.InterruptionOptions(rawValue: info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
                if options.contains(.shouldResume), self.sceneActive, !self.inBackground {
                    self.enterForeground()
                }
            }
        }
        if Thread.isMainThread {
            resume()
        } else {
            DispatchQueue.main.async(execute: resume)
        }
    }

    private func resumeLoop(name: String?, players: [AVAudioPlayerNode], index: Int, mixer: AVAudioMixerNode, loop: Bool) {
        guard engine.isRunning, let name, let buffer = buffer(named: name), matches(buffer, stereoFormat) else { return }
        guard players.indices.contains(index) else { return }
        for (slot, player) in players.enumerated() {
            let isCurrent = slot == index
            if isCurrent {
                connect(player, to: mixer, format: buffer.format)
                safeStop(player)
                player.volume = 1
                player.scheduleBuffer(buffer, at: nil, options: loop ? .loops : [], completionHandler: nil)
                safePlay(player)
            } else {
                safeStop(player)
            }
        }
    }

    private func recoverEngine() {
        fadeTask?.cancel()
        engine.stop()
        engine.reset()
        connected.removeAll()
        musicPlayers = []
        ambientPlayers = []
        sfxPlayers = []
        positionalPlayers = []
        positionalMixers = []
        pitches = []
        started = false
        start()
        guard started, engine.isRunning else { return }
        resumeLoop(name: currentMusic, players: musicPlayers, index: musicIndex, mixer: musicMixer, loop: musicShouldLoop)
        resumeLoop(name: currentAmbient, players: ambientPlayers, index: ambientIndex, mixer: ambientMixer, loop: true)
    }

    private func startAndCheck() -> Bool {
        start()
        return started
    }

    private func configureGraph() {
        engine.attach(musicMixer)
        engine.attach(ambientMixer)
        engine.attach(sfxMixer)
        engine.connect(musicMixer, to: engine.mainMixerNode, format: nil)
        engine.connect(ambientMixer, to: engine.mainMixerNode, format: nil)
        engine.connect(sfxMixer, to: engine.mainMixerNode, format: nil)
        musicPlayers = (0..<2).map { _ in AVAudioPlayerNode() }
        ambientPlayers = (0..<2).map { _ in AVAudioPlayerNode() }
        sfxPlayers = (0..<6).map { _ in AVAudioPlayerNode() }
        for player in musicPlayers { attach(player, to: musicMixer, format: stereoFormat) }
        for player in ambientPlayers { attach(player, to: ambientMixer, format: stereoFormat) }
        for player in sfxPlayers { attach(player, to: sfxMixer, format: stereoFormat) }
        positionalPlayers = (0..<4).map { _ in AVAudioPlayerNode() }
        positionalMixers = (0..<4).map { _ in AVAudioMixerNode() }
        pitches = (0..<4).map { _ in AVAudioUnitTimePitch() }
        for index in positionalPlayers.indices {
            let player = positionalPlayers[index]
            engine.attach(player)
            engine.attach(pitches[index])
            engine.attach(positionalMixers[index])
            engine.connect(player, to: pitches[index], format: monoFormat)
            engine.connect(pitches[index], to: positionalMixers[index], format: monoFormat)
            engine.connect(positionalMixers[index], to: sfxMixer, format: nil)
            connected.insert(ObjectIdentifier(player))
        }
        applyBusVolumes()
    }

    private func applyBusVolumes() {
        let musicOn = previewing == nil || previewing == .music
        let ambientOn = previewing == nil || previewing == .ambient
        let sfxOn = previewing == nil || previewing == .sfx
        musicMixer.outputVolume = musicOn ? volumes.music : 0
        ambientMixer.outputVolume = (ambientOn ? volumes.ambient : 0) * ambientScale
        sfxMixer.outputVolume = sfxOn ? volumes.sfx : 0
        if volumes.music <= 0.001 { musicMixer.outputVolume = 0 }
        if volumes.ambient <= 0.001 { ambientMixer.outputVolume = 0 }
        if volumes.sfx <= 0.001 { sfxMixer.outputVolume = 0 }
    }

    private func crossfade(name: String, players: [AVAudioPlayerNode], index: inout Int, mixer: AVAudioMixerNode, duration: Double, loop: Bool) {
        guard engine.isRunning, let buffer = buffer(named: name), matches(buffer, stereoFormat) else { return }
        let next = (index + 1) % players.count
        let incoming = players[next]
        let outgoing = players[index]
        connect(incoming, to: mixer, format: buffer.format)
        safeStop(incoming)
        incoming.volume = 0
        incoming.scheduleBuffer(buffer, at: nil, options: loop ? .loops : [], completionHandler: nil)
        safePlay(incoming)
        index = next
        fadeTask?.cancel()
        let steps = 12
        let delay = duration / Double(steps)
        fadeTask = Task { @MainActor in
            for step in 1...steps {
                if Task.isCancelled { return }
                let fraction = Float(step) / Float(steps)
                incoming.volume = fraction
                outgoing.volume = 1 - fraction
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            self.safeStop(outgoing)
            outgoing.volume = 1
        }
    }

    private func play(buffer: AVAudioPCMBuffer, on players: inout [AVAudioPlayerNode], index: inout Int, mixer: AVAudioMixerNode, loop: Bool) {
        guard started, engine.isRunning, matches(buffer, stereoFormat) else { return }
        let player = players[index]
        index = (index + 1) % players.count
        connect(player, to: mixer, format: buffer.format)
        safeStop(player)
        player.volume = 1
        player.scheduleBuffer(buffer, at: nil, options: loop ? .loops : [], completionHandler: nil)
        safePlay(player)
    }

    private func safeStop(_ player: AVAudioPlayerNode) {
        guard engine.isRunning, connected.contains(ObjectIdentifier(player)) else { return }
        player.stop()
    }

    private func safePause(_ player: AVAudioPlayerNode) {
        guard engine.isRunning, player.isPlaying else { return }
        player.pause()
    }

    private func safePlay(_ player: AVAudioPlayerNode) {
        guard engine.isRunning, connected.contains(ObjectIdentifier(player)) else { return }
        player.play()
    }

    private func attach(_ player: AVAudioPlayerNode, to mixer: AVAudioMixerNode, format: AVAudioFormat) {
        engine.attach(player)
        engine.connect(player, to: mixer, format: format)
        connected.insert(ObjectIdentifier(player))
    }

    private func matches(_ buffer: AVAudioPCMBuffer, _ format: AVAudioFormat) -> Bool {
        buffer.frameLength > 0
            && buffer.format.sampleRate == format.sampleRate
            && buffer.format.channelCount == format.channelCount
            && buffer.format.commonFormat == format.commonFormat
    }

    private func connect(_ player: AVAudioPlayerNode, to mixer: AVAudioMixerNode, format: AVAudioFormat) {
        let key = ObjectIdentifier(player)
        if connected.contains(key) { return }
        engine.connect(player, to: mixer, format: format)
        connected.insert(key)
    }

    private func buffer(named name: String) -> AVAudioPCMBuffer? {
        if let cached = cache[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a") else {
            print(name + ".m4a")
            return nil
        }
        do {
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { return nil }
            try file.read(into: buffer)
            cache[name] = buffer
            return buffer
        } catch {
            print(name + ".m4a")
            return nil
        }
    }

    private var cache: [String: AVAudioPCMBuffer] = [:]

    func pan(for x: CGFloat, width: CGFloat) -> Float {
        guard width > 1 else { return 0 }
        let normalized = Float((x / width) * 2 - 1)
        return max(-0.75, min(0.75, normalized * 0.75))
    }
}
