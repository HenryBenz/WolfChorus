import SwiftUI
import UIKit

enum Theme {
    static let nightNavy = Color(hex: 0x071126)
    static let deepForest = Color(hex: 0x102B57)
    static let moonCyan = Color(hex: 0x74E7FF)
    static let iceWhite = Color(hex: 0xEAF8FF)
    static let alphaRed = Color(hex: 0xFF493D)
    static let emberGold = Color(hex: 0xF5B83D)
    static let spiritViolet = Color(hex: 0xA988FF)
    static let calmGreen = Color(hex: 0x7DDBB5)
    static let panelBlack = Color(hex: 0x060B14, alpha: 0.86)
    static let primaryText = Color(hex: 0xF3FAFF)
    static let secondaryText = Color(hex: 0xAFC4D8)

    static func screenTitle(_ size: CGFloat = 28) -> Font {
        scaled(size: size, weight: .black, design: .rounded, textStyle: .title1)
    }

    static func sectionTitle() -> Font {
        scaled(size: 20, weight: .semibold, design: .rounded, textStyle: .title2)
    }

    static func buttonLabel() -> Font {
        scaled(size: 17, weight: .bold, design: .rounded, textStyle: .headline)
    }

    static func body() -> Font {
        scaled(size: 16, weight: .regular, design: .default, textStyle: .body)
    }

    static func caption() -> Font {
        scaled(size: 13, weight: .medium, design: .default, textStyle: .caption1)
    }

    static func hudNumber() -> Font {
        .system(size: 15, weight: .heavy, design: .monospaced)
    }

    static func hudText() -> Font {
        .system(size: 13, weight: .medium, design: .default)
    }

    private static func scaled(size: CGFloat, weight: UIFont.Weight, design: UIFontDescriptor.SystemDesign, textStyle: UIFont.TextStyle) -> Font {
        let category = cappedCategory()
        let traits = UITraitCollection(preferredContentSizeCategory: category)
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor.withDesign(design) ?? base.fontDescriptor
        let designed = UIFont(descriptor: descriptor, size: size)
        let scaled = UIFontMetrics(forTextStyle: textStyle).scaledFont(for: designed, compatibleWith: traits)
        return Font(scaled)
    }

    private static func cappedCategory() -> UIContentSizeCategory {
        let current = UIApplication.shared.preferredContentSizeCategory
        let order: [UIContentSizeCategory] = [
            .extraSmall, .small, .medium, .large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
            .accessibilityMedium, .accessibilityLarge
        ]
        if let index = order.firstIndex(of: current) {
            return order[index]
        }
        if current > .accessibilityLarge {
            return .accessibilityLarge
        }
        return current
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt32(cleaned, radix: 16) ?? 0x74E7FF
        self.init(hex: value)
    }
}

struct ArtImage: View {
    let name: String
    var capInsets: EdgeInsets? = nil
    var resizingMode: Image.ResizingMode = .stretch

    var body: some View {
        if UIImage(named: name) != nil {
            if let capInsets {
                Image(name)
                    .resizable(capInsets: capInsets, resizingMode: resizingMode)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            } else {
                Image(name)
                    .resizable()
            }
        } else {
            #if DEBUG
            Color(hex: 0x060B14)
                .onAppear {
                    assertionFailure("Missing PNG \(name).png")
                }
            #else
            Color.clear
            #endif
        }
    }
}

enum BundleInfo {
    static var versionLabel: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(short) (\(build))"
    }
}
