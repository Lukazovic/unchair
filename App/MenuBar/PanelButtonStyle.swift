import SwiftUI

/// A tile-like button for the menu bar panel: a soft fill that is always
/// visible, so it reads as a button, and brightens on hover and press.
struct PanelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .panelTile(isPressed: configuration.isPressed)
    }
}

extension View {
    /// The panel tile look, for controls that can't take a button style, such as menus.
    func panelTile(isPressed: Bool = false) -> some View {
        modifier(PanelTile(isPressed: isPressed))
    }
}

private struct PanelTile: ViewModifier {
    let isPressed: Bool

    @Environment(\.colorSchemeContrast) private var contrast
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .font(.callout)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 30)
            .padding(.horizontal, 8)
            .background(fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                if contrast == .increased {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.primary.opacity(0.6))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var fill: AnyShapeStyle {
        if isPressed {
            AnyShapeStyle(.primary.opacity(0.2))
        } else if isHovered {
            AnyShapeStyle(.primary.opacity(0.13))
        } else {
            AnyShapeStyle(.primary.opacity(0.07))
        }
    }
}
