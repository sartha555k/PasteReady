import SwiftUI

enum PanelPalette {
    static let secondary = Color.white.opacity(0.64)
    static let hint = Color.white.opacity(0.54)
    static let field = Color.white.opacity(0.065)
    static let selection = Color(red: 0.055, green: 0.115, blue: 0.20)
    static let selectionEdge = Color(red: 0.29, green: 0.52, blue: 0.86).opacity(0.55)
    static let accent = Color(red: 0.53, green: 0.72, blue: 1)
}

struct PanelKeycap: View {
    let key: String
    var symbol = false
    var body: some View {
        Group {
            if symbol { Image(systemName: key).font(.system(size: 9, weight: .medium)) }
            else { Text(key).font(.system(size: 9, weight: .medium)) }
        }
        .foregroundStyle(.white.opacity(0.72))
        .padding(.horizontal, 5).frame(minWidth: 18, minHeight: 17)
        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 4))
        .accessibilityHidden(true)
    }
}

struct PanelShortcut: View {
    let key: String
    let title: String
    var symbol = false
    var body: some View {
        HStack(spacing: 5) {
            PanelKeycap(key: key, symbol: symbol)
            Text(title).font(.system(size: 10.5, weight: .medium)).foregroundStyle(PanelPalette.hint).lineLimit(1).fixedSize()
        }
    }
}

struct PanelIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { StyledButton(configuration: configuration) }
    private struct StyledButton: View {
        let configuration: ButtonStyle.Configuration
        @Environment(\.isEnabled) private var enabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var hovering = false
        var body: some View {
            configuration.label
                .background(.white.opacity(configuration.isPressed ? 0.14 : hovering ? 0.075 : 0),
                    in: RoundedRectangle(cornerRadius: 8))
                .opacity(enabled ? 1 : 0.35)
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
                .onHover { hovering = $0 }
        }
    }
}
