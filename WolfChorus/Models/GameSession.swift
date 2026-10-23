import CoreGraphics
import Foundation
import Combine

enum GameMode: Hashable {
    case campaign(chapterID: Int, resumeSuspended: Bool)
    case endless(difficulty: String, wolfIDs: [String])
}

struct PortraitHUD: Identifiable, Equatable {
    var id: String
    var name: String
    var image: String
    var trust: Double
    var anxiety: Double
    var selected: Bool
    var recallRemaining: Double
    var colorHex: String
}

struct HUDModel: Equatable {
    var objective = ""
    var attention = 0.0
    var portraits: [PortraitHUD] = []
    var selectedHowl: String?
    var hint: String?
    var tutorial: String?
    var showSkip = false
    var paused = false
    var resumeNumber: Int?
    var failed = false
    var fade = 0.0
    var countdownText: String?
    var strongHowlText: String?
    var accessibility = ""
    var chapterTitle = ""
}

enum TutorialCue: Equatable {
    case select, aim, charge, target, recall, morHowl, lumiHowl
}

enum FadePhase {
    case none, out, inn
}

final class GameSession: ObservableObject {
    @Published private(set) var hud = HUDModel()

    let mode: GameMode
    private let save: SaveService
    private let audio: AudioService
    private let haptics: HapticsService
    private let ownsWhiteMoon: Bool

    private(set) var playable = CGRect(x: 24, y: 166, width: 345, height: 588)
    private(set) var sceneSize = CGSize(width: 393, height: 852)
    private(set) var wolves: [PackWolf] = []
    private(set) var points: [EchoPoint] = []
    private(set) var echoes: [EchoBurst] = []
    private(set) var aim = AimRender()
    private(set) var backgroundName = "bg_chapter_01_blue_pines"
    private(set) var panIndex = 0
    private(set) var weather = ""
    private(set) var leaderPath: [CGPoint] = []
    private(set) var decoyPoint: CGPoint?
    private(set) var obstaclePoint: CGPoint?
    private(set) var shimmerPoint: CGPoint?
    private(set) var reduceMotion = false
    private(set) var highContrast = false
    private(set) var shakeUntil = 0.0
    private(set) var leaderID = "arkan"

    var onCampaignResult: ((GameResult) -> Void)?
    var onEndlessResult: ((EndlessResult) -> Void)?
    var onLeave: (() -> Void)?

    private var chapter: ChapterDefinition?
    private var encounterIndex = 0
    private var encounterDef: EncounterDefinition?
    private var laidOut = false
    private var selectedID: String?
    private var pressedPoint: String?
    private var lastQuick: (time: TimeInterval, point: CGPoint)?
    private var tutorial: TutorialCue?
    private var tutorialDone = false
    private var showSkipTutorial = false
    private var assistShimmer = false
    private var paused = false
    private var failed = false
    private var resumeLeft: Double?
    private var fadePhase: FadePhase = .none
    private var fade = 0.0
    private var finished = false
    private var attention = 0.0
    private var attentionClock = 0.0
    private var attentionDecay = 2.0
    private var hazardScale = 1.0
    private var howlActive = 0.0
    private var hazardEvent = 0.0
    private var countdown: Double?
    private var strongHowlCount = 0
    private var noTargetTime = 0.0
    private var pulseTime = 0.0
    private var iceArm: Double?
    private var iceFrozen = 0.0
    private var decoyLeft = 0.0
    private var panickedTogether = 0.0
    private var preyPhase = 0.0
    private var requiredDone = false
    private var exitWaiting = false
    private var chapterMemoryFinds: [Int] = []
    private var endlessMemories = 0
    private var endlessClears = 0
    private var templateBag: [Int] = []
    private var lastTemplate = -1
    private var endlessDifficulty = "wild"
    private var endlessWolves: [String] = []
    private var baseline = EncounterBaseline(wolves: [], attention: 0, countdownRemaining: nil, strongHowlCount: 0, collectedMemoryIDs: [], chapterMemoryFinds: [], tutorialDone: false)
    private var rng = SystemRandomNumberGenerator()
    private var hudClock = 0.0

    init(mode: GameMode, save: SaveService, audio: AudioService, haptics: HapticsService, ownsWhiteMoon: Bool) {
        self.mode = mode
        self.save = save
        self.audio = audio
        self.haptics = haptics
        self.ownsWhiteMoon = ownsWhiteMoon
        switch mode {
        case .campaign(let id, _):
            chapter = ContentCatalog.chapter(id)
            backgroundName = chapter?.background ?? backgroundName
            showSkipTutorial = save.data.completedChapterIDs.contains(id)
        case .endless(let difficulty, let wolves):
            endlessDifficulty = difficulty
            endlessWolves = wolves
            let tuning = Self.tuning(difficulty)
            attentionDecay = tuning.decay
            hazardScale = tuning.multiplier
        }
    }

    func apply(preferences: Preferences) {
        reduceMotion = preferences.reduceMotion
        highContrast = preferences.highContrast
        haptics.enabled = preferences.haptics
        publish()
    }

    func updateLayout(sceneSize: CGSize, safeTop: CGFloat, safeBottom: CGFloat) {
        self.sceneSize = sceneSize
        let top = max(98, safeTop + 52)
        let bottom = max(166, safeBottom + 120)
        let rect = CGRect(x: 24, y: bottom, width: max(40, sceneSize.width - 48), height: max(40, sceneSize.height - top - bottom))
        guard rect.width > 40, rect.height > 40 else { return }
        playable = rect
        if !laidOut {
            laidOut = true
            begin()
        }
        publish()
    }

