import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var player: PlayerManager
    @EnvironmentObject var userData: PlaylistStore

    @State private var palette = ArtworkPalette.fallback
    @State private var showLyrics = false
    /// La letra aparece un poco después de que el resto se haya movido.
    @State private var lyricsVisible = false

    var body: some View {
        // El fondo va en `.background` y no como hermano en un ZStack: la carátula difuminada
        // (scaledToFill) es más ancha que la pantalla y, dentro de un ZStack, ensanchaba todo el
        // contenido y lo cortaba por los lados.
        GeometryReader { geo in
            if let track = player.currentTrack {
                content(track: track, size: geo.size)
            } else {
                Text("No hay nada en reproducción")
                    .foregroundStyle(Color.white.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background {
            NowPlayingBackground(palette: palette, artworkKey: player.currentTrack?.artworkKey)
        }
        .foregroundStyle(Color.white)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .onChange(of: player.currentTrack?.id) { _ in
            // Si la nueva pista no tiene letra, se sale del modo letra.
            if player.currentTrack?.hasLyrics != true {
                showLyrics = false
                lyricsVisible = false
            }
        }
        .task(id: player.currentTrack?.artworkKey) { @MainActor in
            guard let key = player.currentTrack?.artworkKey else { return }
            let result = await Task.detached(priority: .utility) {
                PaletteExtractor.palette(key: key)
            }.value
            withAnimation(.easeInOut(duration: 0.8)) {
                palette = result ?? .fallback
            }
        }
    }

    // MARK: - Disposición
    //
    // Sin scroll y con bloques de alto constante, así que nada se mueve al cambiar de canción.
    // Una sola disposición (`NowPlayingGeometry` + `LerpFrame`) coloca todas las piezas, con y sin letra, y
    // calcula cada posición a partir de un valor `t` (0 = normal, 1 = letra) que se anima:
    // así la carátula, los títulos, los botones, la barra y los controles se desplazan a su
    // sitio sin fundidos. Las tarjetas se encogen con desenfoque y la letra entra al final.

    /// Curva de la transición.
    private let moveAnimation = Animation.timingCurve(0.45, 0, 0.15, 1, duration: 0.6)

    private func content(track: Track, size: CGSize) -> some View {
        let lyrics = showLyrics && track.hasLyrics == true
        let t: CGFloat = lyrics ? 1 : 0

        let geometry = NowPlayingGeometry(landscape: size.width > size.height)
        let normal = geometry.rects(compact: false, size: size)
        let compact = geometry.rects(compact: true, size: size)

        // Cada pieza se coloca con un modificador animable: al cambiar `t` dentro de un
        // `withAnimation`, SwiftUI recalcula su posición y tamaño en cada fotograma.
        func piece<V: View>(_ index: Int, _ view: V) -> some View {
            view.modifier(LerpFrame(t: t, from: normal[index], to: compact[index]))
        }

        return ZStack(alignment: .topLeading) {
            piece(0, artwork(track: track, lyrics: lyrics))
            piece(1, lyricsToggle(track: track))
            piece(2, titles(track: track, lyrics: lyrics))
            piece(3, starButton(track: track))
            piece(4, lyricsSlot(track: track, lyrics: lyrics))
            piece(5, ProgressSection(clock: player.clock))
            piece(6, controls)
            piece(7, badges(track: track, collapsed: lyrics))
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    // MARK: - Piezas

    private func artwork(track: Track, lyrics: Bool) -> some View {
        ArtworkView(key: track.artworkKey, pixels: 900)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: lyrics ? 8 : 10, style: .continuous))
            .shadow(color: Color.black.opacity(lyrics ? 0 : 0.35), radius: lyrics ? 0 : 18, y: lyrics ? 0 : 10)
            .trackActions(track, swipe: false)
    }

    private func starButton(track: Track) -> some View {
        let isFavorite = userData.isFavorite(track.id)

        return Button {
            userData.toggleFavorite(track.id)
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isFavorite ? Color.yellow : Color.white.opacity(0.8))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFavorite ? "Quitar de favoritos" : "Añadir a favoritos")
    }

    /// Botón de letra, encima de la barra de progreso. Siempre ocupa su sitio; si la pista no
    /// tiene letra se oculta pero no mueve nada.
    private func lyricsToggle(track: Track) -> some View {
        let hasLyrics = track.hasLyrics == true

        return Button {
            toggleLyrics()
        } label: {
            Label("Letra", systemImage: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Capsule().fill(Color.white.opacity(showLyrics ? 0.32 : 0.16)))
        }
        .buttonStyle(.plain)
        .opacity(hasLyrics ? 1 : 0)
        .disabled(!hasLyrics)
        .accessibilityHidden(!hasLyrics)
    }

    /// Título y artista: centrados en la vista normal, a la izquierda con la letra abierta.
    private func titles(track: Track, lyrics: Bool) -> some View {
        VStack(alignment: lyrics ? .leading : .center, spacing: lyrics ? 2 : 4) {
            MarqueeText(
                text: track.title,
                font: lyrics ? .headline : .title3.bold(),
                color: .white,
                alignment: lyrics ? .leading : .center,
                fps: 60
            )
            MarqueeText(
                text: track.artist,
                font: lyrics ? .subheadline : .body,
                color: Color.white.opacity(0.75),
                alignment: lyrics ? .leading : .center,
                fps: 60
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Letra con fundido y desenfoque; entra cuando el resto ya se ha colocado y sale enseguida.
    /// Solo se crea con la letra abierta, para no leer el archivo si no hace falta.
    @ViewBuilder
    private func lyricsSlot(track: Track, lyrics: Bool) -> some View {
        if lyrics {
            LyricsPanel(track: track)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(lyricsVisible ? 1 : 0)
                .blur(radius: lyricsVisible ? 0 : 14)
                .animation(
                    lyricsVisible ? .easeOut(duration: 0.7) : .easeIn(duration: 0.2),
                    value: lyricsVisible
                )
        } else {
            Color.clear
        }
    }

    private var controls: some View {
        HStack(spacing: 0) {
            toggleButton(systemImage: "shuffle", isOn: player.isShuffleOn) {
                player.toggleShuffle()
            }

            Button { player.previous() } label: {
                Image(systemName: "backward.fill").font(.system(size: 30))
            }
            .frame(maxWidth: .infinity)

            Button { player.togglePlayPause() } label: {
                PlayPauseIcon(isPlaying: player.isPlaying, size: 46)
                    .frame(width: 64, height: 64)
            }
            .frame(maxWidth: .infinity)

            Button { player.next() } label: {
                Image(systemName: "forward.fill").font(.system(size: 30))
            }
            .frame(maxWidth: .infinity)

            toggleButton(
                systemImage: player.repeatMode == .one ? "repeat.1" : "repeat",
                isOn: player.repeatMode != .off
            ) {
                player.repeatMode = player.repeatMode.next
            }
        }
        .buttonStyle(PressableButtonStyle())
        .foregroundStyle(Color.white)
    }

    private func toggleButton(systemImage: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(isOn ? 1 : 0.5))
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
                    .opacity(isOn ? 1 : 0)
            }
            .frame(width: 44, height: 44)
        }
        .frame(maxWidth: .infinity)
    }

    private func toggleLyrics() {
        if showLyrics {
            lyricsVisible = false
            withAnimation(moveAnimation) { showLyrics = false }
        } else {
            withAnimation(moveAnimation) { showLyrics = true }
            // La letra entra cuando el resto ya se ha colocado.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                if showLyrics { lyricsVisible = true }
            }
        }
    }

    /// Tarjetas de información. Al abrir la letra se encogen y se desenfocan hasta desaparecer.
    private func badges(track: Track, collapsed: Bool) -> some View {
        HStack(spacing: 6) {
            InfoCard(title: "Códec", value: track.codecText)
            if let value = track.sampleRateText { InfoCard(title: "Frecuencia", value: value) }
            if let value = track.bitDepthText { InfoCard(title: "Profundidad", value: value) }
            if let value = track.bitrateText { InfoCard(title: "Bitrate", value: value) }
        }
        .scaleEffect(collapsed ? 0.6 : 1)
        .blur(radius: collapsed ? 14 : 0)
        .opacity(collapsed ? 0 : 1)
        .allowsHitTesting(!collapsed)
    }
}

