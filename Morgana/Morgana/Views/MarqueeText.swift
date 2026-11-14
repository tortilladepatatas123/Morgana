import SwiftUI

private struct TextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct ContainerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct MarqueeKey: Equatable {
    let text: String
    let textWidth: Int
    let containerWidth: Int
}

/// Texto de una sola línea que, si no cabe, se desplaza de lado a lado en vez de
/// cortarse con puntos suspensivos. Si cabe, se muestra quieto con la alineación pedida.
/// Con "Reducir movimiento" activado vuelve al recorte con puntos suspensivos.
struct MarqueeText: View {
    let text: String
    var font: Font = .body
    var color: Color = .primary
    var alignment: Alignment = .leading
    /// Velocidad en puntos por segundo.
    var speed: Double = 35
    /// Pausa en cada extremo, en segundos.
    var pause: Double = 1.6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    private var overflow: CGFloat { max(textWidth - containerWidth, 0) }
    private var scrolls: Bool { overflow > 1 }

    var body: some View {
        if reduceMotion {
            Text(text)
                .font(font)
                .foregroundStyle(color)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: alignment)
        } else {
            marquee
        }
    }

    private var marquee: some View {
        // El texto invisible fija el alto y se adapta al ancho disponible (nunca lo desborda).
        // El texto visible va en un overlay: puede ser más ancho sin alterar el layout.
        Text(text)
            .font(font)
            .lineLimit(1)
            .opacity(0)
            .accessibilityHidden(true)
            .frame(maxWidth: .infinity, alignment: alignment)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ContainerWidthKey.self, value: proxy.size.width)
                }
            )
            .overlay(alignment: scrolls ? .leading : alignment) {
                Text(text)
                    .font(font)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: TextWidthKey.self, value: proxy.size.width)
                        }
                    )
                    .offset(x: scrolls ? offset : 0)
            }
            .clipped()
            .mask {
                if scrolls {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.05),
                            .init(color: .black, location: 0.95),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                } else {
                    Color.black
                }
            }
            .onPreferenceChange(TextWidthKey.self) { textWidth = $0 }
            .onPreferenceChange(ContainerWidthKey.self) { containerWidth = $0 }
            .task(id: MarqueeKey(text: text, textWidth: Int(textWidth), containerWidth: Int(containerWidth))) { @MainActor in
                await runLoop()
            }
    }

    @MainActor
    private func runLoop() async {
        offset = 0
        guard scrolls else { return }

        let distance = overflow + 24
        let duration = Double(distance) / speed

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
            if Task.isCancelled { return }
            withAnimation(.linear(duration: duration)) { offset = -distance }

            try? await Task.sleep(nanoseconds: UInt64((duration + pause) * 1_000_000_000))
            if Task.isCancelled { return }
            withAnimation(.easeInOut(duration: 0.5)) { offset = 0 }

            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }
}
