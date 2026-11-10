import SwiftUI

enum NotchFont: String, CaseIterable, Identifiable {
    case system = "System", rounded = "Rounded", serif = "Serif", monospaced = "Monospaced"
    case avenir = "Avenir Next", helvetica = "Helvetica Neue", georgia = "Georgia"
    var id: String { rawValue }
    func font(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        switch self {
        case .system: return .system(size: size, weight: weight, design: design)
        case .rounded: return .system(size: size, weight: weight, design: .rounded)
        case .serif: return .system(size: size, weight: weight, design: .serif)
        case .monospaced: return .system(size: size, weight: weight, design: .monospaced)
        case .avenir, .helvetica, .georgia: return .custom(rawValue, size: size).weight(weight)
        }
    }
}

@MainActor
final class NotchAppearance: ObservableObject {
    private let defaults: UserDefaults
    @Published var font: NotchFont { didSet { defaults.set(font.rawValue, forKey: "notch.font") } }
    @Published var textScale: Double {
        didSet {
            let bounded = Self.clamp(textScale, to: 0.8...1.4, fallback: 1)
            if textScale != bounded { textScale = bounded; return }
            defaults.set(textScale, forKey: "notch.textScale")
        }
    }
    @Published var width: Double {
        didSet {
            let bounded = Self.clamp(width, to: 380...680, fallback: 380)
            if width != bounded { width = bounded; return }
            defaults.set(width, forKey: "notch.width")
        }
    }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        font = defaults.string(forKey: "notch.font").flatMap(NotchFont.init(rawValue:)) ?? .system
        textScale = Self.clamp(defaults.object(forKey: "notch.textScale") as? Double ?? 1, to: 0.8...1.4, fallback: 1)
        width = Self.clamp(defaults.object(forKey: "notch.width") as? Double ?? 380, to: 380...680, fallback: 380)
    }
    func reset() { font = .system; textScale = 1; width = 380 }
    private static func clamp(_ value: Double, to range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
    }
}

private struct NotchFontModifier: ViewModifier {
    @EnvironmentObject var appearance: NotchAppearance
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    func body(content: Content) -> some View {
        content.font(appearance.font.font(size: size, weight: weight, design: design))
    }
}

extension View {
    func notchFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(NotchFontModifier(size: size, weight: weight, design: design))
    }
}
