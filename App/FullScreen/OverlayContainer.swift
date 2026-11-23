import SwiftUI

/// The backdrop of every full-screen alert. Centers its content on the whole
/// display, notch included, and scrolls when the display is too short for it.
struct OverlayContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                content
                    .padding(40)
                    .frame(width: geometry.size.width)
                    .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(.ultraThickMaterial)
        .ignoresSafeArea()
    }
}
