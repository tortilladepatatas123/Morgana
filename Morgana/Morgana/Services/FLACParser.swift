import Foundation

/// Posición de una imagen dentro del archivo. No se carga en memoria hasta que hace falta.
struct PictureRef {
    var offset: UInt64
    var length: Int
    var type: Int
}

struct FLACMetadata {
    var title = ""
    var artists: [String] = []
    var albumArtists: [String] = []
    var album = ""
    var date = ""
    var trackNumber = 0
    var discNumber = 0
    var sampleRate = 0
    var bitsPerSample = 0
    var duration: Double = 0
    var genres: [String] = []
    /// Verdadero si el archivo trae LYRICS o UNSYNCEDLYRICS (el texto solo se lee si se pide).
    var hasLyrics = false
    var lyricsPrimary: String?
    var lyricsFallback: String?
    var picture: PictureRef?

    /// LYRICS tiene prioridad sobre UNSYNCEDLYRICS.
    var lyrics: String? { lyricsPrimary ?? lyricsFallback }
}

/// Lector mínimo de metadatos FLAC: STREAMINFO, VORBIS_COMMENT y PICTURE.
/// No decodifica audio; de eso se encarga AVFoundation.
///
/// Para no disparar la memoria en bibliotecas grandes, de las carátulas solo se lee
/// la cabecera (unos pocos KB) y se anota dónde están los datos; la imagen se carga
/// después con `readPicture` y solo si todavía no está guardada.
enum FLACParser {
    private static let maxCommentBlock = 16 * 1024 * 1024
    private static let maxPictureBytes = 20 * 1024 * 1024
    private static let pictureHeaderBytes = 4096

    /// - Parameter collectLyrics: si es `true`, guarda también el texto de la letra (puede ser grande);
    ///   durante el escaneo se deja en `false` y solo se anota si existe.
    static func parse(url: URL, collectLyrics: Bool = false) -> FLACMetadata? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        guard let marker = try? handle.read(upToCount: 4),
              [UInt8](marker) == [0x66, 0x4C, 0x61, 0x43] else { return nil }  // "fLaC"

        var meta = FLACMetadata()
        var isLast = false

        while !isLast {
            guard let headerData = try? handle.read(upToCount: 4), headerData.count == 4 else { break }
            let h = [UInt8](headerData)
            isLast = (h[0] & 0x80) != 0
            let blockType = Int(h[0] & 0x7F)
            let length = (Int(h[1]) << 16) | (Int(h[2]) << 8) | Int(h[3])

            guard let blockStart = try? handle.offset() else { break }
            let blockEnd = blockStart + UInt64(length)

            if length > 0, blockType == 0 || (blockType == 4 && length <= maxCommentBlock) {
                guard let data = try? handle.read(upToCount: length), data.count == length else { break }
                let bytes = [UInt8](data)
                if blockType == 0 {
                    parseStreamInfo(bytes, into: &meta)
                } else {
                    parseVorbisComment(bytes, collectLyrics: collectLyrics, into: &meta)
                }
            } else if blockType == 6, length > 32 {
                if let prefix = try? handle.read(upToCount: min(length, pictureHeaderBytes)) {
                    parsePictureHeader([UInt8](prefix), blockStart: blockStart, blockLength: length, into: &meta)
                }
            }

            // Siempre dejamos el cursor al inicio del siguiente bloque.
            do { try handle.seek(toOffset: blockEnd) } catch { break }
        }

