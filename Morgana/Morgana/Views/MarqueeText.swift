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

/// Texto de una sola línea que, si no cabe, se desplaza como un letrero continuo: siempre hacia
/// la izquierda, y una segunda copia del texto entra por la derecha a medida que la primera sale
/// por la izquierda (no va y vuelve). Si cabe, se muestra quieto con la alineación pedida.
/// Con "Reducir movimiento" activado se corta con puntos suspensivos.
///
/// La posición y el degradado de los bordes se calculan en cada fotograma a partir del tiempo
/// (con `TimelineView`), así el degradado depende de lo que el texto se ha movido de verdad.
struct MarqueeText: View {
    let text: String
    var font: Font = .body
    var color: Color = .primary
    var alignment: Alignment = .leading
    /// Velocidad en puntos por segundo.
    var speed: Double = 40
    /// Pausa, en segundos, cada vez que el texto vuelve a su posición inicial (0 = sin pausa).
    var pause: Double = 1.5
    /// Fotogramas por segundo de la animación. 30 basta en listas y ahorra batería.
    var fps: Double = 30

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var startDate = Date()

    /// Separación entre el final del texto y el principio de su copia.
    private let gap: CGFloat = 40
    /// Ancho de la zona difuminada de cada borde.
    private let fadeWidth: CGFloat = 16
    /// Puntos que debe desplazarse el texto para que el degradado de un borde esté al 100 %.
    private let fadeRamp: Double = 10

    private var scrolls: Bool { textWidth - containerWidth > 1 }
    /// Lo que hay que recorrer para que la copia ocupe el lugar de la primera.
    private var loopDistance: Double { Double(textWidth + gap) }

    var body: some View {
        if reduceMotion {
            Text(text)
                .font(font)
                .foregroundStyle(color)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: alignment)
        } else {
            TimelineView(.animation(minimumInterval: 1 / max(fps, 1), paused: !scrolls)) { timeline in
                let frame = scrollFrame(at: timeline.date)
                content(offset: frame.offset, leading: frame.leading)
            }
            .task(id: MarqueeKey(text: text, textWidth: Int(textWidth), containerWidth: Int(containerWidth))) { @MainActor in
                startDate = Date()
            }
        }
    }

    // MARK: - Contenido

    private func label(color: Color) -> some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func content(offset: CGFloat, leading: Double) -> some View {
        // El texto invisible fija el alto y se adapta al ancho disponible (nunca lo desborda).
        // Los textos visibles van en un overlay: pueden ser más anchos sin alterar el layout.
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
                HStack(spacing: gap) {
                    label(color: color)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(key: TextWidthKey.self, value: proxy.size.width)
                            }
                        )
                    if scrolls {
                        label(color: color)
                            .accessibilityHidden(true)
                    }
                }
                .offset(x: scrolls ? offset : 0)
            }
            .clipped()
            .mask { fadeMask(leading: leading) }
            .onPreferenceChange(TextWidthKey.self) { textWidth = $0 }
            .onPreferenceChange(ContainerWidthKey.self) { containerWidth = $0 }
    }

    // MARK: - Movimiento

    /// Desplazamiento y fuerza (0...1) del degradado izquierdo en un instante dado.
    /// Ciclo: pausa con el texto en su sitio → recorrido continuo hasta que la copia ocupa su lugar.
    private func scrollFrame(at date: Date) -> (offset: CGFloat, leading: Double) {
        guard scrolls else { return (0, 0) }

        let travel = loopDistance / speed
        let cycle = pause + travel
        let t = max(date.timeIntervalSince(startDate), 0).truncatingRemainder(dividingBy: cycle)

        let moved = t < pause ? 0 : (t - pause) * speed
        // Se corta por la izquierda mientras se mueve; el degradado sube al empezar y baja al llegar.
        let leading = min(min(moved, loopDistance - moved) / fadeRamp, 1)
        return (CGFloat(-moved), max(leading, 0))
    }

    // MARK: - Degradado de los bordes

    @ViewBuilder
    private func fadeMask(leading: Double) -> some View {
        if scrolls {
            HStack(spacing: 0) {
                edgeFade(isTrailing: false, strength: leading)
                Rectangle().fill(Color.black)
                // Por la derecha el texto siempre queda cortado, así que su degradado es fijo.
                edgeFade(isTrailing: true, strength: 1)
            }
        } else {
            Color.black
        }
    }

    /// Borde difuminado: con `strength` 0 es negro opaco (el texto se ve entero); con 1, degradado completo.
    private func edgeFade(isTrailing: Bool, strength: Double) -> some View {
        ZStack {
            LinearGradient(
                colors: isTrailing ? [Color.black, Color.clear] : [Color.clear, Color.black],
                startPoint: .leading,
                endPoint: .trailing
            )
            Color.black.opacity(1 - strength)
        }
        .frame(width: fadeWidth)
    }
}