    func tick(_ dt: Double) {
        let dt = min(0.05, max(0, dt))
        guard laidOut, !finished else { return }
        if let left = resumeLeft {
            resumeLeft = left - dt
            if (resumeLeft ?? 0) <= 0 {
                resumeLeft = nil
                paused = false
                audio.resumeGameplayAudio()
            }
            publish()
            return
        }
        guard !paused, !failed else { return }
        if fadePhase != .none {
            stepFade(dt)
            publish()
            return
        }
        if aim.active {
            aim.charge = min(1.2, aim.charge + dt)
            if let id = selectedID, let wolf = wolves.first(where: { $0.id == id }) {
                aim.origin = wolf.position
            }
        }
        for index in echoes.indices { echoes[index].age += dt }
        echoes.removeAll { $0.age >= 1.1 }
        howlActive = max(0, howlActive - dt)
        hazardEvent = max(0, hazardEvent - dt)
        iceFrozen = max(0, iceFrozen - dt)
        if let arm = iceArm {
            iceArm = arm - dt
            if (iceArm ?? 0) <= 0 {
                iceArm = nil
                triggerIce()
            }
        }
        decoyLeft = max(0, decoyLeft - dt)
        if decoyLeft <= 0 { decoyPoint = nil }
        decayReveals(dt)
        if tutorialFreezes {
            for index in wolves.indices {
                wolves[index].cooldown = max(0, wolves[index].cooldown - dt)
                wolves[index].howlLeft = max(0, wolves[index].howlLeft - dt)
            }
            publishMaybe(dt)
            return
        }
        stepWorld(dt)
        publishMaybe(dt)
    }

    func selectWolf(_ id: String) {
        guard laidOut, !paused, !failed, fadePhase == .none else { return }
        guard wolves.contains(where: { $0.id == id }) else { return }
        selectedID = id
        audio.playSFX("sfx_ui_wolf_select")
        haptics.wolfSelect()
        if tutorial == .select { tutorial = .aim }
        publish()
    }

    func touchBegan(at point: CGPoint, echoID: String?) {
        guard laidOut, !paused, !failed, fadePhase == .none else { return }
        if let echoID {
            pressedPoint = echoID
            return
        }
        if tutorial == .select { return }
        guard let selectedID, let wolf = wolves.first(where: { $0.id == selectedID }) else {
            deny()
            return
        }
        if wolf.state == .panicked || wolf.cooldown > 0 {
            deny()
            return
        }
        aim.active = true
        aim.charge = 0
        aim.finger = point
        aim.origin = wolf.position
        if tutorial == .aim { tutorial = .charge }
    }

    func touchMoved(to point: CGPoint) {
        guard aim.active else { return }
        aim.finger = point
        if let selectedID, let wolf = wolves.first(where: { $0.id == selectedID }) {
            aim.origin = wolf.position
        }
    }

    func touchEnded(at point: CGPoint) {
        if let id = pressedPoint {
            pressedPoint = nil
            tap(id)
            return
        }
        guard aim.active else { return }
        aim.finger = point
        let charge = aim.charge
        aim.active = false
        if charge < 0.25 {
            registerQuickTap(point)
            return
        }
        releaseHowl(at: point)
    }

    func pauseFromUser() {
        guard !failed, !finished else { return }
        paused = true
        aim.active = false
        audio.pauseGameplayAudio()
        publish()
    }

    func systemPause() {
        guard laidOut, !finished else { return }
        if case .campaign = mode {
            save.writeSuspended(snapshot())
        }
        paused = true
        aim.active = false
        resumeLeft = nil
        audio.pauseGameplayAudio()
        publish()
    }

    func beginResume() {
        guard paused, !failed else { return }
        resumeLeft = 3
        publish()
    }

    func restartEncounter() {
        failed = false
        paused = false
        resumeLeft = nil
        audio.resumeGameplayAudio()
        restoreBaseline()
        publish()
    }

    func leaveChapter() {
        if case .campaign = mode {
            save.writeSuspended(snapshot())
        }
        finished = true
        onLeave?()
    }

    func leaveFromFailure() {
        failed = false
        restoreBaseline()
        leaveChapter()
    }

    func retryFromFailure() {
        restartEncounter()
    }

    func skipTutorial() {
        tutorial = nil
        tutorialDone = true
        assistShimmer = false
        publish()
    }

    private func begin() {
        switch mode {
        case .campaign(let id, let resume):
            if resume, let suspended = save.data.suspendedCampaign, suspended.chapterID == id {
                restore(suspended)
            } else {
                save.writeSuspended(nil)
                encounterIndex = 0
                if let chapter {
                    attention = 0
                    countdown = chapter.countdownSeconds
                    strongHowlCount = 0
                    prepareEncounter(chapter.encounters[0], number: 1, freshStats: true)
                    save.noteChapterStarted(id)
                    if chapter.special == "tutorial" {
                        tutorial = .select
                        selectedID = nil
                    }
                }
                storeBaseline()
                save.writeSuspended(snapshot())
            }
            if let chapter {
                audio.playAmbient(chapter.ambient)
            }
        case .endless(let difficulty, let ids):
            save.rememberEndless(difficulty: difficulty, pack: ids)
            attention = 0
            endlessClears = 0
            prepareEndlessEncounter(freshStats: true)
            audio.playAmbient(ContentCatalog.chapter(backgroundChapterID)?.ambient ?? "amb_blue_forest")
        }
        publish()
    }

