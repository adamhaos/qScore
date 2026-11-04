import SwiftUI

enum QTheme {
    static let ink = Color(uiColor: .label)
    static let cream = Color(uiColor: .systemBackground)
    static let paper = Color(uiColor: .secondarySystemBackground)
    static let sage = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.52, green: 0.73, blue: 0.58, alpha: 1)
            : UIColor(red: 0.30, green: 0.45, blue: 0.36, alpha: 1)
    })
    static let gold = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.90, green: 0.72, blue: 0.35, alpha: 1)
            : UIColor(red: 0.82, green: 0.57, blue: 0.18, alpha: 1)
    })
}

struct QBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [QTheme.cream, QTheme.paper], startPoint: .topLeading, endPoint: .bottomTrailing)
            LinearGradient(
                colors: [QTheme.sage.opacity(0.16), QTheme.sage.opacity(0.05), QTheme.sage.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

/// Shared animation curves so motion feels the same everywhere.
enum QMotion {
    static let snappy = Animation.snappy(duration: 0.3)
    static let smooth = Animation.smooth(duration: 0.35)
    static let bouncy = Animation.spring(response: 0.45, dampingFraction: 0.68)
    static let press = Animation.spring(response: 0.25, dampingFraction: 0.7)
}

/// A plain button that shrinks slightly while pressed.
struct QPressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .animation(QMotion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == QPressableButtonStyle {
    static var pressable: QPressableButtonStyle { QPressableButtonStyle() }
    static func pressable(scale: CGFloat) -> QPressableButtonStyle { QPressableButtonStyle(scale: scale) }
}

struct QCardModifier: ViewModifier {
    let showsShadow: Bool

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(QTheme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(QTheme.ink.opacity(0.08), lineWidth: 1) }
            .shadow(color: showsShadow ? QTheme.ink.opacity(0.07) : .clear, radius: 12, y: 5)
    }
}

extension View {
    func qCard(showsShadow: Bool = true) -> some View {
        modifier(QCardModifier(showsShadow: showsShadow))
    }
}
