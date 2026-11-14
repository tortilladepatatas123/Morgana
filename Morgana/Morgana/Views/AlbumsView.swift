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
            MarqueeText(text: album.title, font: .subheadline.weight(.semibold), color: Color.primary)
            MarqueeText(text: album.artist, font: .caption, color: Color.secondary)
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

    /// Pistas agrupadas por disco, conservando su posición en la cola de reproducción.
    private var discs: [(number: Int, items: [(index: Int, track: Track)])] {
        var order: [Int] = []
        var groups: [Int: [(index: Int, track: Track)]] = [:]
        for (index, track) in album.tracks.enumerated() {
            let n = max(track.discNumber, 1)
            if groups[n] == nil { order.append(n) }
            groups[n, default: []].append((index, track))
        }
        return order.sorted().map { (number: $0, items: groups[$0] ?? []) }
    }

    private func trackRow(_ track: Track, index: Int) -> some View {
        Button {
            player.play(tracks: album.tracks, startAt: index)
        } label: {
            HStack(spacing: 12) {
                Text(track.trackNumber > 0 ? "\(track.trackNumber)" : "–")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .trailing)
                MarqueeText(
                    text: track.title,
                    color: player.currentTrack?.id == track.id ? Color.accentColor : Color.primary
                )
                Text(formatTime(track.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .trackActions(track)
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

            if discs.count > 1 {
                ForEach(discs, id: \.number) { disc in
                    Section {
                        ForEach(disc.items, id: \.index) { item in
                            trackRow(item.track, index: item.index)
                        }
                    } header: {
                        Text("Disco \(disc.number)")
                            .textCase(nil)
                            .font(.subheadline.weight(.semibold))
                    }
                }
            } else {
                Section {
                    ForEach(Array(album.tracks.enumerated()), id: \.element.id) { index, track in
                        trackRow(track, index: index)
                    }
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