    private func prepareEncounter(_ definition: EncounterDefinition, number: Int, freshStats: Bool) {
        encounterDef = definition
        requiredDone = false
        exitWaiting = false
        iceArm = nil
        decoyLeft = 0
        decoyPoint = nil
        noTargetTime = 0
        assistShimmer = false
        panIndex = (number - 1) % 3
        points = EncounterController.build(definition: definition, encounterNumber: number, chapter: chapter ?? ContentCatalog.chapters[0])
        let activeChapter = chapter
        let ids = activeChapter?.activeWolfIDs(encounterNumber: number) ?? endlessWolves
        leaderID = activeChapter?.leaderID ?? (ids.contains("arkan") ? "arkan" : ids.first ?? "arkan")
        for id in ids { save.unlockWolf(id) }
        if freshStats {
            let trust = activeChapter?.startingTrust ?? Self.tuning(endlessDifficulty).trust
            let anxiety = activeChapter?.startingAnxiety ?? Self.tuning(endlessDifficulty).anxiety
            let split = activeChapter?.special == "divide" || (activeChapter == nil && definition.hazardKind == "trunk" && false)
            wolves = ids.enumerated().map { index, id in
                let node: NodeID = split ? (index.isMultiple(of: 2) ? .P1 : .P3) : .P0
                return PackController.makeWolf(id: id, trust: trust, anxiety: anxiety, node: node, playable: playable)
            }
        } else {
            var kept = wolves.filter { ids.contains($0.id) }
            for id in ids where !kept.contains(where: { $0.id == id }) {
                let trust = activeChapter?.startingTrust ?? 70
                let anxiety = activeChapter?.startingAnxiety ?? 25
                kept.append(PackController.makeWolf(id: id, trust: trust, anxiety: anxiety, node: .P0, playable: playable))
                save.unlockWolf(id)
            }
            for index in kept.indices {
                let node: NodeID = (activeChapter?.special == "divide") ? (index.isMultiple(of: 2) ? .P1 : .P3) : .P0
                kept[index].node = node
                kept[index].position = node.scenePoint(in: playable)
                kept[index].path = []
                kept[index].destinationPointID = nil
            }
            wolves = kept
        }
        if tutorial == nil, selectedID == nil || !ids.contains(selectedID ?? "") {
            selectedID = leaderID
        }
        backgroundName = activeChapter?.background ?? backgroundName
        weather = weatherName(for: activeChapter?.id ?? backgroundChapterID)
        obstaclePoint = obstacle(for: definition, chapterID: activeChapter?.id ?? backgroundChapterID)
        if activeChapter?.special == "exile", number == activeChapter?.joiningEncounter {
            tutorial = .morHowl
            selectedID = "mor"
        }
        if activeChapter?.special == "frozenVoice", number == 1 {
            tutorial = .lumiHowl
            selectedID = "lumi"
        }
        leaderPath = []
        applyFormation(repositionIdle: true)
    }

    private func prepareEndlessEncounter(freshStats: Bool) {
        let templates = ContentCatalog.endlessTemplates
        if templateBag.isEmpty {
            templateBag = Array(templates.indices)
        }
        var pick = templateBag.randomElement() ?? 0
        if pick == lastTemplate, templateBag.count > 1 {
            pick = templateBag.first(where: { $0 != lastTemplate }) ?? pick
        }
        templateBag.removeAll { $0 == pick }
        lastTemplate = pick
        let template = templates[pick]
        let major = (endlessClears + 1) % 5 == 0
        var definition = template.encounter
        if major { definition.hazardKind = "fire" }
        backgroundChapterID = template.chapterID
        backgroundName = ContentCatalog.chapter(template.chapterID)?.background ?? "bg_chapter_10_red_moon"
        chapter = nil
        encounterIndex = endlessClears
        if freshStats {
            let tuning = Self.tuning(endlessDifficulty)
            wolves = endlessWolves.map {
                PackController.makeWolf(id: $0, trust: tuning.trust, anxiety: tuning.anxiety, node: .P0, playable: playable)
            }
            leaderID = endlessWolves.contains("arkan") ? "arkan" : (endlessWolves.first ?? "arkan")
            selectedID = leaderID
        }
        prepareEncounter(definition, number: endlessClears + 1, freshStats: false)
        if freshStats {
            let tuning = Self.tuning(endlessDifficulty)
            wolves = endlessWolves.map {
                PackController.makeWolf(id: $0, trust: tuning.trust, anxiety: tuning.anxiety, node: .P0, playable: playable)
            }
        }
        audio.playAmbient(ContentCatalog.chapter(template.chapterID)?.ambient ?? "amb_blue_forest")
    }

    private var backgroundChapterID = 1

    private func stepWorld(_ dt: Double) {
        let threat = nearestThreatPosition()
        for index in wolves.indices {
            var wolf = wolves[index]
            let speed = (ContentCatalog.wolf(wolf.id)?.speed ?? 74) * (wolf.state == .guarded ? 0.8 : 1)
            let anchor = wolves.first(where: { $0.id == "arkan" }) ?? wolves.first(where: { $0.id == leaderID })
            if let anchor, wolf.id != anchor.id, wolf.state == .guarded {
                if wolf.path.last != anchor.node && wolf.node != anchor.node {
                    PackController.assign(wolf: &wolf, to: anchor.node, playable: playable, alternate: nil)
                }
            }
            let before = wolf.path.count
            PackController.tick(wolf: &wolf, dt: dt, playable: playable, speed: CGFloat(speed), leaderPosition: leaderPosition(), threatPosition: threat)
            if before > 0, wolf.path.isEmpty {
                wolves[index] = wolf
                arrived(wolfIndex: index)
                wolf = wolves[index]
            }
            wolves[index] = wolf
        }
        let nora = wolves.first { $0.id == "nora" }?.position
        let arkan = wolves.first { $0.id == "arkan" }?.position
        for index in wolves.indices {
            if let arkan, wolves[index].id != "arkan" {
                let away = distance(wolves[index].position, arkan)
                if away > 300 {
                    wolves[index].separated += dt
                    if wolves[index].separated > 5 {
                        wolves[index].anxiety = min(100, wolves[index].anxiety + 3 * dt)
                    }
                } else {
                    wolves[index].separated = 0
                }
            }
            if let nora, wolves[index].id != "nora", distance(wolves[index].position, nora) <= 140 {
                wolves[index].anxiety = max(0, wolves[index].anxiety - dt * 0.5)
            }
            wolves[index].clamp()
        }
        attentionClock += dt
        if attentionClock >= 5 {
            attentionClock -= 5
            if howlActive <= 0, hazardEvent <= 0 {
                attention = max(0, attention - attentionDecay)
            }
        }
        if countdown != nil {
            countdown = max(0, (countdown ?? 0) - dt)
            if countdown == 0 { scatter() }
        }
        if chapter?.special == "fireCountdown" {
            pulseTime += dt
            if pulseTime >= 20 {
                pulseTime -= 20
                pulseAnxiety(HowlStrength.soft.emotion)
                audio.playSFX("sfx_fire_burst")
                audio.playSFX("sfx_anxiety_rise")
                requestShake()
                hazardEvent = 3
            }
        }
        preyPhase += dt
        for index in points.indices where !points[index].consumed && points[index].type == .prey {
            points[index].offset = CGPoint(x: sin(preyPhase) * 16, y: cos(preyPhase * 0.8) * 10)
        }
        if decoyLeft > 0, let decoy = decoyPoint {
            for index in points.indices where points[index].type == .threat && !points[index].consumed {
                let base = points[index].node.scenePoint(in: playable)
                let dx = decoy.x - (base.x + points[index].offset.x)
                let dy = decoy.y - (base.y + points[index].offset.y)
                points[index].offset.x += dx * CGFloat(dt) * 0.8
                points[index].offset.y += dy * CGFloat(dt) * 0.8
            }
        }
        let panicked = wolves.filter { $0.state == .panicked }.count
        if panicked >= 3 {
            panickedTogether += dt
            if panickedTogether >= 5 { scatter() }
        } else {
            panickedTogether = 0
        }
        let visible = points.contains { $0.isVisible }
        if visible {
            noTargetTime = 0
            shimmerPoint = nil
        } else {
            noTargetTime += dt
            if noTargetTime >= 8 || assistShimmer {
                shimmerPoint = nearestRequiredPosition()
            }
        }
        if exitWaiting, let exit = points.first(where: { $0.id.hasPrefix("exit") && !$0.consumed }) {
            if attentionAllowsExit(), wolves.contains(where: { $0.id == leaderID && $0.node == exit.node && $0.path.isEmpty }) {
                finishExit()
            }
        }
    }

