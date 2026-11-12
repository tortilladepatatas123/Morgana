import SwiftUI

struct SongsView: View {
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var player: PlayerManager
    @State private var query = ""

    private var filtered: [Track] {
        guard !query.isEmpty else { return store.tracks }
        return store.tracks.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.artist.localizedCaseInsensitiveContains(query)
                || $0.album.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        let items = filtered

        NavigationStack {
            Group {
                if store.tracks.isEmpty {
                    EmptyLibraryView()
                } else {
                    List {
                        Button {
                            player.play(tracks: items, shuffle: true)
                        } label: {
                            Label("Reproducir aleatorio", systemImage: "shuffle")
                                .font(.headline)
                        }
                        .disabled(items.isEmpty)

                        ForEach(Array(items.enumerated()), id: \.element.id) { index, track in
                            Button {
                                player.play(tracks: items, startAt: index)
                            } label: {
                                TrackRow(track: track, isCurrent: player.currentTrack?.id == track.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $query, prompt: "Buscar canciones, artistas o álbumes")
                }
            }
            .navigationTitle("Canciones")
        }
        .miniPlayerInset()
    }
}