        return meta.sampleRate > 0 ? meta : nil
    }

    /// Texto crudo de la letra incrustada (LYRICS o UNSYNCEDLYRICS), o nil si no hay.
    static func lyrics(url: URL) -> String? {
        guard let text = parse(url: url, collectLyrics: true)?.lyrics,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    /// Lee los bytes de una carátula localizada con `parse`. Devuelve nil si es demasiado grande.
    static func readPicture(url: URL, ref: PictureRef) -> Data? {
        guard ref.length > 0, ref.length <= maxPictureBytes,
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: ref.offset)
            guard let data = try handle.read(upToCount: ref.length), data.count == ref.length else { return nil }
            return data
        } catch {
            return nil
        }
    }

    private static func parseStreamInfo(_ b: [UInt8], into meta: inout FLACMetadata) {
        guard b.count >= 18 else { return }
        let sr1 = Int(b[10]) << 12
        let sr2 = Int(b[11]) << 4
        let sr3 = Int(b[12]) >> 4
        let sampleRate = sr1 | sr2 | sr3

        let bpsHigh = Int(b[12] & 0x01) << 4
        let bpsLow = Int(b[13]) >> 4
        let bitsPerSample = (bpsHigh | bpsLow) + 1

        var total = Int(b[13] & 0x0F) << 32
        total |= Int(b[14]) << 24
        total |= Int(b[15]) << 16
        total |= Int(b[16]) << 8
        total |= Int(b[17])

        meta.sampleRate = sampleRate
        meta.bitsPerSample = bitsPerSample
        if sampleRate > 0 { meta.duration = Double(total) / Double(sampleRate) }
    }

    /// Añade uno o varios valores a una lista. Una misma etiqueta puede repetirse
    /// (ARTIST=A, ARTIST=B) o traer varios valores separados por «;» (ARTIST=A; B).
    /// Se ignoran duplicados sin distinguir mayúsculas. No se separa por «/» ni «,»
    /// porque rompería nombres como AC/DC o «Earth, Wind & Fire».
    private static func appendValues(_ value: String, to list: inout [String]) {
        for part in value.split(whereSeparator: { $0 == ";" || $0 == "\u{0}" }) {
            let item = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if !item.isEmpty, !list.contains(where: { $0.caseInsensitiveCompare(item) == .orderedSame }) {
                list.append(item)
            }
        }
    }

    private static func parseVorbisComment(_ b: [UInt8], collectLyrics: Bool, into meta: inout FLACMetadata) {
        var pos = 0

        func u32() -> Int? {
            guard pos + 4 <= b.count else { return nil }
            let v = Int(b[pos]) | (Int(b[pos + 1]) << 8) | (Int(b[pos + 2]) << 16) | (Int(b[pos + 3]) << 24)
            pos += 4
            return v
        }

        guard let vendorLength = u32(), pos + vendorLength <= b.count else { return }
        pos += vendorLength
        guard let count = u32() else { return }

        for _ in 0..<count {
            guard let length = u32(), pos + length <= b.count else { break }
            let entry = String(decoding: b[pos..<(pos + length)], as: UTF8.self)
            pos += length

            guard let eq = entry.firstIndex(of: "=") else { continue }
            let key = entry[..<eq].uppercased()
            let value = String(entry[entry.index(after: eq)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty { continue }

            switch key {
            case "TITLE": if meta.title.isEmpty { meta.title = value }
            case "ARTIST", "ARTISTS": appendValues(value, to: &meta.artists)
            case "ALBUMARTIST", "ALBUM ARTIST", "ALBUMARTISTS": appendValues(value, to: &meta.albumArtists)
            case "ALBUM": if meta.album.isEmpty { meta.album = value }
            case "DATE", "YEAR": if meta.date.isEmpty { meta.date = value }
            case "GENRE": appendValues(value, to: &meta.genres)
            case "LYRICS":
                meta.hasLyrics = true
                if collectLyrics, meta.lyricsPrimary == nil { meta.lyricsPrimary = value }
            case "UNSYNCEDLYRICS", "UNSYNCED LYRICS":
                meta.hasLyrics = true
                if collectLyrics, meta.lyricsFallback == nil { meta.lyricsFallback = value }
            case "TRACKNUMBER": if meta.trackNumber == 0 { meta.trackNumber = leadingInt(value) }
            case "DISCNUMBER": if meta.discNumber == 0 { meta.discNumber = leadingInt(value) }
            default: break
            }
        }
    }

    /// Lee solo la cabecera del bloque PICTURE y anota dónde empiezan los datos de la imagen.
    private static func parsePictureHeader(
        _ b: [UInt8],
        blockStart: UInt64,
        blockLength: Int,
        into meta: inout FLACMetadata
    ) {
        var pos = 0

        func u32() -> Int? {
            guard pos + 4 <= b.count else { return nil }
            let v = (Int(b[pos]) << 24) | (Int(b[pos + 1]) << 16) | (Int(b[pos + 2]) << 8) | Int(b[pos + 3])
            pos += 4
            return v
        }

        guard let type = u32(),
              let mimeLength = u32(), pos + mimeLength <= b.count else { return }
        pos += mimeLength
        guard let descLength = u32(), pos + descLength <= b.count else { return }
        pos += descLength
        guard pos + 16 <= b.count else { return }
        pos += 16  // ancho, alto, profundidad de color, nº de colores
        guard let dataLength = u32(), dataLength > 0,
              pos + dataLength <= blockLength else { return }

        // Preferimos la portada frontal (tipo 3); si no hay, la primera imagen.
        if meta.picture == nil || (type == 3 && meta.picture?.type != 3) {
            meta.picture = PictureRef(offset: blockStart + UInt64(pos), length: dataLength, type: type)
        }
    }

    private static func leadingInt(_ value: String) -> Int {
        let head = value.split(separator: "/").first.map(String.init) ?? value
        return Int(head.trimmingCharacters(in: .whitespaces)) ?? 0
    }
}
