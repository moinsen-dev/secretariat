import SwiftUI
import SecretariatCore

/// One face per kind of item: a colour that goes with its symbol (DESIGN.md, „Ein Gesicht je Art“).
extension Template {
    var color: Color {
        switch id {
        case "company": .indigo
        case "api": .blue
        case "token": .purple
        case "account": .orange
        case "login": .green
        case "certificate": .brown
        case "database": .teal
        case "server": .gray
        case "note": .yellow
        case "capture": .cyan
        default: .accentColor
        }
    }
}

/// Rounded colour square with a white symbol, like folders and lists in Apple's apps.
struct KindIcon: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
            .accessibilityHidden(true)
    }
}

extension View {
    /// Liquid Glass button on macOS 26+, bordered before (DESIGN.md: glass sparingly, for the main action of a surface).
    @ViewBuilder func glassButton() -> some View {
        if #available(macOS 26.0, *) { buttonStyle(.glass) } else { buttonStyle(.bordered) }
    }
}