    private func releaseHowl(at finger: CGPoint) {
        guard let selectedID, let wolfIndex = wolves.firstIndex(where: { $0.id == selectedID }) else { return }
        guard wolves[wolfIndex].state != .panicked, wolves[wolfIndex].cooldown <= 0 else {
            deny()
            return
        }
        guard let strength = HowlStrength.from(charge: aim.charge) else { return }
        guard let definition = ContentCatalog.wolf(wolves[wolfIndex].id) else { return }
        let origin = wolves[wolfIndex].position
        let direction = CGVector(dx: finger.x - origin.x, dy: finger.y - origin.y)
        let geometry = EchoController.geometry(for: definition, strength: strength, origin: origin, direction: direction)
        wolves[wolfIndex].cooldown = 2.2
        wolves[wolfIndex].howlLeft = definition.vocal(for: strength).duration
        audio.playSFX(strength.echoSound)
        let pan = audio.pan(for: origin.x, width: sceneSize.width)
        audio.playPositional(definition.vocal(for: strength).name, pan: pan)
        if strength == .medium { haptics.mediumHowl() }
        if strength == .strong { haptics.strongHowl(); strongHowlCount += 1 }
        var cost = strength.attentionCost
        if definition.echo == "calming" { cost = max(0, cost - 4) }
        if definition.echo == "frozen" { cost += 3 }
        attention = min(100, attention + cost)
        howlActive = 1.1
        echoes.append(EchoBurst(origin: origin, direction: geometry.direction, range: geometry.range, halfAngle: geometry.halfAngle, fullCircle: geometry.fullCircle, colorHex: definition.colorHex))
        var revealedAny = false
        var foundSecret = false
        for index in points.indices where !points[index].consumed {
            let pos = pointPosition(points[index])
            if EchoController.occluded(howlerID: definition.id, type: points[index].type, howler: origin, point: pos, obstacle: obstaclePoint) { continue }
            guard EchoController.contains(pos, geometry: geometry, irregular: definition.echo == "curious") else { continue }
            if definition.echo == "calming", points[index].type == .prey, distance(origin, pos) > 260 { continue }
            let duration = revealDuration(type: points[index].type, howler: definition)
            if !points[index].revealed {
                revealedAny = true
                if points[index].type == .memory || points[index].type == .secret { foundSecret = true }
                onReveal(index)
            }
            points[index].revealed = true
            points[index].revealRemaining = max(points[index].revealRemaining, duration)
        }
        applyHowlEmotions(definition: definition, strength: strength, geometry: geometry, foundSecret: foundSecret)
        if definition.echo == "false" {
            let length = max(1, hypot(direction.dx, direction.dy))
            let clamped = min(geometry.range, hypot(finger.x - origin.x, finger.y - origin.y))
            decoyPoint = CGPoint(x: origin.x + direction.dx / length * clamped, y: origin.y + direction.dy / length * clamped)
            decoyLeft = 6
        }
        if definition.echo == "frozen" {
            if let index = points.indices.first(where: { points[$0].hazardKind == "ice" && !points[$0].consumed && EchoController.contains(pointPosition(points[$0]), geometry: geometry, irregular: false) }) {
                _ = index
                iceFrozen = 8
                iceArm = nil
            }
        }
        if strength == .strong, iceFrozen <= 0 {
            let hitsIce = points.contains { point in
                point.hazardKind == "ice" && !point.consumed && EchoController.contains(pointPosition(point), geometry: geometry, irregular: false)
            }
            if hitsIce {
                iceArm = 3
                audio.playSFX("sfx_ice_warning")
                hazardEvent = 3
            }
        }
        if definition.echo == "curious" {
            for index in points.indices where points[index].type == .prey && !points[index].consumed {
                let pos = pointPosition(points[index])
                if EchoController.contains(pos, geometry: geometry, irregular: true) {
                    let dx = origin.x - pos.x
                    let dy = origin.y - pos.y
                    let len = max(1, hypot(dx, dy))
                    points[index].offset.x += dx / len * 80
                    points[index].offset.y += dy / len * 80
                }
            }
        }
        if tutorial == .charge {
            if revealedAny {
                tutorial = .target
                assistShimmer = false
            } else {
                assistShimmer = true
                shimmerPoint = nearestRequiredPosition()
            }
        }
        if tutorial == .morHowl, definition.id == "mor" {
            tutorial = nil
            tutorialDone = true
        }
        if tutorial == .lumiHowl, definition.id == "lumi" {
            tutorial = nil
            tutorialDone = true
        }
        publish()
    }