/// Coloca una pieza entre su posición normal (`t` = 0) y la de letra abierta (`t` = 1).
private struct LerpFrame: ViewModifier, Animatable {
    var t: CGFloat
    let from: CGRect
    let to: CGRect

    var animatableData: CGFloat {
        get { t }
        set { t = newValue }
    }

    func body(content: Content) -> some View {
        let x = from.minX + (to.minX - from.minX) * t
        let y = from.minY + (to.minY - from.minY) * t
        let w = max(from.width + (to.width - from.width) * t, 0)
        let h = max(from.height + (to.height - from.height) * t, 0)

        content
            .frame(width: w, height: h)
            .position(x: x + w / 2, y: y + h / 2)
    }
}

/// Dónde va cada pieza de la pantalla de reproducción en cada una de sus dos vistas. Orden:
/// carátula, botón de letra, títulos, estrella, letra, barra de progreso, controles y tarjetas.
private struct NowPlayingGeometry {
    var landscape: Bool

    private let rowH: CGFloat = 48
    private let progressH: CGFloat = 40
    private let controlsH: CGFloat = 64
    private let badgesH: CGFloat = 54
    private let headerH: CGFloat = 56
    private let button: CGFloat = 36
    private let toggleH: CGFloat = 34
    private let toggleW: CGFloat = 112

