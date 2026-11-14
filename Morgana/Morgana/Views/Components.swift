import SwiftUI

struct ArtworkView: View {
    let key: String
    var pixels: CGFloat = 300

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color(.secondarySystemFill))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .task(id: key) {
            let key = key
            let pixels = pixels
            image = await Task.detached(priority: .utility) {
                ArtworkStore.image(key: key, maxPixel: pixels)
            }.value
        }
    }
}

struct TrackRow: View {
    let track: Track
    let isCurrent: Bool

    @EnvironmentObject var userData: PlaylistStore

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(key: track.artworkKey, pixels: 150)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body)
                    .foregroundStyle(isCurrent ? Color.accentColor : Color.primary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if userData.isFavorite(track.id) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }

            Text(formatTime(track.duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

struct EmptyLibraryView: View {
    @EnvironmentObject var store: LibraryStore

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)

            if store.isScanning {
                ProgressView()
                Text(store.scanStatus)
                    .foregroundStyle(.secondary)
            } else {
                Text("Tu biblioteca está vacía")
                    .font(.title3.bold())
                Text("Ve a la pestaña Configuración y añade la carpeta donde guardas tus archivos FLAC.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Icono de play/pause con animación: los dos iconos se cruzan con escala, giro y fundido.
/// (Funciona en iOS 16; `contentTransition(.symbolEffect)` solo existe desde iOS 17.)
struct PlayPauseIcon: View {
    let isPlaying: Bool
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            Image(systemName: "pause.fill")
                .scaleEffect(isPlaying ? 1 : 0.4)
                .rotationEffect(.degrees(isPlaying ? 0 : -90))
                .opacity(isPlaying ? 1 : 0)

            Image(systemName: "play.fill")
                .scaleEffect(isPlaying ? 0.4 : 1)
                .rotationEffect(.degrees(isPlaying ? 90 : 0))
                .opacity(isPlaying ? 0 : 1)
        }
        .font(.system(size: size))
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: isPlaying)
    }
}

/// Botón sin estilo propio que se encoge un poco al pulsarlo.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