    private func applyHowlEmotions(definition: WolfDefinition, strength: HowlStrength, geometry: EchoGeometry, foundSecret: Bool) {
        let howler = wolves.first { $0.id == definition.id }?.position ?? geometry.origin
        var trustRose = false
        switch definition.echo {
        case "courage":
            for index in wolves.indices where distance(wolves[index].position, howler) <= 220 {
                wolves[index].trust += strength.emotion
                wolves[index].anxiety -= strength.emotion / 2
                trustRose = true
                wolves[index].clamp()
            }
        case "tracker":
            for index in wolves.indices where distance(wolves[index].position, howler) <= geometry.range {
                wolves[index].anxiety += 4
                wolves[index].shield = 12
                wolves[index].clamp()
            }
            audio.playSFX("sfx_anxiety_rise")
        case "calming":
            for index in wolves.indices where distance(wolves[index].position, howler) <= geometry.range {
                wolves[index].anxiety -= strength.emotion
                wolves[index].clamp()
            }
        case "curious":
            if let index = wolves.firstIndex(where: { $0.id == "rune" }) {
                wolves[index].anxiety += 5
                if foundSecret {
                    wolves[index].trust += 6
                    trustRose = true
                }
                wolves[index].clamp()
            }
        case "false":
            for index in wolves.indices where wolves[index].trust < 60 {
                wolves[index].trust -= 4
                wolves[index].clamp()
            }
        default:
            break
        }
        if trustRose { audio.playSFX("sfx_trust_restore") }
    }

    private func tap(_ id: String) {
        guard let index = points.firstIndex(where: { $0.id == id }), points[index].isVisible else { return }
        points[index].remembered = true
        let node = points[index].node
        for wolfIndex in wolves.indices where wolves[wolfIndex].state != .panicked {
            if wolves[wolfIndex].id != leaderID, wolves[wolfIndex].state == .guarded {
                wolves[wolfIndex].destinationPointID = nil
                continue
            }
            var alternate: NodeID?
            var destination = id
            if wolves[wolfIndex].state == .independent, chance(0.25), let other = alternatePoint(excluding: id, near: wolves[wolfIndex].position) {
                alternate = other.node
                destination = other.id
            }
            wolves[wolfIndex].destinationPointID = destination
            PackController.assign(wolf: &wolves[wolfIndex], to: node, playable: playable, alternate: alternate)
        }
        if let leader = wolves.first(where: { $0.id == leaderID }) {
            leaderPath = ([leader.node] + leader.path).map { $0.scenePoint(in: playable) }
        }
        if tutorial == .target {
            tutorial = .recall
        }
        publish()
    }

    private func recall() {
        guard tutorial == nil || tutorial == .recall else { return }
        guard let leaderIndex = wolves.firstIndex(where: { $0.id == leaderID }) else { return }
        guard wolves[leaderIndex].recallCooldown <= 0 else {
            deny()
            return
        }
        wolves[leaderIndex].recallCooldown = 8
        let node = wolves[leaderIndex].node
        for index in wolves.indices where wolves[index].state != .panicked {
            wolves[index].destinationPointID = nil
            PackController.assign(wolf: &wolves[index], to: node, playable: playable, alternate: nil)
        }
        audio.playSFX("sfx_pack_recall")
        if tutorial == .recall {
            tutorial = nil
            tutorialDone = true
        }
        publish()
    }

    private func arrived(wolfIndex: Int) {
        guard let dest = wolves[wolfIndex].destinationPointID,
              let index = points.firstIndex(where: { $0.id == dest && !$0.consumed && $0.node == wolves[wolfIndex].node }) else { return }
        wolves[wolfIndex].destinationPointID = nil
        resolve(index)
    }

    private func resolve(_ index: Int) {
        guard !points[index].consumed else { return }
        let point = points[index]
        if point.id.hasPrefix("exit") {
            if !attentionAllowsExit() {
                exitWaiting = true
                return
            }
            points[index].consumed = true
            finishExit()
            return
        }
        if point.id.hasPrefix("required") {
            points[index].consumed = true
            requiredDone = true
            if !points.contains(where: { $0.id.hasPrefix("exit") }) {
                points.append(EncounterController.exitPoint(encounterNumber: encounterIndex + 1))
            }
            return
        }
        if point.type == .memory, let memoryID = point.memoryID {
            points[index].consumed = true
            audio.playSFX("sfx_memory_found")
            haptics.memoryFound()
            if case .endless = mode {
                endlessMemories += 1
            } else {
                if !chapterMemoryFinds.contains(memoryID) { chapterMemoryFinds.append(memoryID) }
                save.unlockMemory(memoryID)
                save.writeSuspended(snapshot())
            }
            return
        }
        if point.type == .trail {
            points[index].consumed = true
            for wolfIndex in wolves.indices {
                wolves[wolfIndex].trust += 5
                wolves[wolfIndex].clamp()
            }
            attention = max(0, attention - 5)
            audio.playSFX("sfx_trust_restore")
            return
        }
        points[index].consumed = true
        harm(at: pointPosition(point), kind: point.hazardKind)
    }