    /// Posición de cada pieza en una de las dos vistas.
    func rects(compact: Bool, size: CGSize) -> [CGRect] {
        landscape ? landscapeRects(compact: compact, size: size) : portraitRects(compact: compact, size: size)
    }

    private func portraitRects(compact: Bool, size: CGSize) -> [CGRect] {
        let w = size.width, h = size.height
        let px: CGFloat = 24, top: CGFloat = 24, bottom: CGFloat = 12
        let cw = w - 2 * px
        let gap: CGFloat = 20
        let small: CGFloat = 12

        // El botón de letra va siempre encima de la barra de progreso, centrado.
        func toggle(progY: CGFloat) -> CGRect {
            CGRect(x: px + (cw - toggleW) / 2, y: progY - small - toggleH, width: toggleW, height: toggleH)
        }

        // Posiciones de la vista con letra (la letra solo se ve en ella).
        let ctrlYLyrics = h - bottom - controlsH
        let progYLyrics = ctrlYLyrics - 16 - progressH
        let toggleLyrics = toggle(progY: progYLyrics)
        let panelY = top + headerH + 16
        let panel = CGRect(x: px, y: panelY, width: cw, height: max(toggleLyrics.minY - 16 - panelY, 0))

        if compact {
            return [
                CGRect(x: px, y: top, width: headerH, height: headerH),
                toggleLyrics,
                CGRect(x: px + headerH + 10, y: top, width: cw - headerH - 10 - button - 8, height: headerH),
                CGRect(x: px + cw - button, y: top + (headerH - button) / 2, width: button, height: button),
                panel,
                CGRect(x: px, y: progYLyrics, width: cw, height: progressH),
                CGRect(x: px, y: ctrlYLyrics, width: cw, height: controlsH),
                CGRect(x: px, y: h - bottom, width: cw, height: 0)
            ]
        }

        let others = gap + rowH + gap + toggleH + small + progressH + gap + controlsH + gap + badgesH
        let side = max(120, min(cw, h - top - bottom - others))
        let total = side + others
        let y0 = top + max(0, (h - top - bottom - total) / 2)
        let rowY = y0 + side + gap
        let toggleY = rowY + rowH + gap
        let progY = toggleY + toggleH + small
        let ctrlY = progY + progressH + gap
        let badY = ctrlY + controlsH + gap

        return [
            CGRect(x: px + (cw - side) / 2, y: y0, width: side, height: side),
            toggle(progY: progY),
            CGRect(x: px + button + 8, y: rowY, width: cw - 2 * button - 16, height: rowH),
            CGRect(x: px + cw - button, y: rowY + (rowH - button) / 2, width: button, height: button),
            panel,
            CGRect(x: px, y: progY, width: cw, height: progressH),
            CGRect(x: px, y: ctrlY, width: cw, height: controlsH),
            CGRect(x: px, y: badY, width: cw, height: badgesH)
        ]
    }

