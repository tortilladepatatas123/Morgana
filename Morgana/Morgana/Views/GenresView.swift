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
                                Text(genre.name).lineLimit(1)
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

/// Un álbum dentro de un género (solo con las pistas de ese género).
private struct AlbumGroup: Identifiable {
    let id: String
    let title: String
    let artist: String
    let tracks: [Track]
}

/// Contenido de un género, agrupado por canción o por álbum, con acciones para añadir todo
/// a favoritos o a una lista.
struct GenreDetailView: View {
    let genre: Genre

    @EnvironmentObject var player: PlayerManager
    @EnvironmentObject var userData: PlaylistStore
    @AppStorage("genreGrouping") private var grouping: GenreGrouping = .songs
    @State private var showAddToPlaylist = false
    @State private var toast: String?

    private var albumGroups: [AlbumGroup] {
        Dictionary(grouping: genre.tracks, by: { $0.artworkKey })
            .values
            .map { group in
                let ordered = group.sorted { a, b in
                    if a.discNumber != b.discNumber { return a.discNumber < b.discNumber }
                    if a.trackNumber != b.trackNumber { return a.trackNumber < b.trackNumber }
                    return a.title.localizedStandardCompare(b.title) == .orderedAscending
                }
                return AlbumGroup(
                    id: ordered[0].artworkKey,
                    title: ordered[0].album,
                    artist: ordered[0].albumArtist,
                    tracks: ordered
                )
            }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        let groups = grouping == .albums ? albumGroups : []
        // Orden de reproducción = orden en pantalla.
        let queue = grouping == .albums ? groups.flatMap { $0.tracks } : genre.tracks

        List {
            Picker("Agrupar por", selection: $grouping) {
                Text("Canciones").tag(GenreGrouping.songs)
                Text("Álbumes").tag(GenreGrouping.albums)
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)

            HStack(spacing: 12) {
                AlbumActionButton(title: "Reproducir", systemImage: "play.fill", prominent: true) {
                    player.play(tracks: queue)
                }
                AlbumActionButton(title: "Aleatorio", systemImage: "shuffle") {
                    player.play(tracks: queue, shuffle: true)
                }
            }
            .listRowSeparator(.hidden)

            if grouping == .songs {
                ForEach(Array(genre.tracks.enumerated()), id: \.element.id) { index, track in
                    row(track: track, queue: queue, index: index)
                }
            } else {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.tracks) { track in
                            row(track: track, queue: queue, index: queue.firstIndex(where: { $0.id == track.id }) ?? 0)
                        }
                    } header: {
                        HStack(spacing: 10) {
                            ArtworkView(key: group.id, pixels: 100)
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(group.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(group.artist)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.plain)
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
