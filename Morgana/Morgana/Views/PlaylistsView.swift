import SwiftUI

struct PlaylistsView: View {
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var userData: PlaylistStore
    @State private var showNew = false

    var body: some View {
        List {
            NavigationLink {
                FavoritesView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.title3)
                        .foregroundStyle(.yellow)
                        .frame(width: 48, height: 48)
                        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Favoritos")
                        Text("\(store.tracks(for: userData.favorites).count) canciones")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                ForEach(userData.playlists) { playlist in
                    NavigationLink {
                        PlaylistDetailView(playlistID: playlist.id)
                    } label: {
                        let tracks = store.tracks(for: playlist.trackIDs)
                        HStack(spacing: 12) {
                            ArtworkView(key: tracks.first?.artworkKey ?? "", pixels: 150)
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(playlist.name).lineLimit(1)
                                Text("\(tracks.count) canciones")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { userData.deletePlaylists(at: $0) }
            } header: {
                Text("Mis listas")
            } footer: {
                if userData.playlists.isEmpty {
                    Text("Crea una lista con el botón + o añade canciones desde su menú (mantén pulsada una canción).")
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Listas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNew = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNew) {
            PlaylistNameSheet(title: "Nueva lista", confirmTitle: "Crear") { name in
                userData.createPlaylist(name: name)
            }
        }
        .miniPlayerBottomSpacing()
    }
}

struct PlaylistDetailView: View {
    let playlistID: UUID

    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var player: PlayerManager
    @EnvironmentObject var userData: PlaylistStore
    @Environment(\.dismiss) private var dismiss
    @State private var showRename = false
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if let playlist = userData.playlist(playlistID) {
                content(for: playlist)
            } else {
                Text("Esta lista ya no existe.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .miniPlayerBottomSpacing()
    }

    private func content(for playlist: Playlist) -> some View {
        let tracks = store.tracks(for: playlist.trackIDs)

        return List {
            VStack(spacing: 12) {
                Text(playlist.name)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("\(tracks.count) canciones • \(formatTime(tracks.reduce(0) { $0 + $1.duration }))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    AlbumActionButton(title: "Reproducir", systemImage: "play.fill", prominent: true) {
                        player.play(tracks: tracks)
                    }
                    AlbumActionButton(title: "Aleatorio", systemImage: "shuffle") {
                        player.play(tracks: tracks, shuffle: true)
                    }
                }
                .disabled(tracks.isEmpty)
            }
            .frame(maxWidth: .infinity)
            .listRowSeparator(.hidden)

            if tracks.isEmpty {
                Text("La lista está vacía. Mantén pulsada una canción y elige «Añadir a una lista…».")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                Button {
                    player.play(tracks: tracks, startAt: index)
                } label: {
                    TrackRow(track: track, isCurrent: player.currentTrack?.id == track.id)
                }
                .buttonStyle(.plain)
                .trackActions(track, swipe: false)
            }
            .onDelete { offsets in
                userData.remove(offsets.map { tracks[$0].id }, from: playlistID)
            }
            .onMove { source, destination in
                var ids = tracks.map { $0.id }
                ids.move(fromOffsets: source, toOffset: destination)
                userData.setTrackIDs(ids, for: playlistID)
            }
        }
        .listStyle(.plain)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                EditButton()
                Menu {
                    Button {
                        showRename = true
                    } label: {
                        Label("Renombrar", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Eliminar lista", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showRename) {
            PlaylistNameSheet(title: "Renombrar lista", confirmTitle: "Guardar", initialName: playlist.name) { name in
                userData.rename(playlistID, to: name)
            }
        }
        .confirmationDialog("¿Eliminar «\(playlist.name)»?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Eliminar lista", role: .destructive) {
                userData.deletePlaylist(playlistID)
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Las canciones no se borran de tu biblioteca.")
        }
    }
}
