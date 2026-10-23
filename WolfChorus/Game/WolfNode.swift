import SpriteKit
import UIKit

final class WolfNode: SKNode {
    let wolfID: String
    private let shadow = SKShapeNode(ellipseOf: CGSize(width: 54, height: 16))
    private let idle = SKSpriteNode()
    private let howling = SKSpriteNode()
    private let eyes = SKNode()
    private let facesLeft: Bool
    private var movingRight = true
    private var howlShown = false

    init(id: String) {
        wolfID = id
        let definition = ContentCatalog.wolf(id)
        facesLeft = definition?.facesLeft ?? false
        movingRight = !facesLeft
        super.init()
        shadow.fillColor = UIColor.black.withAlphaComponent(0.35)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -42)
        addChild(shadow)
        idle.size = CGSize(width: 96, height: 96)
        howling.size = idle.size
        howling.alpha = 0
        addChild(idle)
        addChild(howling)
        if let definition {
            idle.texture = ArtTexture.named(definition.bodyIdle)
            howling.texture = ArtTexture.named(definition.bodyHowl)
            let color = ArtTexture.uiColor(definition.colorHex)
            for offset in [CGPoint(x: 8, y: 16), CGPoint(x: 20, y: 16)] {
                let glow = SKShapeNode(circleOfRadius: 3.5)
                glow.fillColor = color
                glow.strokeColor = .clear
                glow.blendMode = .add
                glow.position = offset
                eyes.addChild(glow)
            }
        }
        addChild(eyes)
    }

    required init?(coder aDecoder: NSCoder) { nil }

    func sync(wolf: PackWolf, movingRight: Bool?, moving: Bool, reduceMotion: Bool, time: TimeInterval) {
        if let movingRight { self.movingRight = movingRight }
        position = wolf.position
        zRotation = 0
        idle.setScale(1)
        howling.setScale(1)
        if wolf.howlLeft > 0 {
            if !howlShown {
                howlShown = true
                howling.run(.fadeAlpha(to: 1, duration: 0.12))
                idle.run(.fadeAlpha(to: 0, duration: 0.12))
            }
            let tilt: CGFloat = 3 * .pi / 180
            zRotation = movingRightOrDefault ? -tilt : tilt
        } else if howlShown {
            howlShown = false
            howling.run(.fadeAlpha(to: 0, duration: 0.12))
            idle.run(.fadeAlpha(to: 1, duration: 0.12))
        }
        if wolf.state == .panicked {
            let amp: CGFloat = reduceMotion ? 1 : 5
            position.x += sin(CGFloat(time) * 4 * .pi * 2) * amp
        } else if moving {
            let bob = sin(CGFloat(time) * 2.5 * .pi * 2)
            position.y += bob * 2
            zRotation += bob * 1.5 * .pi / 180
        } else {
            let wave = sin(CGFloat(time) / 2.4 * .pi * 2)
            position.y += wave * 2
            if !reduceMotion {
                let scale = 1 + wave * 0.006
                idle.yScale = scale
                howling.yScale = scale
            }
        }
        eyes.alpha = reduceMotion ? 0.85 : 0.7 + 0.3 * (0.5 + 0.5 * sin(CGFloat(time) / 1.8 * .pi * 2))
        applyFacing()
    }

    private var movingRightOrDefault: Bool { movingRight }

    private func applyFacing() {
        if facesLeft {
            xScale = movingRight ? -1 : 1
        } else {
            xScale = movingRight ? 1 : -1
        }
    }
}

enum ArtTexture {
    static func named(_ name: String) -> SKTexture {
        if let image = UIImage(named: name) {
            return SKTexture(image: image)
        }
        print("\(name).png")
        #if DEBUG
        assertionFailure("Missing PNG \(name).png")
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        let image = renderer.image { context in
            UIColor(red: 6 / 255, green: 11 / 255, blue: 20 / 255, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        return SKTexture(image: image)
        #else
        return SKTexture()
        #endif
    }

    static func uiColor(_ hex: String) -> UIColor {
        let value = UInt32(hex, radix: 16) ?? 0x74E7FF
        return UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    static let softCircle: SKTexture = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        let image = renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 16, height: 16)).fill()
        }
        return SKTexture(image: image)
    }()

    static let noise: SKTexture = {
        let size = 128
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            for y in 0..<size {
                for x in 0..<size {
                    let shade = CGFloat.random(in: 0.55...1)
                    UIColor(white: 1, alpha: shade * 0.45).setFill()
                    context.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }()

    static let vignette: SKTexture = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        let image = renderer.image { context in
            let colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.55).cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0.45, 1])!
            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: 32, y: 32),
                startRadius: 0,
                endCenter: CGPoint(x: 32, y: 32),
                endRadius: 46,
                options: []
            )
        }
        return SKTexture(image: image)
    }()
}
