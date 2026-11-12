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
                Text("\(track.artist) · \(track.album)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

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
                Text("Ve a la pestaña Carpetas y añade la carpeta donde guardas tus archivos FLAC.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
