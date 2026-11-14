import Foundation

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
