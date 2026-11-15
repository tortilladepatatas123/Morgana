import Foundation
import SwiftUI

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var folders: [LibraryFolder] = []
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var albums: [Album] = []
    @Published private(set) var artists: [Artist] = []
    @Published private(set) var isScanning = false
    @Published private(set) var scanStatus = ""
    @Published private(set) var genres: [Genre] = []
    @Published var errorMessage: String?

    /// Acceso rápido por id, para resolver favoritos y listas de reproducción.
    private(set) var trackIndex: [UUID: Track] = [:]

    private var folderURLs: [UUID: URL] = [:]

    private struct Snapshot: Codable {
        var folders: [LibraryFolder]
        var tracks: [Track]
    }

    private static let storeURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("library.json")
    }()

    init() {
        load()
        resolveFolders()
        rebuildIndexes()
    }

    // MARK: - Acceso a archivos

    func url(for track: Track) -> URL? {
        folderURLs[track.folderID]?.appendingPathComponent(track.relativePath)
    }

    // MARK: - Carpetas

    func addFolder(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()

        if let existing = folders.first(where: { folderURLs[$0.id]?.standardizedFileURL == url.standardizedFileURL }) {
            if accessed { url.stopAccessingSecurityScopedResource() }
            rescan(folderID: existing.id)
            return
        }

        do {
            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            let folder = LibraryFolder(id: UUID(), name: url.lastPathComponent, bookmark: bookmark)
            folders.append(folder)
            folderURLs[folder.id] = url
            save()
            rescan(folderID: folder.id)
        } catch {
            if accessed { url.stopAccessingSecurityScopedResource() }
            errorMessage = "No se pudo guardar el acceso a la carpeta: \(error.localizedDescription)"
        }
    }

    func removeFolders(at offsets: IndexSet) {
        let removed = offsets.map { folders[$0] }
        for folder in removed {
            folderURLs[folder.id]?.stopAccessingSecurityScopedResource()
            folderURLs[folder.id] = nil
        }
        let ids = Set(removed.map { $0.id })
        folders.removeAll { ids.contains($0.id) }
        tracks.removeAll { ids.contains($0.folderID) }
        rebuildIndexes()
        save()
    }

    // MARK: - Escaneo

    func rescan(folderID: UUID? = nil) {
        guard !isScanning else { return }

        let targets = folders.filter { folderID == nil || $0.id == folderID }
        var jobs: [(id: UUID, url: URL, previous: [String: UUID])] = []
        for folder in targets {
            guard let url = folderURLs[folder.id] else { continue }
            let previous = Dictionary(
                tracks.filter { $0.folderID == folder.id }.map { ($0.relativePath, $0.id) },
                uniquingKeysWith: { first, _ in first }
            )
            jobs.append((folder.id, url, previous))
        }
        guard !jobs.isEmpty else { return }

        isScanning = true
        scanStatus = "Escaneando…"

        Task {
            var results: [UUID: [Track]] = [:]
            for job in jobs {
                let found = await Task.detached(priority: .utility) {
                    await LibraryScanner.scan(folderURL: job.url, folderID: job.id, previousIDs: job.previous) { done, total in
                        Task { @MainActor [weak self] in
                            self?.scanStatus = "Escaneando… \(done) de \(total)"
                        }
                    }
                }.value
                results[job.id] = found
            }

            let scanned = Set(results.keys)
            tracks = tracks.filter { !scanned.contains($0.folderID) } + results.values.flatMap { $0 }
            isScanning = false
            scanStatus = ""
            rebuildIndexes()
            save()
        }
    }

    // MARK: - Índices (álbumes y artistas)

    private func rebuildIndexes() {
        tracks.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        trackIndex = Dictionary(tracks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        genres = Self.makeGenres(from: tracks)

        let grouped = Dictionary(grouping: tracks, by: { $0.artworkKey })
        albums = grouped.values.map { group in
            let ordered = group.sorted { a, b in
                if a.discNumber != b.discNumber { return a.discNumber < b.discNumber }
                if a.trackNumber != b.trackNumber { return a.trackNumber < b.trackNumber }
                return a.title.localizedStandardCompare(b.title) == .orderedAscending
            }
            let first = ordered[0]
            let year = ordered.map { $0.year }.first(where: { !$0.isEmpty }) ?? ""
            return Album(
                id: first.artworkKey,
                title: first.album,
                artist: first.albumArtist,
                artistNames: first.albumArtists ?? [first.albumArtist],
                year: year,
                artworkKey: first.artworkKey,
                tracks: ordered
            )
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }

        // Un álbum con varios artistas aparece bajo cada uno de ellos.
        var byArtist: [String: [Album]] = [:]
        for album in albums {
            for name in album.artistNames {
                byArtist[name, default: []].append(album)
            }
        }
        artists = byArtist.map { name, albums in
            Artist(
                name: name,
                albums: albums.sorted { a, b in
                    if a.year != b.year { return a.year < b.year }
                    return a.title.localizedStandardCompare(b.title) == .orderedAscending
                }
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Pistas de la biblioteca a partir de sus ids, en el mismo orden. Ignora las que ya no existen.
    func tracks(for ids: [UUID]) -> [Track] {
        ids.compactMap { trackIndex[$0] }
    }

    private static func makeGenres(from tracks: [Track]) -> [Genre] {
        var displayNames: [String: String] = [:]
        var grouped: [String: [Track]] = [:]

        for track in tracks {
            let names = track.genres ?? []
            if names.isEmpty {
                displayNames[Unknown.genre.lowercased()] = Unknown.genre
                grouped[Unknown.genre.lowercased(), default: []].append(track)
            } else {
                for name in names {
                    let key = name.lowercased()
                    if displayNames[key] == nil { displayNames[key] = name }
                    grouped[key, default: []].append(track)
                }
            }
        }

        return grouped
            .map { Genre(name: displayNames[$0.key] ?? $0.key, tracks: $0.value) }
            .sorted { a, b in
                if a.name == Unknown.genre { return false }
                if b.name == Unknown.genre { return true }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
    }

    // MARK: - Persistencia

    private func load() {
        guard let data = try? Data(contentsOf: Self.storeURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        folders = snapshot.folders
        tracks = snapshot.tracks
    }

    private func save() {
        let snapshot = Snapshot(folders: folders, tracks: tracks)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: Self.storeURL, options: .atomic)
    }

    private func resolveFolders() {
        for index in folders.indices {
            var stale = false
            guard let url = try? URL(
                resolvingBookmarkData: folders[index].bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) else { continue }

            _ = url.startAccessingSecurityScopedResource()
            folderURLs[folders[index].id] = url

            if stale, let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                folders[index].bookmark = fresh
            }
        }
    }
}