    private func landscapeRects(compact: Bool, size: CGSize) -> [CGRect] {
        let w = size.width, h = size.height
        let px: CGFloat = 28, top: CGFloat = 28, bottom: CGFloat = 12
        let gap: CGFloat = 12
        let leftW = w * 0.42

        let panelX = px + leftW + 28
        let panelW = max(w - px - panelX, 0)

        if compact {
            let ctrlY = h - bottom - controlsH
            let progY = ctrlY - gap - progressH
            let toggleY = progY - gap - toggleH
            return [
                CGRect(x: px, y: top, width: headerH, height: headerH),
                CGRect(x: px + (leftW - toggleW) / 2, y: toggleY, width: toggleW, height: toggleH),
                CGRect(x: px + headerH + 10, y: top, width: leftW - headerH - 10 - button - 8, height: headerH),
                CGRect(x: px + leftW - button, y: top + (headerH - button) / 2, width: button, height: button),
                CGRect(x: panelX, y: top, width: panelW, height: h - top - bottom),
                CGRect(x: px, y: progY, width: leftW, height: progressH),
                CGRect(x: px, y: ctrlY, width: leftW, height: controlsH),
                CGRect(x: px, y: h - bottom, width: leftW, height: 0)
            ]
        }

        let side = max(120, min(h - 52, w * 0.42))
        let colX = px + side + 28
        let colW = max(w - px - colX, 0)
        let colTotal = rowH + gap + toggleH + gap + progressH + gap + controlsH + gap + badgesH
        let y0 = top + max(0, (h - top - bottom - colTotal) / 2)
        let toggleY = y0 + rowH + gap
        let progY = toggleY + toggleH + gap
        let ctrlY = progY + progressH + gap
        let badY = ctrlY + controlsH + gap

        return [
            CGRect(x: px, y: (h - side) / 2, width: side, height: side),
            CGRect(x: colX + (colW - toggleW) / 2, y: toggleY, width: toggleW, height: toggleH),
            CGRect(x: colX + button + 8, y: y0, width: max(colW - 2 * button - 16, 0), height: rowH),
            CGRect(x: colX + colW - button, y: y0 + (rowH - button) / 2, width: button, height: button),
            CGRect(x: panelX, y: top, width: panelW, height: h - top - bottom),
            CGRect(x: colX, y: progY, width: colW, height: progressH),
            CGRect(x: colX, y: ctrlY, width: colW, height: controlsH),
            CGRect(x: colX, y: badY, width: colW, height: badgesH)
        ]
    }
}

// MARK: - Barra de progreso

/// Barra de progreso con su propio reloj: es la única parte de la pantalla que se redibuja
/// al avanzar la canción.
private struct ProgressSection: View {
    @EnvironmentObject var player: PlayerManager
    @ObservedObject var clock: PlaybackClock

    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0

    private var displayedTime: Double {
        isScrubbing ? scrubValue : clock.currentTime
    }

