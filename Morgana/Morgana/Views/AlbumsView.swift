import SwiftUI

struct AlbumsView: View {
    @EnvironmentObject var store: LibraryStore

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        NavigationStack {
            Group {
                if store.albums.isEmpty {
                    EmptyLibraryView()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(store.albums) { album in
                                NavigationLink {
                                    AlbumDetailView(album: album)
                                } label: {
                                    AlbumCell(album: album)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .miniPlayerBottomSpacing()
            .navigationTitle("Álbumes")
        }
        .miniPlayerInset()
    }
}

struct AlbumCell: View {
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ArtworkView(key: album.artworkKey, pixels: 400)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(album.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(album.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct AlbumDetailView: View {
    let album: Album
    @EnvironmentObject var player: PlayerManager

    private var subtitle: String {
        var parts = [album.artist]
        if !album.year.isEmpty { parts.append(album.year) }
        return parts.joined(separator: " • ")
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    ArtworkView(key: album.artworkKey, pixels: 800)
                        .frame(width: 240, height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(radius: 8, y: 4)

                    Text(album.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                    Text("\(album.tracks.count) canciones • \(formatTime(album.totalDuration))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        AlbumActionButton(title: "Reproducir", systemImage: "play.fill", prominent: true) {
                            player.play(tracks: album.tracks)
                        }
                        AlbumActionButton(title: "Aleatorio", systemImage: "shuffle") {
                            player.play(tracks: album.tracks, shuffle: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
            }

            Section {
                ForEach(Array(album.tracks.enumerated()), id: \.element.id) { index, track in
                    Button {
                        player.play(tracks: album.tracks, startAt: index)
                    } label: {
                        HStack(spacing: 12) {
                            Text(track.trackNumber > 0 ? "\(track.trackNumber)" : "–")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .trailing)
                            Text(track.title)
                                .foregroundStyle(player.currentTrack?.id == track.id ? Color.accentColor : Color.primary)
                                .lineLimit(1)
                            Spacer()
                            Text(formatTime(track.duration))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .trackActions(track)
                }
            }
        }
        .listStyle(.plain)
        .navigationBarTitleDisplayMode(.inline)
        .miniPlayerBottomSpacing()
    }
}

/// Botón propio (icono + texto en un HStack) para la cabecera del álbum.
/// Dentro de una `List`, `Label` + estilos bordered renderizaba mal el icono y
/// dos botones en la misma fila se disparaban a la vez.
struct AlbumActionButton: View {
    let title: String
    let systemImage: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                Text(title)
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(prominent ? Color.white : Color.accentColor)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(prominent ? Color.accentColor : Color(.secondarySystemFill))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
