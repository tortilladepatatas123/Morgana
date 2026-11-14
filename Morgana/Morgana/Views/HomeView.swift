import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var userData: PlaylistStore
    var body: some View {
        NavigationStack {
            quickAccess
                .miniPlayerBottomSpacing()
                .navigationTitle("Inicio")
        }
        .miniPlayerInset()
    }

    private var quickAccess: some View {
        ScrollView {
            VStack(spacing: 20) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    NavigationLink {
                        TrackListView(title: "Canciones", tracks: store.tracks)
                    } label: {
                        HomeCard(title: "Canciones", systemImage: "music.note", tint: .pink, subtitle: "\(store.tracks.count)")
                    }

                    NavigationLink {
                        FavoritesView()
                    } label: {
                        HomeCard(
                            title: "Favoritos",
                            systemImage: "star.fill",
                            tint: .yellow,
                            subtitle: "\(store.tracks(for: userData.favorites).count)"
                        )
                    }

                    NavigationLink {
                        GenresView()
                    } label: {
                        HomeCard(title: "Géneros", systemImage: "guitars", tint: .purple, subtitle: "\(store.genres.count)")
                    }

                    NavigationLink {
                        PlaylistsView()
                    } label: {
                        HomeCard(
                            title: "Listas",
                            systemImage: "music.note.list",
                            tint: .blue,
                            subtitle: "\(userData.playlists.count)"
                        )
                    }
                }
                .buttonStyle(.plain)

                if store.tracks.isEmpty {
                    EmptyLibraryView()
                        .frame(minHeight: 260)
                }
            }
            .padding(16)
        }
    }
}

private struct HomeCard: View {
    let title: String
    let systemImage: String
    let tint: Color
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
