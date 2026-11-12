import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject var store: LibraryStore

    var body: some View {
        NavigationStack {
            Group {
                if store.artists.isEmpty {
                    EmptyLibraryView()
                } else {
                    List(store.artists) { artist in
                        NavigationLink {
                            ArtistDetailView(artist: artist)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(artist.name).lineLimit(1)
                                    Text("\(artist.albums.count) álbumes · \(artist.trackCount) canciones")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Artistas")
        }
        .miniPlayerInset()
    }
}

struct ArtistDetailView: View {
    let artist: Artist

    var body: some View {
        List(artist.albums) { album in
            NavigationLink {
                AlbumDetailView(album: album)
            } label: {
                HStack(spacing: 12) {
                    ArtworkView(key: album.artworkKey, pixels: 200)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(album.title).lineLimit(1)
                        Text(album.year.isEmpty ? "\(album.tracks.count) canciones" : "\(album.year) · \(album.tracks.count) canciones")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
