import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var player: PlayerManager
    @EnvironmentObject var userData: PlaylistStore

    @State private var palette = ArtworkPalette.fallback
    @State private var showLyrics = false
    /// La letra aparece un poco después de que el resto se haya movido.
    @State private var lyricsVisible = false
    @Namespace private var ns

    var body: some View {
        // El fondo va en `.background` y no como hermano en un ZStack: la carátula difuminada
        // (scaledToFill) es más ancha que la pantalla y, dentro de un ZStack, ensanchaba todo el
        // contenido y lo cortaba por los lados.
        GeometryReader { geo in
            if let track = player.currentTrack {
                if geo.size.width > geo.size.height {
                    landscape(track: track, size: geo.size)
                } else {
                    portrait(track: track, size: geo.size)
                }
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

    // MARK: - Disposiciones
    //
    // Sin scroll y con bloques de alto constante, así que nada se mueve al cambiar de canción.
    // Al abrir la letra no hay fundidos entre pantallas: la carátula, los títulos y los botones
    // se desplazan a su nuevo sitio (matchedGeometryEffect), la barra y los controles suben por
    // el propio reajuste, las tarjetas se encogen con desenfoque y la letra aparece al final.

    /// Curva lenta de la transición.
    private let slow = Animation.easeInOut(duration: 0.85)

    private func portrait(track: Track, size: CGSize) -> some View {
        let lyrics = showLyrics && track.hasLyrics == true
        // ~340 pt es lo que ocupa todo lo demás (info, barra, controles, tarjetas y márgenes).
        let artworkSide = max(120, min(size.width - 48, size.height - 340))

        return VStack(spacing: 20) {
            if lyrics {
                header(track: track)
                lyricsPanel(track: track)
            } else {
                Spacer(minLength: 0)
                artwork(track: track, side: artworkSide)
                info(track: track)
            }
            progress
            controls
            badges(track: track, collapsed: lyrics)
                .padding(.top, lyrics ? -20 : 0)
            if !lyrics {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .frame(width: size.width, height: size.height)
    }

    private func landscape(track: Track, size: CGSize) -> some View {
        let lyrics = showLyrics && track.hasLyrics == true
        let artworkSide = max(120, min(size.height - 52, size.width * 0.42))

        return HStack(alignment: .center, spacing: 28) {
            if lyrics {
                VStack(spacing: 12) {
                    header(track: track)
                    Spacer(minLength: 0)
                    progress
                    controls
                }
                .frame(width: size.width * 0.42)
                .frame(maxHeight: .infinity)

                lyricsPanel(track: track)
            } else {
                artwork(track: track, side: artworkSide)

                VStack(spacing: 12) {
                    info(track: track)
                    progress
                    controls
                    badges(track: track, collapsed: false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .frame(width: size.width, height: size.height)
    }

    /// Letra con fundido y desenfoque; entra cuando el resto ya se ha colocado y sale enseguida.
    private func lyricsPanel(track: Track) -> some View {
        LyricsPanel(track: track)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
            .opacity(lyricsVisible ? 1 : 0)
            .blur(radius: lyricsVisible ? 0 : 14)
            .animation(
                lyricsVisible ? .easeOut(duration: 0.7) : .easeIn(duration: 0.2),
                value: lyricsVisible
            )
            .transition(.identity)
    }

    private var progress: some View {
        ProgressSection(clock: player.clock)
    }

    // MARK: - Piezas

    private func artwork(track: Track, side: CGFloat, radius: CGFloat = 10, shadow: Bool = true) -> some View {
        ArtworkView(key: track.artworkKey, pixels: side > 100 ? 900 : 200)
            .frame(width: side, height: side)
            .matchedGeometryEffect(id: "art", in: ns)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Color.black.opacity(shadow ? 0.35 : 0), radius: shadow ? 18 : 0, y: shadow ? 10 : 0)
            .trackActions(track, swipe: false)
            .transition(.identity)
    }

    private func starButton(track: Track) -> some View {
        let isFavorite = userData.isFavorite(track.id)

        return Button {
            userData.toggleFavorite(track.id)
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isFavorite ? Color.yellow : Color.white.opacity(0.8))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .matchedGeometryEffect(id: "star", in: ns)
        .transition(.identity)
        .accessibilityLabel(isFavorite ? "Quitar de favoritos" : "Añadir a favoritos")
    }

    /// Botón de letra, a la izquierda del título (la estrella queda a la derecha). Siempre ocupa
    /// su sitio; si la pista no tiene letra se oculta pero no mueve nada.
    private func lyricsToggle(track: Track) -> some View {
        let hasLyrics = track.hasLyrics == true

        return Button {
            toggleLyrics()
        } label: {
            Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.white.opacity(showLyrics ? 1 : 0.8))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .matchedGeometryEffect(id: "lyricsBtn", in: ns)
        .transition(.identity)
        .opacity(hasLyrics ? 1 : 0)
        .disabled(!hasLyrics)
        .accessibilityLabel("Letra")
        .accessibilityHidden(!hasLyrics)
    }

    /// Normal: letra | título y artista centrados | estrella.
    private func info(track: Track) -> some View {
        HStack(spacing: 8) {
            lyricsToggle(track: track)

            VStack(spacing: 4) {
                MarqueeText(text: track.title, font: .title3.bold(), color: .white, alignment: .center, fps: 60)
                MarqueeText(text: track.artist, font: .body, color: Color.white.opacity(0.75), alignment: .center, fps: 60)
            }
            .matchedGeometryEffect(id: "titles", in: ns)
            .transition(.identity)

            starButton(track: track)
        }
        .transition(.identity)
    }

    /// Con la letra abierta: carátula pequeña | título y artista | letra | estrella.
    private func header(track: Track) -> some View {
        HStack(spacing: 10) {
            artwork(track: track, side: 56, radius: 8, shadow: false)

            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(text: track.title, font: .headline, color: .white, fps: 60)
                MarqueeText(text: track.artist, font: .subheadline, color: Color.white.opacity(0.75), fps: 60)
            }
            .matchedGeometryEffect(id: "titles", in: ns)
            .transition(.identity)

            lyricsToggle(track: track)
            starButton(track: track)
        }
        .transition(.identity)
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
            withAnimation(slow) { showLyrics = false }
        } else {
            withAnimation(slow) { showLyrics = true }
            // La letra entra cuando el resto ya se ha colocado.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 550_000_000)
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
        .scaleEffect(collapsed ? 0.7 : 1)
        .blur(radius: collapsed ? 12 : 0)
        .opacity(collapsed ? 0 : 1)
        .frame(height: collapsed ? 0 : 54)
        .clipped()
        .allowsHitTesting(!collapsed)
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
