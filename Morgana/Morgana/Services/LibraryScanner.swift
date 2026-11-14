import Foundation

enum LibraryScanner {
    /// Cuántos archivos se procesan antes de ceder el hilo y avisar del progreso.
    private static let batchSize = 50

    /// Recorre una carpeta (y subcarpetas) buscando archivos .flac y lee sus metadatos por lotes.
    ///
    /// - Cada archivo se procesa dentro de un `autoreleasepool`, de modo que los objetos temporales
    ///   (FileHandle, Data, UIImage...) se liberan al terminar el archivo y no al final del escaneo.
    /// - Entre lote y lote se cede el hilo con `Task.yield()`, así el escaneo es cooperativo.
    static func scan(
        folderURL: URL,
        folderID: UUID,
        previousIDs: [String: UUID],
        progress: @escaping @Sendable (_ done: Int, _ total: Int) -> Void
    ) async -> [Track] {
        let paths = listFLACFiles(in: folderURL)
        let total = paths.count
        progress(0, total)

        var tracks: [Track] = []
        tracks.reserveCapacity(total)

        var start = 0
        while start < total {
            if Task.isCancelled { break }
            let end = min(start + batchSize, total)

            for path in paths[start..<end] {
                autoreleasepool {
                    if let track = makeTrack(
                        relativePath: path,
                        folderURL: folderURL,
                        folderID: folderID,
                        previousIDs: previousIDs
                    ) {
                        tracks.append(track)
                    }
                }
            }

            start = end
            progress(start, total)
            await Task.yield()
        }

        return tracks
    }

    private static func listFLACFiles(in folderURL: URL) -> [String] {
        var result: [String] = []
        autoreleasepool {
            guard let enumerator = FileManager.default.enumerator(atPath: folderURL.path) else { return }
            while let relativePath = enumerator.nextObject() as? String {
                let name = (relativePath as NSString).lastPathComponent
                if name.hasPrefix(".") {
                    enumerator.skipDescendants()
                    continue
                }
                if name.lowercased().hasSuffix(".flac") {
                    result.append(relativePath)
                }
            }
        }
        return result
    }

    private static func makeTrack(
        relativePath: String,
        folderURL: URL,
        folderID: UUID,
        previousIDs: [String: UUID]
    ) -> Track? {
        let fileURL = folderURL.appendingPathComponent(relativePath)
        guard let meta = FLACParser.parse(url: fileURL) else { return nil }

        let fileName = (relativePath as NSString).lastPathComponent
        let fallbackTitle = (fileName as NSString).deletingPathExtension

        let artistList = meta.artists.isEmpty ? [Unknown.artist] : meta.artists
        let albumArtistList = meta.albumArtists.isEmpty ? artistList : meta.albumArtists
        let artist = artistList.joined(separator: ", ")
        let albumArtist = albumArtistList.joined(separator: ", ")
        let album = meta.album.isEmpty ? Unknown.album : meta.album
        let artworkKey = ArtworkStore.key(albumArtist: albumArtist, album: album)

        // Solo se carga la imagen si ese álbum aún no tiene carátula guardada.
        if let ref = meta.picture,
           !ArtworkStore.exists(key: artworkKey),
           let data = FLACParser.readPicture(url: fileURL, ref: ref) {
            ArtworkStore.save(data, key: artworkKey)
        }

        let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        var bitrate: Int?
        if fileSize > 0, meta.duration > 0 {
            bitrate = Int((Double(fileSize) * 8 / meta.duration / 1000).rounded())
        }

        return Track(
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
            artworkKey: artworkKey,
            bitrateKbps: bitrate,
            genres: meta.genres.isEmpty ? nil : meta.genres,
            artists: artistList,
            albumArtists: albumArtistList,
            hasLyrics: meta.hasLyrics ? true : nil
        )
    }
}
