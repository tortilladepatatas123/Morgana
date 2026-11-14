import SwiftUI

/// Lista de pistas reutilizable: Canciones, Favoritos y cada género.
/// No lleva NavigationStack propio: siempre se abre desde otra pantalla.
struct TrackListView: View {
    let title: String
    let tracks: [Track]
    var emptyText = "No hay canciones."

    @EnvironmentObject var player: PlayerManager
    @State private var query = ""

    private var filtered: [Track] {
        guard !query.isEmpty else { return tracks }
        return tracks.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.artist.localizedCaseInsensitiveContains(query)
                || $0.album.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        let items = filtered

        Group {
            if tracks.isEmpty {
                Text(emptyText)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    HStack(spacing: 12) {
                        AlbumActionButton(title: "Reproducir", systemImage: "play.fill", prominent: true) {
                            player.play(tracks: items)
                        }
                        AlbumActionButton(title: "Aleatorio", systemImage: "shuffle") {
                            player.play(tracks: items, shuffle: true)
                        }
                    }
                    .disabled(items.isEmpty)
                    .listRowSeparator(.hidden)

                    ForEach(Array(items.enumerated()), id: \.element.id) { index, track in
                        Button {
                            player.play(tracks: items, startAt: index)
                        } label: {
                            TrackRow(track: track, isCurrent: player.currentTrack?.id == track.id)
                        }
                        .buttonStyle(.plain)
                        .trackActions(track)
                    }
                }
                .listStyle(.plain)
                .searchable(text: $query, prompt: "Buscar en \(title)")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .miniPlayerBottomSpacing()
    }
}

struct FavoritesView: View {
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var userData: PlaylistStore

    var body: some View {
        TrackListView(
            title: "Favoritos",
            tracks: store.tracks(for: userData.favorites),
            emptyText: "Todavía no tienes favoritos.\nMarca una canción con la estrella para verla aquí."
        )
    }
}
