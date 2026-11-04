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
        LinearGradient(colors: [QTheme.cream, QTheme.paper], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
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
