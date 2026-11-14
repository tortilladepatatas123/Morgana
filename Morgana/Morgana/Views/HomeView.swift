import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var userData: PlaylistStore
    @State private var query = ""

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Group {
                if trimmedQuery.isEmpty {
                    quickAccess
                } else {
                    SearchResultsView(query: trimmedQuery)
                }
            }
            .miniPlayerBottomSpacing()
            .navigationTitle("Inicio")
            .searchable(text: $query, prompt: "Canciones, álbumes, artistas…")
        }
        .miniPlayerInset()
    }

    private var quickAccess: some View {
        ScrollView {
            VStack(spacing: 20) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    NavigationLink {
                        TrackListView(title: "Canciones", tracks: store.tracks)
                    } label: {
                        HomeCard(title: "Canciones", systemImage: "music.note", tint: .pink, subtitle: "\(store.tracks.count)")
                    }

                    NavigationLink {
                        FavoritesView()
                    } label: {
                        HomeCard(
                            title: "Favoritos",
                            systemImage: "star.fill",
                            tint: .yellow,
                            subtitle: "\(store.tracks(for: userData.favorites).count)"
                        )
                    }

                    NavigationLink {
                        GenresView()
                    } label: {
                        HomeCard(title: "Géneros", systemImage: "guitars", tint: .purple, subtitle: "\(store.genres.count)")
                    }

                    NavigationLink {
                        PlaylistsView()
                    } label: {
                        HomeCard(
                            title: "Listas",
                            systemImage: "music.note.list",
                            tint: .blue,
                            subtitle: "\(userData.playlists.count)"
                        )
                    }
                }
                .buttonStyle(.plain)

                if store.tracks.isEmpty {
                    EmptyLibraryView()
                        .frame(minHeight: 260)
                }
            }
            .padding(16)
        }
    }
}

private struct HomeCard: View {
    let title: String
    let systemImage: String
    let tint: Color
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

/// Resultados de la búsqueda de Inicio, agrupados por tipo.
private struct SearchResultsView: View {
    let query: String

    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var player: PlayerManager
    @EnvironmentObject var userData: PlaylistStore

    private static let songLimit = 50

    var body: some View {
        let songs = Array(
            store.tracks.lazy.filter {
                $0.title.localizedCaseInsensitiveContains(query)
                    || $0.artist.localizedCaseInsensitiveContains(query)
                    || $0.album.localizedCaseInsensitiveContains(query)
            }.prefix(Self.songLimit)
        )
        let albums = store.albums.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.artist.localizedCaseInsensitiveContains(query)
        }
        let artists = store.artists.filter { $0.name.localizedCaseInsensitiveContains(query) }
        let genres = store.genres.filter { $0.name.localizedCaseInsensitiveContains(query) }
        let playlists = userData.playlists.filter { $0.name.localizedCaseInsensitiveContains(query) }
        let isEmpty = songs.isEmpty && albums.isEmpty && artists.isEmpty && genres.isEmpty && playlists.isEmpty

        if isEmpty {
            Text("Sin resultados para «\(query)»")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                if !songs.isEmpty {
                    Section("Canciones") {
                        ForEach(Array(songs.enumerated()), id: \.element.id) { index, track in
                            Button {
                                player.play(tracks: songs, startAt: index)
                            } label: {
                                TrackRow(track: track, isCurrent: player.currentTrack?.id == track.id)
                            }
                            .buttonStyle(.plain)
                            .trackActions(track)
                        }
                    }
                }

                if !albums.isEmpty {
                    Section("Álbumes") {
                        ForEach(albums) { album in
                            NavigationLink {
                                AlbumDetailView(album: album)
                            } label: {
                                resultRow(artworkKey: album.artworkKey, title: album.title, subtitle: album.artist)
                            }
                        }
                    }
                }

                if !artists.isEmpty {
                    Section("Artistas") {
                        ForEach(artists) { artist in
                            NavigationLink {
                                ArtistDetailView(artist: artist)
                            } label: {
                                resultRow(
                                    artworkKey: artist.albums.first?.artworkKey ?? "",
                                    title: artist.name,
                                    subtitle: "\(artist.albums.count) álbumes"
                                )
                            }
                        }
                    }
                }

                if !genres.isEmpty {
                    Section("Géneros") {
                        ForEach(genres) { genre in
                            NavigationLink {
                                GenreDetailView(genre: genre)
                            } label: {
                                Label(genre.name, systemImage: "guitars")
                            }
                        }
                    }
                }

                if !playlists.isEmpty {
                    Section("Listas") {
                        ForEach(playlists) { playlist in
                            NavigationLink {
                                PlaylistDetailView(playlistID: playlist.id)
                            } label: {
                                Label(playlist.name, systemImage: "music.note.list")
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func resultRow(artworkKey: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ArtworkView(key: artworkKey, pixels: 150)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
