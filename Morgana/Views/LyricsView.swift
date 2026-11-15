import SwiftUI

/// Letra de la canción para mostrar dentro de la pantalla de reproducción.
/// Si está sincronizada, resalta la línea actual y la mantiene centrada; tocar una línea salta a ella.
struct LyricsPanel: View {
    let track: Track

    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var player: PlayerManager

    private enum LoadState {
        case loading
        case content(LyricsContent)
        case missing
    }

    @State private var state: LoadState = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .missing:
                Text("Esta canción no tiene letra incrustada.")
                    .foregroundStyle(Color.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .content(let content):
                if content.isSynced {
                    SyncedLyrics(lines: content.lines, clock: player.clock) { time in
                        player.seek(to: time)
                    }
                } else {
                    PlainLyrics(lines: content.lines)
                }
            }
        }
        .task(id: track.id) { @MainActor in
            state = .loading
            guard let url = store.url(for: track),
                  let content = await Lyrics.loadContent(from: url) else {
                state = .missing
                return
            }
            state = .content(content)
        }
    }
}

/// Difumina los bordes superior e inferior de la zona de letra.
private struct LyricsEdgeFade: ViewModifier {
    func body(content: Content) -> some View {
        content.mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [Color.clear, Color.black], startPoint: .top, endPoint: .bottom)
                    .frame(height: 28)
                Rectangle().fill(Color.black)
                LinearGradient(colors: [Color.black, Color.clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 28)
            }
        }
    }
}

private struct PlainLyrics: View {
    let lines: [LyricLine]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(lines) { line in
                    Text(line.text.isEmpty ? " " : line.text)
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 24)
        }
        .modifier(LyricsEdgeFade())
    }
}

/// Observa el reloj y solo pasa a la vista de líneas el índice actual, para no redibujarla en cada tic.
private struct SyncedLyrics: View {
    let lines: [LyricLine]
    @ObservedObject var clock: PlaybackClock
    let onSeek: (Double) -> Void

    private var currentIndex: Int {
        let t = clock.currentTime + 0.15
        var low = 0
        var high = lines.count
        // Última línea cuyo tiempo es <= t (búsqueda binaria; las líneas están ordenadas).
        while low < high {
            let mid = (low + high) / 2
            if (lines[mid].time ?? 0) <= t { low = mid + 1 } else { high = mid }
        }
        return low - 1
    }

    var body: some View {
        SyncedLines(lines: lines, current: currentIndex, onSeek: onSeek)
            .equatable()
    }
}

private struct SyncedLines: View, Equatable {
    let lines: [LyricLine]
    let current: Int
    let onSeek: (Double) -> Void

    static func == (a: SyncedLines, b: SyncedLines) -> Bool {
        a.current == b.current && a.lines == b.lines
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(lines) { line in
                        Text(line.text.isEmpty ? "\u{266A}" : line.text)
                            .font(.title2.weight(.bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .opacity(line.id == current ? 1 : 0.4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let time = line.time { onSeek(time) }
                            }
                            .id(line.id)
                    }
                }
                .padding(.vertical, 60)
                .animation(.easeInOut(duration: 0.3), value: current)
            }
            .modifier(LyricsEdgeFade())
            .onAppear {
                if current >= 0 { proxy.scrollTo(current, anchor: .center) }
            }
            .onChange(of: current) { value in
                guard value >= 0 else { return }
                withAnimation(.easeInOut(duration: 0.4)) {
                    proxy.scrollTo(value, anchor: .center)
                }
            }
        }
    }
}
