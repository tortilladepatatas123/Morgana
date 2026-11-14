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
///
/// La posición y el degradado de los bordes se calculan en cada fotograma a partir del tiempo
/// (con `TimelineView`), no con animaciones de SwiftUI. Así el degradado de cada borde depende
/// de lo que el texto se ha movido de verdad: aparece en cuanto empieza a desplazarse y
/// desaparece cuando llega al extremo, sin que se pierda ninguna letra.
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
    @State private var startDate = Date()

    private let returnDuration = 0.5
    /// Ancho de la zona difuminada de cada borde.
    private let fadeWidth: CGFloat = 16
    /// Puntos que debe desplazarse el texto para que el degradado de un borde esté al 100 %.
    private let fadeRamp: Double = 10

    private var overflow: CGFloat { max(textWidth - containerWidth, 0) }
    private var scrolls: Bool { overflow > 1 }
    /// Recorrido total: lo que sobra más un margen para que el final no quede pegado al borde.
    private var scrollDistance: Double { Double(overflow) + 24 }

    var body: some View {
        if reduceMotion {
            Text(text)
                .font(font)
                .foregroundStyle(color)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: alignment)
        } else {
            TimelineView(.animation(paused: !scrolls)) { timeline in
                let frame = scrollFrame(at: timeline.date)
                content(offset: frame.offset, leading: frame.leading, trailing: frame.trailing)
            }
            .task(id: MarqueeKey(text: text, textWidth: Int(textWidth), containerWidth: Int(containerWidth))) { @MainActor in
                startDate = Date()
            }
        }
    }

    // MARK: - Contenido

    private func content(offset: CGFloat, leading: Double, trailing: Double) -> some View {
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
            .mask { fadeMask(leading: leading, trailing: trailing) }
            .onPreferenceChange(TextWidthKey.self) { textWidth = $0 }
            .onPreferenceChange(ContainerWidthKey.self) { containerWidth = $0 }
    }

    // MARK: - Movimiento

    /// Desplazamiento y fuerza (0...1) del degradado de cada borde en un instante dado.
    /// Ciclo: pausa → recorrido lineal → pausa → vuelta suave al inicio.
    private func scrollFrame(at date: Date) -> (offset: CGFloat, leading: Double, trailing: Double) {
        guard scrolls else { return (0, 0, 0) }

        let travel = scrollDistance / speed
        let cycle = pause + travel + pause + returnDuration
        let t = max(date.timeIntervalSince(startDate), 0).truncatingRemainder(dividingBy: cycle)

        let progress: Double
        if t < pause {
            progress = 0
        } else if t < pause + travel {
            progress = (t - pause) / travel
        } else if t < 2 * pause + travel {
            progress = 1
        } else {
            let r = (t - 2 * pause - travel) / returnDuration
            progress = 1 - r * r * (3 - 2 * r)
        }

        let moved = progress * scrollDistance
        let remaining = scrollDistance - moved
        return (
            CGFloat(-moved),
            min(moved / fadeRamp, 1),       // algo queda cortado a la izquierda: sube nada más moverse
            min(remaining / fadeRamp, 1)    // algo queda cortado a la derecha: baja al llegar al final
        )
    }

    // MARK: - Degradado de los bordes

    @ViewBuilder
    private func fadeMask(leading: Double, trailing: Double) -> some View {
        if scrolls {
            HStack(spacing: 0) {
                edgeFade(isTrailing: false, strength: leading)
                Rectangle().fill(Color.black)
                edgeFade(isTrailing: true, strength: trailing)
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
