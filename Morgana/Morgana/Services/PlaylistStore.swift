import Foundation
import SwiftUI

struct Playlist: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var trackIDs: [UUID]
    var createdAt: Date
}

/// Favoritos y listas de reproducción. Guardan ids de pista (que se conservan entre escaneos),
/// no copias de las pistas, y se persisten en un JSON propio, separado de la biblioteca.
@MainActor
final class PlaylistStore: ObservableObject {
    /// Ids favoritos, el más reciente primero.
    @Published private(set) var favorites: [UUID] = []
    @Published private(set) var playlists: [Playlist] = []

    private var favoriteSet: Set<UUID> = []

    private struct Snapshot: Codable {
        var favorites: [UUID]
        var playlists: [Playlist]
    }

    private static let storeURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("userdata.json")
    }()

    init() {
        load()
    }

    // MARK: - Favoritos

    func isFavorite(_ id: UUID) -> Bool {
        favoriteSet.contains(id)
    }

    func toggleFavorite(_ id: UUID) {
        if favoriteSet.contains(id) {
            favoriteSet.remove(id)
            favorites.removeAll { $0 == id }
        } else {
            favoriteSet.insert(id)
            favorites.insert(id, at: 0)
        }
        save()
    }

    /// Añade varias pistas a favoritos de una vez (las que ya lo eran se ignoran).
    /// Devuelve cuántas se añadieron de verdad.
    @discardableResult
    func addFavorites(_ ids: [UUID]) -> Int {
        var added: [UUID] = []
        var seen = Set<UUID>()
        for id in ids where !favoriteSet.contains(id) && seen.insert(id).inserted {
            added.append(id)
        }
        guard !added.isEmpty else { return 0 }
        favorites.insert(contentsOf: added, at: 0)
        favoriteSet.formUnion(added)
        save()
        return added.count
    }

    // MARK: - Listas

    func playlist(_ id: UUID) -> Playlist? {
        playlists.first { $0.id == id }
    }

    @discardableResult
    func createPlaylist(name: String, trackIDs: [UUID] = []) -> Playlist {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var unique: [UUID] = []
        for id in trackIDs where !unique.contains(id) { unique.append(id) }
        let playlist = Playlist(
            id: UUID(),
            name: clean.isEmpty ? "Lista nueva" : clean,
            trackIDs: unique,
            createdAt: Date()
        )
        playlists.append(playlist)
        save()
        return playlist
    }

    func rename(_ id: UUID, to name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[index].name = clean
        save()
    }

    func deletePlaylist(_ id: UUID) {
        playlists.removeAll { $0.id == id }
        save()
    }

    func deletePlaylists(at offsets: IndexSet) {
        playlists.remove(atOffsets: offsets)
        save()
    }

    /// Añade pistas al final de la lista, sin duplicarlas.
    func add(_ ids: [UUID], to playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        for id in ids where !playlists[index].trackIDs.contains(id) {
            playlists[index].trackIDs.append(id)
        }
        save()
    }

    func remove(_ ids: [UUID], from playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        let set = Set(ids)
        playlists[index].trackIDs.removeAll { set.contains($0) }
        save()
    }

    func setTrackIDs(_ ids: [UUID], for playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[index].trackIDs = ids
        save()
    }

    // MARK: - Persistencia

    private func load() {
        guard let data = try? Data(contentsOf: Self.storeURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        favorites = snapshot.favorites
        favoriteSet = Set(snapshot.favorites)
        playlists = snapshot.playlists
    }

    private func save() {
        let snapshot = Snapshot(favorites: favorites, playlists: playlists)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: Self.storeURL, options: .atomic)
    }
}
