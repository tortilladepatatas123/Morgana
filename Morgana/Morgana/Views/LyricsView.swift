import SwiftUI

/// Hoja con la letra incrustada de una pista.
struct LyricsSheet: View {
    let track: Track

    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    private enum LoadState {
        case loading
        case text(String)
        case missing
    }

    @State private var state: LoadState = .loading

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .missing:
                    Text("Esta canción no tiene letra incrustada.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(32)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .text(let lyrics):
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.headline)
                                Text(track.artist)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Text(lyrics)
                                .font(.title3.weight(.medium))
                                .lineSpacing(6)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Letra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task(id: track.id) { @MainActor in
            state = .loading
            guard let url = store.url(for: track),
                  let lyrics = await Lyrics.load(from: url) else {
                state = .missing
                return
            }
            state = .text(lyrics)
        }
    }
}
