import SpriteKit
import UIKit

final class ForestScene: SKScene {
    let session: GameSession
    private let world = SKNode()
    private let background = SKSpriteNode()
    private let fogA = SKSpriteNode()
    private let fogB = SKSpriteNode()
    private let vignette = SKSpriteNode()
    private var weatherNode: SKEmitterNode?
    private var weatherKind = ""
    private let wolvesNode = SKNode()
    private let pointsNode = SKNode()
    private let echoNode = SKNode()
    private let routeLine = SKShapeNode()
    private let aimLine = SKShapeNode()
    private let chargeRing = SKShapeNode()
    private let shimmer = SKShapeNode()
    private let decoy = SKSpriteNode(texture: ArtTexture.named("obj_echo_marker"))
    private let obstacle = SKSpriteNode(texture: ArtTexture.named("obj_fallen_trunk"))
    private var wolfNodes: [String: WolfNode] = [:]
    private var pointNodes: [String: SKNode] = [:]
    private var lastTime: TimeInterval = 0
    private var lastSafeTop: CGFloat = 59
    private var lastSafeBottom: CGFloat = 34

    init(session: GameSession) {
        self.session = session
        super.init(size: CGSize(width: 393, height: 852))
        scaleMode = .resizeFill
        backgroundColor = ArtTexture.uiColor("071126")
        anchorPoint = .zero
    }

