import SwiftUI
import UIKit

enum Theme {
    static let accent = Color(red: 1.00, green: 0.62, blue: 0.20)
    static let accentDeep = Color(red: 0.95, green: 0.36, blue: 0.16)
    static let background = Color(red: 0.045, green: 0.05, blue: 0.065)
    static let card = Color(red: 0.105, green: 0.11, blue: 0.135)
    static let chip = Color.white.opacity(0.08)
    static let live = Color(red: 0.30, green: 0.86, blue: 0.56)
    static let warn = Color(red: 1.00, green: 0.42, blue: 0.38)

    static let glow = LinearGradient(
        colors: [accent, accentDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Dark, opaque bars so content doesn't smear under them.
    static func applyBars() {
        let bg = UIColor(red: 0.045, green: 0.05, blue: 0.065, alpha: 1)
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = bg
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = bg
        nav.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }
}

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

extension View {
    /// Page background for every list in the app.
    func themedList() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
    }
}

/// Rounded pill used for inputs, sound modes and quick selects.
struct ChipStyle: ButtonStyle {
    var selected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(selected ? .semibold : .regular))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? AnyShapeStyle(Theme.glow) : AnyShapeStyle(Theme.chip))
            )
            .foregroundStyle(selected ? Color.black : Color.white)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Round icon button for the remote (power, mute, cursor keys).
struct RoundKeyStyle: ButtonStyle {
    var size: CGFloat = 56
    var fill: AnyShapeStyle = AnyShapeStyle(Theme.chip)
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .frame(width: size, height: size)
            .background(Circle().fill(fill))
            .foregroundStyle(foreground)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Small rounded label, e.g. the audio format.
struct Badge: View {
    let text: String
    var color: Color = Theme.accent

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.16)))
            .foregroundStyle(color)
    }
}

/// Three-quarter ring showing master volume with the dB readout in the middle.
struct VolumeDial: View {
    let fraction: Double
    let text: String
    let caption: String
    let muted: Bool

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: 0.75 * max(0.002, min(fraction, 1)))
                .stroke(
                    muted ? AnyShapeStyle(Color.gray.opacity(0.5)) : AnyShapeStyle(Theme.glow),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(135))
                .shadow(color: muted ? .clear : Theme.accent.opacity(0.45), radius: 10)
                .animation(.easeOut(duration: 0.2), value: fraction)
            VStack(spacing: 2) {
                Text(text)
                    .font(.system(size: 42, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(caption)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(muted ? Theme.warn : Color.secondary)
            }
            .padding(.horizontal, 30)
        }
        .frame(width: 214, height: 214)
    }
}
