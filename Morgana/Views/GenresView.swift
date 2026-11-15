import SwiftUI

struct GenresView: View {
    @EnvironmentObject var store: LibraryStore

    var body: some View {
        Group {
            if store.genres.isEmpty {
                Text("Aún no hay géneros.\nSe leen de la etiqueta GENRE de tus archivos FLAC.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.genres) { genre in
                    NavigationLink {
                        GenreDetailView(genre: genre)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "guitars")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                MarqueeText(text: genre.name, color: Color.primary)
                                Text("\(genre.tracks.count) canciones")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Géneros")
        .navigationBarTitleDisplayMode(.inline)
        .miniPlayerBottomSpacing()
    }
}

enum GenreGrouping: String {
    case songs
    case albums
}

/// Contenido de un género, agrupado por canción o por álbum, con acciones para añadir todo
/// a favoritos o a una lista. En modo álbumes se muestra igual que la pestaña Álbumes.
struct GenreDetailView: View {
    let genre: Genre

    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var player: PlayerManager
    @EnvironmentObject var userData: PlaylistStore
    @AppStorage("genreGrouping") private var grouping: GenreGrouping = .songs
    @State private var showAddToPlaylist = false
    @State private var toast: String?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    /// Álbumes completos que tienen alguna pista de este género.
    private var genreAlbums: [Album] {
        let keys = Set(genre.tracks.map { $0.artworkKey })
        return store.albums.filter { keys.contains($0.id) }
    }

    private var queue: [Track] {
        if grouping == .albums {
            let ids = Set(genre.tracks.map { $0.id })
            return genreAlbums.flatMap { $0.tracks.filter { ids.contains($0.id) } }
        }
        return genre.tracks
    }

    private var header: some View {
        VStack(spacing: 12) {
            Picker("Agrupar por", selection: $grouping) {
                Text("Canciones").tag(GenreGrouping.songs)
                Text("Álbumes").tag(GenreGrouping.albums)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                AlbumActionButton(title: "Reproducir", systemImage: "play.fill", prominent: true) {
                    player.play(tracks: queue)
                }
                AlbumActionButton(title: "Aleatorio", systemImage: "shuffle") {
                    player.play(tracks: queue, shuffle: true)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if grouping == .songs {
            List {
                header
                    .listRowSeparator(.hidden)
                ForEach(Array(genre.tracks.enumerated()), id: \.element.id) { index, track in
                    row(track: track, queue: genre.tracks, index: index)
                }
            }
            .listStyle(.plain)
        } else {
            ScrollView {
                header
                    .padding([.horizontal, .top])
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(genreAlbums) { album in
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

    var body: some View {
        content
        .navigationTitle(genre.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        addAllToFavorites()
                    } label: {
                        Label("Añadir todo a favoritos", systemImage: "star")
                    }
                    Button {
                        showAddToPlaylist = true
                    } label: {
                        Label("Añadir todo a una lista…", systemImage: "text.badge.plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistSheet(trackIDs: genre.tracks.map { $0.id })
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: toast)
        .miniPlayerBottomSpacing()
    }

    private func row(track: Track, queue: [Track], index: Int) -> some View {
        Button {
            player.play(tracks: queue, startAt: index)
        } label: {
            TrackRow(track: track, isCurrent: player.currentTrack?.id == track.id)
        }
        .buttonStyle(.plain)
        .trackActions(track)
    }

    private func addAllToFavorites() {
        let added = userData.addFavorites(genre.tracks.map { $0.id })
        toast = added == 0
            ? "Ya estaban todas en favoritos"
            : "\(added) \(added == 1 ? "canción añadida" : "canciones añadidas") a favoritos"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            toast = nil
        }
    }
}
