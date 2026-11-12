import Foundation

enum Unknown {
    static let artist = "Artista desconocido"
    static let album = "Álbum desconocido"
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

    var formatDescription: String {
        var parts = ["FLAC"]
        if sampleRate > 0 { parts.append("\(Track.formatKHz(sampleRate)) kHz") }
        if bitsPerSample > 0 { parts.append("\(bitsPerSample) bit") }
        return parts.joined(separator: " · ")
    }

    private static func formatKHz(_ hz: Int) -> String {
        let k = Double(hz) / 1000
        if k.truncatingRemainder(dividingBy: 1) == 0 { return String(Int(k)) }
        return String(format: "%.1f", k)
    }
}

struct Album: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
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
