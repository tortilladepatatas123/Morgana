import Foundation

enum Unknown {
    static let artist = "Artista desconocido"
    static let album = "Álbum desconocido"
    static let genre = "Sin género"
}

struct Genre: Identifiable, Hashable {
    let name: String
    let tracks: [Track]

    var id: String { name }
}

struct LibraryFolder: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var bookmark: Data
}

struct Track: Codable, Identifiable, Hashable {
    let id: UUID
    var folderID: UUID
    var relativePath: String
    var title: String
    var artist: String
    var albumArtist: String
    var album: String
    var year: String
    var trackNumber: Int
    var discNumber: Int
    var duration: Double
    var sampleRate: Int
    var bitsPerSample: Int
    var artworkKey: String
    /// Opcional para que bibliotecas guardadas sin este dato sigan cargando.
    var bitrateKbps: Int?
    var genres: [String]?
    /// Todos los artistas de la pista (etiquetas múltiples). `artist` es la versión para mostrar, unida con comas.
    var artists: [String]?
    var albumArtists: [String]?
    var hasLyrics: Bool?

    var codecText: String { "FLAC" }

    var sampleRateText: String? {
        guard sampleRate > 0 else { return nil }
        let khz = Double(sampleRate) / 1000
        return khz.formatted(.number.precision(.fractionLength(0...1))) + " kHz"
    }

    var bitDepthText: String? {
        bitsPerSample > 0 ? "\(bitsPerSample) bit" : nil
    }

    var bitrateText: String? {
        guard let kbps = bitrateKbps, kbps > 0 else { return nil }
        return "\(kbps) kbps"
    }

    var formatDescription: String {
        [codecText, sampleRateText, bitDepthText, bitrateText]
            .compactMap { $0 }
            .joined(separator: " • ")
    }
}

struct Album: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    /// Artistas del álbum por separado; el álbum aparece bajo cada uno en la pestaña Artistas.
    let artistNames: [String]
    let year: String
    let artworkKey: String
    let tracks: [Track]

    var totalDuration: Double { tracks.reduce(0) { $0 + $1.duration } }
}

struct Artist: Identifiable, Hashable {
    let name: String
    let albums: [Album]

    var id: String { name }
    var trackCount: Int { albums.reduce(0) { $0 + $1.tracks.count } }
}

func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds.rounded())
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%d:%02d", m, s)
}
