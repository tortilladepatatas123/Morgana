import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var player: PlayerManager
    @EnvironmentObject var userData: PlaylistStore

    @State private var palette = ArtworkPalette.fallback
    @State private var showLyrics = false

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
        .sheet(isPresented: $showLyrics) {
            if let track = player.currentTrack {
                LyricsSheet(track: track)
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
    // Las dos son fijas: no hay scroll y todos los bloques tienen un alto constante (también el
    // botón de Letra, que reserva su hueco aunque la pista no tenga letra), así que nada se mueve
    // al cambiar de canción. La carátula es lo único que se adapta al espacio disponible.

    private func portrait(track: Track, size: CGSize) -> some View {
        // ~390 pt es lo que ocupa todo lo demás (info, barra, controles, tarjetas, letra y márgenes).
        let artworkSide = max(120, min(size.width - 48, size.height - 390))

        return VStack(spacing: 20) {
            Spacer(minLength: 0)
            artwork(track: track, side: artworkSide)
            info(track: track)
            ProgressSection(clock: player.clock)
            controls
            badges(track: track)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .frame(width: size.width, height: size.height)
    }

    private func landscape(track: Track, size: CGSize) -> some View {
        let artworkSide = max(120, min(size.height - 52, size.width * 0.42))

        // Dos columnas: carátula a la izquierda; información y controles a la derecha.
        return HStack(alignment: .center, spacing: 28) {
            artwork(track: track, side: artworkSide)

            VStack(spacing: 12) {
                info(track: track)
                ProgressSection(clock: player.clock)
                controls
                badges(track: track)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Piezas

    private func artwork(track: Track, side: CGFloat) -> some View {
        ArtworkView(key: track.artworkKey, pixels: 900)
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: Color.black.opacity(0.35), radius: 18, y: 10)
            .trackActions(track, swipe: false)
    }

    private func info(track: Track) -> some View {
        let isFavorite = userData.isFavorite(track.id)

        return HStack(spacing: 8) {
            // Hueco del mismo ancho que la estrella para que los títulos sigan centrados.
            Color.clear.frame(width: 36, height: 36)

            VStack(spacing: 4) {
                MarqueeText(text: track.title, font: .title3.bold(), color: .white, alignment: .center)
                MarqueeText(text: track.artist, font: .body, color: Color.white.opacity(0.75), alignment: .center)
            }

            Button {
                userData.toggleFavorite(track.id)
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isFavorite ? Color.yellow : Color.white.opacity(0.8))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "Quitar de favoritos" : "Añadir a favoritos")
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

    private func badges(track: Track) -> some View {
        let hasLyrics = track.hasLyrics == true

        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                InfoCard(title: "Códec", value: track.codecText)
                if let value = track.sampleRateText { InfoCard(title: "Frecuencia", value: value) }
                if let value = track.bitDepthText { InfoCard(title: "Profundidad", value: value) }
                if let value = track.bitrateText { InfoCard(title: "Bitrate", value: value) }
            }

            // El botón siempre ocupa su sitio; si la pista no tiene letra se oculta pero no mueve nada.
            Button {
                showLyrics = true
            } label: {
                Label("Letra", systemImage: "quote.bubble")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.16)))
            }
            .buttonStyle(.plain)
            .opacity(hasLyrics ? 1 : 0)
            .disabled(!hasLyrics)
            .accessibilityHidden(!hasLyrics)
        }
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

            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))
                Capsule().fill(Color.white).frame(width: width * fraction)
            }
            .frame(height: isDragging ? 10 : 6)
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
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.6))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
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
