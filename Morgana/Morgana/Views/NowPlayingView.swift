import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var player: PlayerManager
    @EnvironmentObject var userData: PlaylistStore

    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0
    @State private var palette = ArtworkPalette.fallback
    @State private var showLyrics = false

    private var displayedTime: Double {
        isScrubbing ? scrubValue : player.currentTime
    }

    var body: some View {
        ZStack {
            NowPlayingBackground(palette: palette, artworkKey: player.currentTrack?.artworkKey)

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

    private func portrait(track: Track, size: CGSize) -> some View {
        let artworkSide = min(size.width - 48, max(150, size.height * 0.36))

        return VStack(spacing: 20) {
            Spacer(minLength: 8)

            artwork(track: track, side: artworkSide)

            info(track: track)

            progressSection

            controls

            badges(track: track)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(width: size.width, height: size.height)
    }

    private func landscape(track: Track, size: CGSize) -> some View {
        let artworkSide = min(size.height - 48, size.width * 0.44)

        return HStack(spacing: 32) {
            artwork(track: track, side: max(artworkSide, 120))

            VStack(spacing: 14) {
                info(track: track)
                progressSection
                controls
                badges(track: track)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Piezas

    private func artwork(track: Track, side: CGFloat) -> some View {
        ArtworkView(key: track.artworkKey, pixels: 900)
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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

    private var progressSection: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { displayedTime },
                    set: { scrubValue = $0 }
                ),
                in: 0...max(player.duration, 1),
                onEditingChanged: { editing in
                    if editing {
                        scrubValue = player.currentTime
                        isScrubbing = true
                        player.beginScrubbing()
                    } else {
                        player.endScrubbing(at: scrubValue)
                        isScrubbing = false
                    }
                }
            )
            .tint(.white)

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
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 46))
                    .frame(width: 56, height: 56)
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
        .buttonStyle(.plain)
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
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                InfoCard(title: "Códec", value: track.codecText)
                if let value = track.sampleRateText { InfoCard(title: "Frecuencia", value: value) }
                if let value = track.bitDepthText { InfoCard(title: "Profundidad", value: value) }
                if let value = track.bitrateText { InfoCard(title: "Bitrate", value: value) }
            }

            // Solo aparece si el archivo trae letra incrustada.
            if track.hasLyrics == true {
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
            }
        }
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

            if let blurred {
                Image(uiImage: blurred)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 60)
                    .opacity(0.35)
                    .transition(.opacity)
            }

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