    private func harm(at position: CGPoint, kind: String) {
        for index in wolves.indices where distance(wolves[index].position, position) <= 240 {
            var anxiety = wolves[index].anxiety
            var shield = wolves[index].shield
            EmotionController.applyHazard(anxiety: &anxiety, shield: &shield, amount: 14 * hazardScale)
            wolves[index].anxiety = anxiety
            wolves[index].shield = shield
            wolves[index].clamp()
        }
        hazardEvent = 3
        audio.playSFX("sfx_anxiety_rise")
        switch kind {
        case "ravens": audio.playPositional("sfx_ravens_takeoff", pan: audio.pan(for: position.x, width: sceneSize.width))
        case "rival":
            audio.playPositional("sfx_rival_howl", pan: audio.pan(for: position.x, width: sceneSize.width))
            requestShake()
        case "bear": audio.playPositional("sfx_bear_approach", pan: audio.pan(for: position.x, width: sceneSize.width))
        case "fire":
            audio.playSFX("sfx_fire_burst")
            requestShake()
        case "ice":
            audio.playSFX("sfx_ice_break")
            requestShake()
        case "deer": audio.playPositional("sfx_deer_move", pan: audio.pan(for: position.x, width: sceneSize.width))
        case "lantern": audio.playSFX("sfx_threat_trigger")
        default: audio.playSFX("sfx_threat_trigger")
        }
    }

    private func triggerIce() {
        guard iceFrozen <= 0 else { return }
        if let ice = points.first(where: { $0.hazardKind == "ice" && !$0.consumed }) {
            harm(at: pointPosition(ice), kind: "ice")
        }
    }

    private func finishExit() {
        exitWaiting = false
        let isFinal: Bool
        if case .campaign = mode, let chapter {
            isFinal = encounterIndex >= chapter.encounters.count - 1
        } else {
            isFinal = false
        }
        if isFinal {
            completeCampaign()
        } else {
            fadePhase = .out
        }
    }

    private func stepFade(_ dt: Double) {
        switch fadePhase {
        case .out:
            fade = min(1, fade + dt / 0.35)
            if fade >= 1 {
                advance()
                fadePhase = .inn
            }
        case .inn:
            fade = max(0, fade - dt / 0.35)
            if fade <= 0 {
                fade = 0
                fadePhase = .none
            }
        case .none:
            break
        }
    }

    private func advance() {
        if case .endless = mode {
            endlessClears += 1
            prepareEndlessEncounter(freshStats: false)
            return
        }
        guard let chapter else { return }
        encounterIndex += 1
        if encounterIndex >= chapter.encounters.count {
            completeCampaign()
            return
        }
        prepareEncounter(chapter.encounters[encounterIndex], number: encounterIndex + 1, freshStats: false)
        storeBaseline()
        save.writeSuspended(snapshot())
    }

    private func completeCampaign() {
        guard !finished, let chapter else { return }
        finished = true
        let together = wolves.allSatisfy { $0.trust >= 50 }
        var intact = together
        if let limit = chapter.strongHowlLimit, strongHowlCount > limit { intact = false }
        let total = chapter.encounters.contains { $0.memoryID != nil } ? 1 : 0
        let result = ChapterResultData(
            packStayedTogether: intact,
            memoriesFound: min(total, chapterMemoryFinds.count),
            memoriesTotal: total,
            forestAttention: AttentionBand.name(for: attention)
        )
        save.completeChapter(chapter.id, result: result)
        audio.playSFX("sfx_ui_success")
        haptics.memoryFound()
        onCampaignResult?(GameResult(chapterID: chapter.id, result: result))
    }

    private func scatter() {
        if case .endless = mode {
            guard !finished else { return }
            finished = true
            let distance = endlessClears * 100
            let isNew = save.recordEndless(difficulty: endlessDifficulty, distance: distance)
            let best = save.data.endlessBestMeters[endlessDifficulty] ?? distance
            audio.playSFX("sfx_ui_failure")
            haptics.chapterFailure()
            onEndlessResult?(EndlessResult(
                distanceMeters: distance,
                encountersSurvived: endlessClears,
                memoriesCollected: endlessMemories,
                bestMeters: best,
                isNewBest: isNew,
                difficulty: endlessDifficulty,
                wolfIDs: endlessWolves
            ))
            return
        }
        guard !failed else { return }
        failed = true
        paused = true
        audio.playSFX("sfx_ui_failure")
        haptics.chapterFailure()
        publish()
    }

    private func attentionAllowsExit() -> Bool {
        guard let limit = chapter?.attentionLimit else { return true }
        guard let chapter, encounterIndex >= chapter.encounters.count - 1 else { return true }
        return attention < limit
    }

    private func revealDuration(type: EchoType, howler: WolfDefinition) -> Double {
        if howler.echo == "frozen" { return 14 }
        if type == .trail { return chapter?.trailRevealSeconds ?? 6 }
        return 6
    }

    private func onReveal(_ index: Int) {
        let point = points[index]
        let pos = pointPosition(point)
        let pitch = Float.random(in: -0.05...0.05)
        audio.playPositional("sfx_echo_reveal", pan: audio.pan(for: pos.x, width: sceneSize.width), pitch: pitch)
        if chapter?.special == "rivalDecoys", !point.requiredLane {
            audio.playPositional("sfx_rival_howl", pan: audio.pan(for: pos.x, width: sceneSize.width))
        }
        if point.hazardKind == "rival" {
            requestShake()
        }
    }

    private func pulseAnxiety(_ amount: Double) {
        for index in wolves.indices {
            var anxiety = wolves[index].anxiety
            var shield = wolves[index].shield
            EmotionController.applyHazard(anxiety: &anxiety, shield: &shield, amount: amount)
            wolves[index].anxiety = anxiety
            wolves[index].shield = shield
            wolves[index].clamp()
        }
    }

    private func pointPosition(_ point: EchoPoint) -> CGPoint {
        let base = point.node.scenePoint(in: playable)
        return CGPoint(x: base.x + point.offset.x, y: base.y + point.offset.y)
    }

    private func nearestRequiredPosition() -> CGPoint? {
        if let exit = points.first(where: { $0.id.hasPrefix("exit") && !$0.consumed }) {
            return pointPosition(exit)
        }
        if let required = points.first(where: { $0.id.hasPrefix("required") && !$0.consumed }) {
            return pointPosition(required)
        }
        return nil
    }

    private func nearestThreatPosition() -> CGPoint? {
        points.filter { $0.type == .threat && !$0.consumed }.map { pointPosition($0) }.min { lhs, rhs in
            distance(lhs, leaderPosition()) < distance(rhs, leaderPosition())
        }
    }

