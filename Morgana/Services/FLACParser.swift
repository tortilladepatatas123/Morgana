import Foundation

struct FLACMetadata {
    var title = ""
    var artist = ""
    var albumArtist = ""
    var album = ""
    var date = ""
    var trackNumber = 0
    var discNumber = 0
    var sampleRate = 0
    var bitsPerSample = 0
    var duration: Double = 0
    var pictureData: Data?
}

/// Lector mínimo de metadatos FLAC: STREAMINFO, VORBIS_COMMENT y PICTURE.
/// No decodifica audio; de eso se encarga AVFoundation.
enum FLACParser {
    private static let maxBlockSize = 32 * 1024 * 1024

    static func parse(url: URL) -> FLACMetadata? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        guard let marker = try? handle.read(upToCount: 4),
              [UInt8](marker) == [0x66, 0x4C, 0x61, 0x43] else { return nil }  // "fLaC"

        var meta = FLACMetadata()
        var pictureType = -1
        var isLast = false

        while !isLast {
            guard let headerData = try? handle.read(upToCount: 4), headerData.count == 4 else { break }
            let h = [UInt8](headerData)
            isLast = (h[0] & 0x80) != 0
            let blockType = Int(h[0] & 0x7F)
            let length = (Int(h[1]) << 16) | (Int(h[2]) << 8) | Int(h[3])

            let wanted = blockType == 0 || blockType == 4 || blockType == 6
            if !wanted || length == 0 || length > maxBlockSize {
                guard let offset = try? handle.offset(),
                      (try? handle.seek(toOffset: offset + UInt64(length))) != nil else { break }
                continue
            }

            guard let data = try? handle.read(upToCount: length), data.count == length else { break }
            let bytes = [UInt8](data)

            switch blockType {
            case 0: parseStreamInfo(bytes, into: &meta)
            case 4: parseVorbisComment(bytes, into: &meta)
            case 6: parsePicture(bytes, into: &meta, currentType: &pictureType)
            default: break
            }
        }

        return meta.sampleRate > 0 ? meta : nil
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

    private static func parseVorbisComment(_ b: [UInt8], into meta: inout FLACMetadata) {
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
            case "ARTIST": if meta.artist.isEmpty { meta.artist = value }
            case "ALBUMARTIST", "ALBUM ARTIST": if meta.albumArtist.isEmpty { meta.albumArtist = value }
            case "ALBUM": if meta.album.isEmpty { meta.album = value }
            case "DATE", "YEAR": if meta.date.isEmpty { meta.date = value }
            case "TRACKNUMBER": if meta.trackNumber == 0 { meta.trackNumber = leadingInt(value) }
            case "DISCNUMBER": if meta.discNumber == 0 { meta.discNumber = leadingInt(value) }
            default: break
            }
        }
    }

    private static func parsePicture(_ b: [UInt8], into meta: inout FLACMetadata, currentType: inout Int) {
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
        guard let dataLength = u32(), dataLength > 0, pos + dataLength <= b.count else { return }

        // Preferimos la portada frontal (tipo 3); si no hay, la primera imagen.
        if meta.pictureData == nil || (type == 3 && currentType != 3) {
            meta.pictureData = Data(b[pos..<(pos + dataLength)])
            currentType = type
        }
    }

    private static func leadingInt(_ value: String) -> Int {
        let head = value.split(separator: "/").first.map(String.init) ?? value
        return Int(head.trimmingCharacters(in: .whitespaces)) ?? 0
    }
}
