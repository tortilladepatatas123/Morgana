import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: PlayerManager

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Inicio", systemImage: "house") }
            SearchView()
                .tabItem { Label("Buscar", systemImage: "magnifyingglass") }
            AlbumsView()
                .tabItem { Label("Álbumes", systemImage: "square.stack") }
            ArtistsView()
                .tabItem { Label("Artistas", systemImage: "music.mic") }
            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
        }
        .miniPlayerAccessory()
        .sheet(isPresented: $player.showNowPlaying) {
            NowPlayingView()
                .environmentObject(player)
                .presentationDragIndicator(.visible)
        }
    }
}