    private func applyFormation(repositionIdle: Bool) {
        let count = wolves.count
        guard count > 1 else { return }
        for index in wolves.indices {
            let x = (CGFloat(index) - CGFloat(count - 1) / 2) * 28
            wolves[index].formX = x
            if repositionIdle, wolves[index].path.isEmpty {
                let base = wolves[index].node.scenePoint(in: playable)
                wolves[index].position = CGPoint(x: base.x + x, y: base.y)
            }
        }
    }

    private func leaderPosition() -> CGPoint {
        wolves.first { $0.id == leaderID }?.position ?? playableCenter
    }

    private var playableCenter: CGPoint {
        CGPoint(x: playable.midX, y: playable.midY)
    }

    private func alternatePoint(excluding id: String, near position: CGPoint) -> EchoPoint? {
        points.filter { $0.id != id && $0.isVisible }.min { distance(pointPosition($0), position) < distance(pointPosition($1), position) }
    }

    private func obstacle(for definition: EncounterDefinition, chapterID: Int) -> CGPoint? {
        guard chapterID >= 2, let node = NodeID(rawValue: definition.hazard) else { return nil }
        let hazard = node.scenePoint(in: playable)
        let start = NodeID.P0.scenePoint(in: playable)
        let dx = start.x - hazard.x
        let dy = start.y - hazard.y
        let len = max(1, hypot(dx, dy))
        return CGPoint(x: hazard.x + dx / len * 78, y: hazard.y + dy / len * 78)
    }

    private func weatherName(for chapterID: Int?) -> String {
        switch chapterID {
        case 2: return "rain"
        case 5: return "sparks"
        case 6, 11: return "snow"
        default: return ""
        }
    }

    private var tutorialFreezes: Bool {
        switch tutorial {
        case .select, .aim, .charge, .target, .morHowl, .lumiHowl: return true
        default: return false
        }
    }

    private func registerQuickTap(_ point: CGPoint) {
        let now = Date().timeIntervalSinceReferenceDate
        if let lastQuick, now - lastQuick.time < 0.35, distance(point, lastQuick.point) < 48 {
            self.lastQuick = nil
            recall()
        } else {
            lastQuick = (now, point)
        }
    }

    var simulationRunning: Bool {
        laidOut && !paused && !failed && fadePhase == .none && !tutorialFreezes && resumeLeft == nil && !finished
    }

    private func decayReveals(_ dt: Double) {
        for index in points.indices where points[index].revealed && !points[index].remembered && !points[index].consumed && !points[index].id.hasPrefix("exit") {
            points[index].revealRemaining -= dt
            if points[index].revealRemaining <= 0 {
                points[index].revealed = false
                points[index].revealRemaining = 0
            }
        }
    }

    private func deny() {
        audio.playSFX("sfx_ui_locked")
        haptics.locked()
    }

    private func chance(_ probability: Double) -> Bool {
        Double.random(in: 0..<1, using: &rng) < probability
    }

    private func requestShake() {
        guard !reduceMotion else { return }
        shakeUntil = Date().timeIntervalSinceReferenceDate + 0.25
    }

    private func storeBaseline() {
        baseline = EncounterBaseline(
            wolves: wolves.map { $0.snapshot(playable: playable) },
            attention: attention,
            countdownRemaining: countdown,
            strongHowlCount: strongHowlCount,
            collectedMemoryIDs: save.data.unlockedMemoryIDs,
            chapterMemoryFinds: chapterMemoryFinds,
            tutorialDone: tutorialDone
        )
    }

    private func restoreBaseline() {
        attention = baseline.attention
        countdown = baseline.countdownRemaining
        strongHowlCount = baseline.strongHowlCount
        chapterMemoryFinds = baseline.chapterMemoryFinds
        tutorialDone = baseline.tutorialDone
        tutorial = nil
        requiredDone = false
        exitWaiting = false
        fade = 0
        fadePhase = .none
        aim.active = false
        if let chapter {
            prepareEncounter(chapter.encounters[min(encounterIndex, chapter.encounters.count - 1)], number: encounterIndex + 1, freshStats: true)
            wolves = baseline.wolves.compactMap { snap in
                guard let node = NodeID(rawValue: snap.node) else { return nil }
                var wolf = PackController.makeWolf(id: snap.id, trust: snap.trust, anxiety: snap.anxiety, node: node, playable: playable)
                wolf.position = node.scenePoint(in: playable)
                return wolf
            }
            if chapter.special == "tutorial", encounterIndex == 0, !tutorialDone {
                tutorial = .select
                selectedID = nil
            }
            applyFormation(repositionIdle: true)
        }
        storeBaseline()
        save.writeSuspended(snapshot())
    }

    private func restore(_ suspended: SuspendedCampaignData) {
        guard let chapter else { return }
        self.chapter = chapter
        encounterIndex = suspended.encounterIndex
        attention = suspended.attention
        countdown = suspended.countdownRemaining
        strongHowlCount = suspended.strongHowlCount
        chapterMemoryFinds = suspended.chapterMemoryFinds
        tutorialDone = suspended.tutorialDone
        requiredDone = suspended.requiredDone
        exitWaiting = false
        iceArm = suspended.iceArm
        iceFrozen = suspended.iceFrozen
        decoyLeft = suspended.decoyRemaining
        panickedTogether = suspended.panickedTogether
        noTargetTime = suspended.noTargetTime
        pulseTime = suspended.anxietyPulseTime
        panIndex = suspended.backgroundPan
        points = suspended.points.compactMap(EchoPoint.from)
        wolves = suspended.wolves.compactMap { snap in
            guard let node = NodeID(rawValue: snap.node) else { return nil }
            var wolf = PackController.makeWolf(id: snap.id, trust: snap.trust, anxiety: snap.anxiety, node: node, playable: playable)
            wolf.position = CGPoint(x: playable.minX + snap.normX * playable.width, y: playable.maxY - snap.normY * playable.height)
            return wolf
        }
        leaderID = chapter.leaderID
        if !wolves.contains(where: { $0.id == leaderID }) {
            leaderID = wolves.first?.id ?? chapter.leaderID
        }
        if encounterIndex < chapter.encounters.count {
            let definition = chapter.encounters[encounterIndex]
            encounterDef = definition
            obstaclePoint = obstacle(for: definition, chapterID: chapter.id)
        }
        selectedID = leaderID
        applyFormation(repositionIdle: true)
        backgroundName = chapter.background
        weather = weatherName(for: chapter.id)
        if decoyLeft > 0 {
            decoyPoint = CGPoint(x: playable.minX + suspended.decoyNormX * playable.width, y: playable.maxY - suspended.decoyNormY * playable.height)
        }
        baseline = suspended.baseline
        if !tutorialDone, chapter.special == "tutorial", encounterIndex == 0 {
            tutorial = .select
            selectedID = nil
        }
        audio.playAmbient(chapter.ambient)
    }