    required init?(coder aDecoder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        if world.parent == nil {
            addChild(world)
            background.zPosition = 0
            world.addChild(background)
            fogA.texture = ArtTexture.noise
            fogB.texture = ArtTexture.noise
            fogA.alpha = 0.16
            fogB.alpha = 0.1
            fogA.zPosition = 8
            fogB.zPosition = 9
            world.addChild(fogA)
            world.addChild(fogB)
            vignette.texture = ArtTexture.vignette
            vignette.zPosition = 40
            vignette.alpha = 0.45
            addChild(vignette)
            wolvesNode.zPosition = 20
            pointsNode.zPosition = 15
            echoNode.zPosition = 18
            world.addChild(pointsNode)
            world.addChild(echoNode)
            world.addChild(wolvesNode)
            routeLine.strokeColor = ArtTexture.uiColor("74E7FF")
            routeLine.lineWidth = 2
            routeLine.alpha = 0.7
            routeLine.zPosition = 12
            world.addChild(routeLine)
            aimLine.lineWidth = 2
            aimLine.zPosition = 30
            world.addChild(aimLine)
            chargeRing.lineWidth = 3
            chargeRing.strokeColor = ArtTexture.uiColor("74E7FF")
            chargeRing.fillColor = .clear
            chargeRing.zPosition = 31
            world.addChild(chargeRing)
            shimmer.strokeColor = ArtTexture.uiColor("EAF8FF")
            shimmer.lineWidth = 2
            shimmer.alpha = 0.28
            shimmer.zPosition = 13
            world.addChild(shimmer)
            decoy.size = CGSize(width: 36, height: 36)
            decoy.alpha = 0
            decoy.zPosition = 16
            world.addChild(decoy)
            obstacle.size = CGSize(width: 120, height: 48)
            obstacle.alpha = 0
            obstacle.zPosition = 14
            world.addChild(obstacle)
        }
        layoutStatic()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layoutStatic()
        session.updateLayout(sceneSize: size, safeTop: view?.safeAreaInsets.top ?? lastSafeTop, safeBottom: view?.safeAreaInsets.bottom ?? lastSafeBottom)
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : min(0.05, currentTime - lastTime)
        lastTime = currentTime
        let safeTop = view?.safeAreaInsets.top ?? lastSafeTop
        let safeBottom = view?.safeAreaInsets.bottom ?? lastSafeBottom
        if safeTop != lastSafeTop || safeBottom != lastSafeBottom {
            lastSafeTop = safeTop
            lastSafeBottom = safeBottom
            session.updateLayout(sceneSize: size, safeTop: safeTop, safeBottom: safeBottom)
        }
        session.tick(dt)
        if currentTime < session.shakeUntil {
            world.position = CGPoint(x: .random(in: -4...4), y: .random(in: -4...4))
        } else {
            world.position = .zero
        }
        syncBackground()
        fogA.position.x += CGFloat(dt) * 8
        fogB.position.x -= CGFloat(dt) * 5
        wrap(fogA)
        wrap(fogB)
        syncWeather()
        syncPoints()
        syncWolves(time: currentTime)
        syncEchoes()
        syncAim()
        syncRoute()
        syncShimmer(time: currentTime)
        if let decoyPoint = session.decoyPoint {
            decoy.position = decoyPoint
            decoy.alpha = 0.85
            decoy.color = ArtTexture.uiColor("7DDBB5")
            decoy.colorBlendFactor = 0.8
        } else {
            decoy.alpha = 0
        }
        if let obstaclePoint = session.obstaclePoint {
            obstacle.position = obstaclePoint
            obstacle.alpha = 0.9
        } else {
            obstacle.alpha = 0
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        session.touchBegan(at: location, echoID: echoHit(location))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        session.touchMoved(to: touch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        session.touchEnded(at: touch.location(in: self))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        session.touchEnded(at: touch.location(in: self))
    }

    private func layoutStatic() {
        let cover = max(size.width / 1290, size.height / 2796) * 1.08
        background.size = CGSize(width: 1290 * cover, height: 2796 * cover)
        fogA.size = CGSize(width: size.width * 2.2, height: size.height * 1.4)
        fogB.size = fogA.size
        vignette.size = size
        vignette.position = CGPoint(x: size.width / 2, y: size.height / 2)
        fogA.position = CGPoint(x: size.width / 2, y: size.height / 2)
        fogB.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private func syncBackground() {
        if background.texture == nil || background.name != session.backgroundName {
            background.texture = ArtTexture.named(session.backgroundName)
            background.name = session.backgroundName
        }
        let pans: [CGFloat] = [-0.04, 0, 0.04]
        let pan = pans[session.panIndex % 3] * size.width
        let parallax: CGFloat
        if session.reduceMotion || !session.aim.active {
            parallax = 0
        } else {
            parallax = (session.aim.finger.x - size.width / 2) / max(1, size.width) * 8
        }
        background.position = CGPoint(x: size.width / 2 + pan + parallax, y: size.height / 2)
    }

    private func syncWeather() {
        if weatherKind == session.weather { return }
        weatherKind = session.weather
        weatherNode?.removeFromParent()
        weatherNode = nil
        guard !weatherKind.isEmpty else { return }
        let emitter = SKEmitterNode()
        emitter.particleTexture = ArtTexture.softCircle
        emitter.particleLifetime = 3
        emitter.particleBirthRate = weatherKind == "sparks" ? 18 : 36
        emitter.particleSpeed = weatherKind == "snow" ? 40 : (weatherKind == "sparks" ? 70 : 180)
        emitter.particleSpeedRange = 20
        emitter.emissionAngle = weatherKind == "sparks" ? .pi / 2 : -.pi / 2
        emitter.emissionAngleRange = 0.2
        emitter.particleAlpha = weatherKind == "sparks" ? 0.8 : 0.35
        emitter.particleAlphaSpeed = -0.15
        emitter.particleScale = weatherKind == "snow" ? 0.18 : 0.08
        emitter.particleScaleRange = 0.05
        emitter.particleColor = weatherKind == "sparks" ? ArtTexture.uiColor("F5B83D") : .white
        emitter.particleColorBlendFactor = 1
        emitter.position = CGPoint(x: size.width / 2, y: size.height + 10)
        emitter.particlePositionRange = CGVector(dx: size.width, dy: 0)
        emitter.zPosition = 35
        emitter.advanceSimulationTime(2)
        addChild(emitter)
        weatherNode = emitter
    }

    private func syncWolves(time: TimeInterval) {
        let ids = Set(session.wolves.map { $0.id })
        for (id, node) in wolfNodes where !ids.contains(id) {
            node.removeFromParent()
            wolfNodes[id] = nil
        }
        for wolf in session.wolves {
            let node = wolfNodes[wolf.id] ?? {
                let created = WolfNode(id: wolf.id)
                wolvesNode.addChild(created)
                wolfNodes[wolf.id] = created
                return created
            }()
            let movingRight: Bool?
            if let next = wolf.path.first {
                movingRight = next.scenePoint(in: session.playable).x >= wolf.position.x
            } else {
                movingRight = nil
            }
            node.sync(
                wolf: wolf,
                movingRight: movingRight,
                moving: session.simulationRunning && !wolf.path.isEmpty,
                reduceMotion: session.reduceMotion,
                time: time
            )
            node.zPosition = 1000 - wolf.position.y
        }
    }

    private func syncPoints() {
        let visibleIDs = Set(session.points.filter { !$0.consumed }.map { $0.id })
        for (id, node) in pointNodes where !visibleIDs.contains(id) {
            node.removeFromParent()
            pointNodes[id] = nil
        }
        for point in session.points where !point.consumed {
            let node = pointNodes[point.id] ?? makePointNode(point)
            let base = point.node.scenePoint(in: session.playable)
            node.position = CGPoint(x: base.x + point.offset.x, y: base.y + point.offset.y)
            let show = point.isVisible
            node.alpha = show ? (point.remembered && point.revealRemaining <= 0 ? 0.55 : 1) : 0
            if let marker = node.childNode(withName: "marker") as? SKSpriteNode {
                marker.alpha = 1
            }
            node.childNode(withName: "glyph")?.isHidden = !session.highContrast
        }
    }

    private func makePointNode(_ point: EchoPoint) -> SKNode {
        let root = SKNode()
        root.name = point.id
        let marker = SKSpriteNode(texture: ArtTexture.named("obj_echo_marker"))
        marker.name = "marker"
        marker.size = CGSize(width: 44, height: 44)
        marker.color = ArtTexture.uiColor(point.type.tintHex)
        marker.colorBlendFactor = 0.85
        root.addChild(marker)
        if let sprite = EncounterController.spriteName(kind: point.hazardKind), point.type == .threat || point.type == .hazard || point.type == .prey {
            let art = SKSpriteNode(texture: ArtTexture.named(sprite))
            art.size = CGSize(width: 78, height: 78)
            art.zPosition = -1
            art.alpha = 0.95
            root.addChild(art)
        }
        if point.type == .memory {
            let wisp = SKSpriteNode(texture: ArtTexture.named("obj_memory_wisp"))
            wisp.size = CGSize(width: 48, height: 48)
            wisp.zPosition = 1
            root.addChild(wisp)
        }
        let glyph = shape(for: point.type)
        glyph.name = "glyph"
        glyph.strokeColor = ArtTexture.uiColor("EAF8FF")
        glyph.fillColor = .clear
        glyph.lineWidth = 1.5
        glyph.isHidden = true
        glyph.zPosition = 2
        root.addChild(glyph)
        root.alpha = 0
        root.run(.fadeIn(withDuration: 0.18))
        pointsNode.addChild(root)
        pointNodes[point.id] = root
        return root
    }

    private func shape(for type: EchoType) -> SKShapeNode {
        switch type {
        case .trail:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -12, y: 0))
            path.addLine(to: CGPoint(x: 12, y: 0))
            return SKShapeNode(path: path)
        case .objective:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 12))
            path.addLine(to: CGPoint(x: 8, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -12))
            path.addLine(to: CGPoint(x: -8, y: 0))
            path.closeSubpath()
            return SKShapeNode(path: path)
        case .prey:
            return SKShapeNode(ellipseOf: CGSize(width: 16, height: 10))
        case .threat:
            let path = CGMutablePath()
            path.addArc(center: .zero, radius: 10, startAngle: 0.4, endAngle: .pi * 1.7, clockwise: false)
            return SKShapeNode(path: path)
        case .hazard:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 12))
            path.addLine(to: CGPoint(x: 11, y: -8))
            path.addLine(to: CGPoint(x: -11, y: -8))
            path.closeSubpath()
            return SKShapeNode(path: path)
        case .memory:
            return SKShapeNode(path: starPath(radius: 10))
        case .secret:
            let path = CGMutablePath()
            path.addArc(center: CGPoint(x: -2, y: 0), radius: 8, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
            return SKShapeNode(path: path)
        }
    }

    private func starPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for index in 0..<10 {
            let angle = CGFloat(index) * .pi / 5 - .pi / 2
            let length = index.isMultiple(of: 2) ? radius : radius * 0.45
            let point = CGPoint(x: cos(angle) * length, y: sin(angle) * length)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    private func syncEchoes() {
        echoNode.removeAllChildren()
        for burst in session.echoes {
            let crop = SKCropNode()
            crop.position = burst.origin
            let mask = SKShapeNode(path: wedge(burst))
            mask.fillColor = .white
            mask.strokeColor = .clear
            crop.maskNode = mask
            let progress = min(1, burst.age / 0.8)
            let fade = burst.age < 0.8 ? 1 : max(0, 1 - (burst.age - 0.8) / 0.3)
            let color = ArtTexture.uiColor(burst.colorHex)
            for scale in [0.55, 0.78, 1.0] as [CGFloat] {
                let ring = SKShapeNode(circleOfRadius: max(8, burst.range * scale * progress))
                ring.strokeColor = color
                ring.fillColor = .clear
                ring.lineWidth = 3
                ring.alpha = fade
                ring.blendMode = .add
                crop.addChild(ring)
            }
            echoNode.addChild(crop)
        }
    }

    private func wedge(_ burst: EchoBurst) -> CGPath {
        let path = CGMutablePath()
        if burst.fullCircle {
            path.addEllipse(in: CGRect(x: -burst.range, y: -burst.range, width: burst.range * 2, height: burst.range * 2))
            return path
        }
        let aim = atan2(burst.direction.dy, burst.direction.dx)
        let half = burst.halfAngle * .pi / 180
        path.move(to: .zero)
        path.addArc(center: .zero, radius: burst.range, startAngle: aim - half, endAngle: aim + half, clockwise: false)
        path.closeSubpath()
        return path
    }

    private func syncAim() {
        guard session.aim.active else {
            aimLine.path = nil
            chargeRing.path = nil
            return
        }
        let path = CGMutablePath()
        path.move(to: session.aim.origin)
        path.addLine(to: session.aim.finger)
        aimLine.path = path
        if let id = session.hud.portraits.first(where: { $0.selected })?.colorHex {
            aimLine.strokeColor = ArtTexture.uiColor(id)
        }
        let fraction = session.aim.charge / 1.2
        let radius: CGFloat = 22
        let arc = CGMutablePath()
        arc.addArc(center: session.aim.finger, radius: radius, startAngle: -.pi / 2, endAngle: -.pi / 2 + fraction * .pi * 2, clockwise: false)
        chargeRing.path = arc
    }

    private func syncRoute() {
        guard session.leaderPath.count > 1 else {
            routeLine.path = nil
            return
        }
        let path = CGMutablePath()
        path.move(to: session.leaderPath[0])
        for point in session.leaderPath.dropFirst() { path.addLine(to: point) }
        routeLine.path = path
    }

    private func syncShimmer(time: TimeInterval) {
        guard let target = session.shimmerPoint, let leader = session.wolves.first(where: { $0.id == session.leaderID }) else {
            shimmer.path = nil
            return
        }
        let path = CGMutablePath()
        path.move(to: leader.position)
        path.addLine(to: target)
        shimmer.path = path
        shimmer.alpha = 0.18 + 0.12 * abs(sin(CGFloat(time) * 3))
    }

    private func echoHit(_ location: CGPoint) -> String? {
        var best: (String, CGFloat)?
        for point in session.points where point.isVisible {
            let base = point.node.scenePoint(in: session.playable)
            let position = CGPoint(x: base.x + point.offset.x, y: base.y + point.offset.y)
            let dist = hypot(location.x - position.x, location.y - position.y)
            if dist <= 28, best == nil || dist < best!.1 {
                best = (point.id, dist)
            }
        }
        return best?.0
    }

    private func wrap(_ node: SKSpriteNode) {
        if node.position.x > size.width * 1.5 { node.position.x = size.width / 2 }
        if node.position.x < -size.width * 0.5 { node.position.x = size.width / 2 }
    }
}
