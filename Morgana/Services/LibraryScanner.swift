import Foundation

enum LibraryScanner {
    /// Recorre una carpeta (y subcarpetas) buscando archivos .flac y lee sus metadatos.
    /// Es síncrona y está pensada para ejecutarse fuera del hilo principal.
    static func scan(
        folderURL: URL,
        folderID: UUID,
        previousIDs: [String: UUID],
        progress: @escaping (Int) -> Void
    ) -> [Track] {
        guard let enumerator = FileManager.default.enumerator(atPath: folderURL.path) else { return [] }

        var tracks: [Track] = []
        var found = 0

        while let relativePath = enumerator.nextObject() as? String {
            let components = relativePath.split(separator: "/")
            if components.contains(where: { $0.hasPrefix(".") }) { continue }
            guard relativePath.lowercased().hasSuffix(".flac") else { continue }

            let fileURL = folderURL.appendingPathComponent(relativePath)
            guard let meta = FLACParser.parse(url: fileURL) else { continue }

            let fileName = (relativePath as NSString).lastPathComponent
            let fallbackTitle = (fileName as NSString).deletingPathExtension

            let artist = meta.artist.isEmpty ? Unknown.artist : meta.artist
            let albumArtist = meta.albumArtist.isEmpty ? artist : meta.albumArtist
            let album = meta.album.isEmpty ? Unknown.album : meta.album
            let artworkKey = ArtworkStore.key(albumArtist: albumArtist, album: album)

            if let picture = meta.pictureData {
                ArtworkStore.saveIfNeeded(picture, key: artworkKey)
            }

            tracks.append(Track(
                id: previousIDs[relativePath] ?? UUID(),
                folderID: folderID,
                relativePath: relativePath,
                title: meta.title.isEmpty ? fallbackTitle : meta.title,
                artist: artist,
                albumArtist: albumArtist,
                album: album,
                year: String(meta.date.prefix(4)),
                trackNumber: meta.trackNumber,
                discNumber: meta.discNumber,
                duration: meta.duration,
                sampleRate: meta.sampleRate,
                bitsPerSample: meta.bitsPerSample,
                artworkKey: artworkKey
            ))

            found += 1
            if found % 25 == 0 { progress(found) }
        }

        progress(found)
        return tracks
    }
}
