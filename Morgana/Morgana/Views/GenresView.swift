import SwiftUI

struct GenresView: View {
    @EnvironmentObject var store: LibraryStore

    var body: some View {
        Group {
            if store.genres.isEmpty {
                Text("Aún no hay géneros.\nSe leen de la etiqueta GENRE de tus archivos FLAC.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.genres) { genre in
                    NavigationLink {
                        TrackListView(title: genre.name, tracks: genre.tracks)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "guitars")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(genre.name).lineLimit(1)
                                Text("\(genre.tracks.count) canciones")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Géneros")
        .navigationBarTitleDisplayMode(.inline)
        .miniPlayerBottomSpacing()
    }
}