    var body: some View {
        VStack(spacing: 2) {
            SeekBar(
                value: Binding(
                    get: { displayedTime },
                    set: { scrubValue = $0 }
                ),
                range: 0...max(player.duration, 1)
            ) { editing in
                if editing {
                    scrubValue = clock.currentTime
                    isScrubbing = true
                    player.beginScrubbing()
                } else {
                    player.endScrubbing(at: scrubValue)
                    isScrubbing = false
                }
            }

            HStack {
                Text(formatTime(displayedTime))
                Spacer()
                // Signo menos matemático (U+2212), no el guion.
                Text("\u{2212}" + formatTime(max(player.duration - displayedTime, 0)))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(Color.white.opacity(0.7))
        }
    }
}

/// Barra propia (el `Slider` del sistema no deja cambiar el color del fondo de la pista):
/// pista blanca al 15 % de opacidad, relleno blanco y sin pulgar; se engrosa al arrastrar.
private struct SeekBar: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onEditingChanged: (Bool) -> Void

    @State private var isDragging = false

    private var span: Double { max(range.upperBound - range.lowerBound, 0.0001) }
    private var fraction: Double { min(max((value - range.lowerBound) / span, 0), 1) }

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)

            // Pista y relleno son rectángulos y se recortan juntos con una cápsula: el borde de avance
            // del relleno queda recto y solo los extremos de la barra son redondeados.
            ZStack(alignment: .leading) {
                Color.white.opacity(0.15)
                Color.white.frame(width: width * fraction)
            }
            .frame(height: isDragging ? 10 : 6)
            .clipShape(Capsule())
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged(true)
                        }
                        value = position(for: drag.location.x, width: width)
                    }
                    .onEnded { drag in
                        value = position(for: drag.location.x, width: width)
                        isDragging = false
                        onEditingChanged(false)
                    }
            )
            .animation(.easeOut(duration: 0.15), value: isDragging)
        }
        .frame(height: 28)
        .accessibilityElement()
        .accessibilityLabel("Posición")
        .accessibilityValue(Text("\(Int(fraction * 100)) %"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: nudge(by: 5)
            case .decrement: nudge(by: -5)
            @unknown default: break
            }
        }
    }

    private func position(for x: CGFloat, width: CGFloat) -> Double {
        range.lowerBound + min(max(Double(x / width), 0), 1) * span
    }

    private func nudge(by seconds: Double) {
        onEditingChanged(true)
        value = min(max(value + seconds, range.lowerBound), range.upperBound)
        onEditingChanged(false)
    }
}

/// Tarjeta pequeña con un dato técnico del audio.
private struct InfoCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            // Tamaño de letra fijo, sin reducirlo según el contenido: así "320 kbps" y "1411 kbps"
            // se ven iguales y todas las tarjetas miden lo mismo (se reparten el ancho a partes iguales).
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.6))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 2)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }
}

/// Fondo con degradado suave a partir de los colores dominantes de la carátula,
/// más la propia carátula muy difuminada por debajo.
private struct NowPlayingBackground: View {
    let palette: ArtworkPalette
    let artworkKey: String?

    @State private var blurred: UIImage?

    var body: some View {
        ZStack {
            Color.black

            LinearGradient(
                colors: [palette.primary, palette.secondary, palette.tertiary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // La imagen va en un overlay de un Color.clear y se recorta: así nunca influye en el tamaño.
            Color.clear
                .overlay {
                    if let blurred {
                        Image(uiImage: blurred)
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 60)
                            .opacity(0.35)
                            .transition(.opacity)
                    }
                }
                .clipped()

            Color.black.opacity(0.15)
        }
        .ignoresSafeArea()
        .task(id: artworkKey) { @MainActor in
            guard let artworkKey else { blurred = nil; return }
            let image = await Task.detached(priority: .utility) {
                ArtworkStore.image(key: artworkKey, maxPixel: 120)
            }.value
            withAnimation(.easeInOut(duration: 0.6)) { blurred = image }
        }
    }
}