    private func snapshot() -> SuspendedCampaignData {
        let decoyNormX = decoyPoint.map { playable.width > 0 ? ($0.x - playable.minX) / playable.width : 0.5 } ?? 0.5
        let decoyNormY = decoyPoint.map { playable.height > 0 ? (playable.maxY - $0.y) / playable.height : 0.5 } ?? 0.5
        return SuspendedCampaignData(
            chapterID: chapter?.id ?? 1,
            encounterIndex: encounterIndex,
            wolves: wolves.map { $0.snapshot(playable: playable) },
            attention: attention,
            collectedMemoryIDs: save.data.unlockedMemoryIDs,
            countdownRemaining: countdown,
            strongHowlCount: strongHowlCount,
            points: points.map { $0.snapshot() },
            requiredDone: requiredDone,
            exitSpawned: points.contains { $0.id.hasPrefix("exit") },
            noTargetTime: noTargetTime,
            anxietyPulseTime: pulseTime,
            iceArm: iceArm,
            iceFrozen: iceFrozen,
            decoyRemaining: decoyLeft,
            decoyNormX: decoyNormX,
            decoyNormY: decoyNormY,
            panickedTogether: panickedTogether,
            tutorialDone: tutorialDone || tutorial == nil,
            chapterMemoryFinds: chapterMemoryFinds,
            baseline: baseline,
            backgroundPan: panIndex
        )
    }

    private func publishMaybe(_ dt: Double) {
        hudClock += dt
        if hudClock >= 0.1 {
            hudClock = 0
            publish()
        }
    }

    private func publish() {
        let selected = wolves.first { $0.id == selectedID }
        let definition = selected.flatMap { ContentCatalog.wolf($0.id) }
        hud = HUDModel(
            objective: chapter?.objective ?? "Travel as far as possible before the pack scatters.",
            attention: attention,
            portraits: wolves.map { wolf in
                let def = ContentCatalog.wolf(wolf.id)
                let stressed = wolf.anxiety >= 60
                return PortraitHUD(
                    id: wolf.id,
                    name: def?.name ?? wolf.id,
                    image: stressed ? (def?.portraitStressed ?? "") : (def?.portraitCalm ?? ""),
                    trust: wolf.trust,
                    anxiety: wolf.anxiety,
                    selected: wolf.id == selectedID,
                    recallRemaining: wolf.id == leaderID ? wolf.recallCooldown / 8 : 0,
                    colorHex: def?.colorHex ?? "74E7FF"
                )
            },
            selectedHowl: definition?.howlLabel,
            hint: (assistShimmer || noTargetTime >= 15) ? "Try a stronger echo in the highlighted direction." : nil,
            tutorial: tutorialText,
            showSkip: showSkipTutorial && isFirstCue,
            paused: paused && resumeLeft == nil && !failed,
            resumeNumber: resumeLeft.map { max(1, Int(ceil($0))) },
            failed: failed,
            fade: fade,
            countdownText: countdown.map { formatTime($0) },
            strongHowlText: chapter?.strongHowlLimit.map { "\(strongHowlCount)/\($0)" },
            accessibility: accessText(selected: selected, definition: definition),
            chapterTitle: chapter?.title ?? "Endless Night"
        )
    }

    private var isFirstCue: Bool {
        switch tutorial {
        case .select, .morHowl, .lumiHowl: return true
        default: return false
        }
    }

    private var tutorialText: String? {
        switch tutorial {
        case .select: return "Tap a portrait to select that wolf."
        case .aim: return "Touch and hold anywhere in the playable area, excluding HUD, to begin aiming."
        case .charge: return assistShimmer ? "Try a stronger echo in the highlighted direction." : "Release from 0.25–0.69 seconds for a soft howl, 0.70–1.09 for a medium howl, and 1.10 seconds or longer for a strong howl."
        case .target: return "Tap a revealed Echo Point to set it as the pack target."
        case .recall: return "Double-tap empty ground to recall the pack toward the leader."
        case .morHowl: return "A false howl pulls danger away from the pack."
        case .lumiHowl: return "Her echo refuses to fade."
        case nil: return nil
        }
    }

    private func accessText(selected: PackWolf?, definition: WolfDefinition?) -> String {
        let name = definition?.name ?? "No wolf"
        let trust = (selected?.trust ?? 0) >= 50 ? "Trust steady" : "Trust independent"
        let anxiety = (selected?.anxiety ?? 0) >= 60 ? "Anxiety guarded" : "Anxiety steady"
        let remembered = points.filter { $0.remembered && !$0.consumed }.map { $0.type.spoken }
        let memoryText = remembered.isEmpty ? "no remembered targets" : "remembered " + remembered.joined(separator: ", ")
        return "\(name), \(trust), \(anxiety), Forest \(AttentionBand.name(for: attention)), \(memoryText)"
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private static func tuning(_ name: String) -> (trust: Double, anxiety: Double, decay: Double, multiplier: Double) {
        switch name {
        case "calm": return (80, 15, 3, 0.75)
        case "relentless": return (60, 35, 1, 1.3)
        default: return (70, 25, 2, 1)
        }
    }
}

