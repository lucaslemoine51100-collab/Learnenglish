import SwiftUI

/// Fenêtre flottante au-dessus de la page : déplaçable (barre de titre), redimensionnable (coin inférieur droit)
/// et réductible en une pastille. Position et taille sont mémorisées.
struct FloatingPanel<Content: View>: View {
    let containerSize: CGSize
    @Binding var isCollapsed: Bool
    let content: () -> Content

    @AppStorage("panel.x") private var storedX: Double = -1
    @AppStorage("panel.y") private var storedY: Double = -1
    @AppStorage("panel.width") private var storedWidth: Double = 360
    @AppStorage("panel.height") private var storedHeight: Double = 480

    @State private var liveOrigin: CGPoint?
    @State private var liveSize: CGSize?
    @State private var dragStart: CGPoint?
    @State private var resizeStart: CGSize?

    private let minimumSize = CGSize(width: 280, height: 220)
    private let pillSize: CGFloat = 56
    private let margin: CGFloat = 12

    init(containerSize: CGSize, isCollapsed: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {
        self.containerSize = containerSize
        self._isCollapsed = isCollapsed
        self.content = content
    }

    var body: some View {
        let size = panelSize
        let frameSize = isCollapsed ? CGSize(width: pillSize, height: pillSize) : size
        let origin = clamped(liveOrigin ?? storedOrigin(for: size), frameSize: frameSize)

        Group {
            if isCollapsed {
                pill
            } else {
                expandedPanel(size: size)
            }
        }
        .offset(x: origin.x, y: origin.y)
    }

    // MARK: - Vues

    private var pill: some View {
        Image(systemName: "text.bubble.fill")
            .font(.title2)
            .foregroundStyle(.white)
            .frame(width: pillSize, height: pillSize)
            .background(Circle().fill(Color.accentColor))
            .shadow(radius: 6)
            .onTapGesture { isCollapsed = false }
            .gesture(moveGesture(frameSize: CGSize(width: pillSize, height: pillSize)))
            .accessibilityLabel("Ouvrir l'assistant")
            .accessibilityAddTraits(.isButton)
    }

    private func expandedPanel(size: CGSize) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
                Text("Assistant")
                    .font(.headline)
                Spacer()
                Button {
                    isCollapsed = true
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Réduire l'assistant")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .gesture(moveGesture(frameSize: size))

            Divider()

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: size.width, height: size.height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .rotationEffect(.degrees(90))
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .gesture(resizeGesture)
                .accessibilityLabel("Redimensionner")
        }
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }

    // MARK: - Gestes

    private func moveGesture(frameSize: CGSize) -> some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                let start = dragStart ?? clamped(liveOrigin ?? storedOrigin(for: panelSize), frameSize: frameSize)
                if dragStart == nil { dragStart = start }
                liveOrigin = CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height)
            }
            .onEnded { _ in
                let final = clamped(liveOrigin ?? storedOrigin(for: panelSize), frameSize: frameSize)
                storedX = Double(final.x)
                storedY = Double(final.y)
                liveOrigin = nil
                dragStart = nil
            }
    }

    private var resizeGesture: some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                let start = resizeStart ?? panelSize
                if resizeStart == nil { resizeStart = start }
                liveSize = CGSize(width: start.width + value.translation.width,
                                  height: start.height + value.translation.height)
            }
            .onEnded { _ in
                let final = panelSize
                storedWidth = Double(final.width)
                storedHeight = Double(final.height)
                liveSize = nil
                resizeStart = nil
            }
    }

    // MARK: - Géométrie

    private var panelSize: CGSize {
        let wanted = liveSize ?? CGSize(width: storedWidth, height: storedHeight)
        let maxWidth = max(minimumSize.width, containerSize.width - 2 * margin)
        let maxHeight = max(minimumSize.height, containerSize.height - 2 * margin)
        return CGSize(width: min(max(wanted.width, minimumSize.width), maxWidth),
                      height: min(max(wanted.height, minimumSize.height), maxHeight))
    }

    /// Position mémorisée ; par défaut, en haut à droite.
    private func storedOrigin(for size: CGSize) -> CGPoint {
        if storedX < 0 || storedY < 0 {
            return CGPoint(x: containerSize.width - size.width - margin, y: margin)
        }
        return CGPoint(x: storedX, y: storedY)
    }

    private func clamped(_ point: CGPoint, frameSize: CGSize) -> CGPoint {
        let maxX = max(0, containerSize.width - frameSize.width)
        let maxY = max(0, containerSize.height - frameSize.height)
        return CGPoint(x: min(max(0, point.x), maxX), y: min(max(0, point.y), maxY))
    }
}
