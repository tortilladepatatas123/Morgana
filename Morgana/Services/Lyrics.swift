import Foundation

/// Una línea de la letra. `time` es nil en las letras sin sincronizar.
struct LyricLine: Identifiable, Equatable {
    let id: Int
    let time: Double?
    let text: String
}

/// Letra lista para mostrar. Si trae marcas de tiempo (LRC), `isSynced` es true y las líneas
/// van ordenadas por tiempo.
struct LyricsContent: Equatable {
    var lines: [LyricLine]
    var isSynced: Bool
}

enum Lyrics {
    /// Lee la letra incrustada del archivo (fuera del hilo principal) y la deja lista para mostrar.
    /// Devuelve nil si la pista no trae letra.
    static func load(from url: URL) async -> String? {
        await Task.detached(priority: .userInitiated) { () -> String? in
            guard let raw = FLACParser.lyrics(url: url) else { return nil }
            let text = displayText(from: raw)
            return text.isEmpty ? nil : text
        }.value
    }

    /// Lee la letra incrustada y la devuelve línea a línea, con sus tiempos si está sincronizada.
    static func loadContent(from url: URL) async -> LyricsContent? {
        await Task.detached(priority: .userInitiated) { () -> LyricsContent? in
            guard let raw = FLACParser.lyrics(url: url) else { return nil }
            let content = parse(raw)
            return content.lines.isEmpty ? nil : content
        }.value
    }

    /// Interpreta la letra: LRC (`[mm:ss.xx] texto`, con varias marcas por línea y `[offset:ms]`)
    /// o texto plano.
    static func parse(_ raw: String) -> LyricsContent {
        let normalized = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let stampRegex = try? NSRegularExpression(pattern: #"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]"#)
        let offsetRegex = try? NSRegularExpression(pattern: #"^\[offset:\s*(-?\d+)\s*\]"#, options: [.caseInsensitive])

        var offset = 0.0
        var timed: [(time: Double, text: String)] = []

        for rawLine in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let ns = line as NSString

            if let m = offsetRegex?.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)),
               let value = Double(ns.substring(with: m.range(at: 1))) {
                offset = value / 1000
                continue
            }

            guard let regex = stampRegex else { continue }
            // Solo cuentan las marcas del principio de la línea.
            var stamps: [Double] = []
            var cursor = 0
            while let m = regex.firstMatch(
                in: line, options: .anchored,
                range: NSRange(location: cursor, length: ns.length - cursor)
            ) {
                let minutes = Double(ns.substring(with: m.range(at: 1))) ?? 0
                let seconds = Double(ns.substring(with: m.range(at: 2))) ?? 0
                var fraction = 0.0
                if m.range(at: 3).location != NSNotFound {
                    fraction = Double("0." + ns.substring(with: m.range(at: 3))) ?? 0
                }
                stamps.append(minutes * 60 + seconds + fraction)
                cursor = m.range.location + m.range.length
            }
            guard !stamps.isEmpty else { continue }

            var text = ns.substring(from: cursor)
            text = text.replacingOccurrences(
                of: #"<\d{1,3}:\d{2}(?:[.:]\d{1,3})?>"#, with: "", options: .regularExpression
            )
            text = text.trimmingCharacters(in: .whitespaces)
            for stamp in stamps { timed.append((max(stamp - offset, 0), text)) }
        }

        if timed.count >= 2 {
            let sorted = timed.enumerated()
                .sorted { a, b in a.element.time != b.element.time ? a.element.time < b.element.time : a.offset < b.offset }
                .map { $0.element }
            let lines = sorted.enumerated().map { LyricLine(id: $0.offset, time: $0.element.time, text: $0.element.text) }
            return LyricsContent(lines: lines, isSynced: true)
        }

        let plain = displayText(from: raw)
        guard !plain.isEmpty else { return LyricsContent(lines: [], isSynced: false) }
        let lines = plain.components(separatedBy: "\n").enumerated().map {
            LyricLine(id: $0.offset, time: nil, text: $0.element)
        }
        return LyricsContent(lines: lines, isSynced: false)
    }

    /// Normaliza saltos de línea y quita lo que sobra en letras sincronizadas (formato LRC):
    /// marcas de tiempo [01:23.45], marcas por palabra <01:23.45> y líneas de etiqueta [ar:...].
    /// Las letras sin sincronizar no se tocan.
    static func displayText(from raw: String) -> String {
        var text = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        text = text.replacingOccurrences(
            of: #"(?m)^\[[A-Za-z]{2,}:[^\]]*\][ \t]*\n?"#,
            with: "",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"\[\d{1,3}:\d{2}(?:[.:]\d{1,3})?\]"#,
            with: "",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"<\d{1,3}:\d{2}(?:[.:]\d{1,3})?>"#,
            with: "",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"[ \t]+\n"#,
            with: "\n",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
