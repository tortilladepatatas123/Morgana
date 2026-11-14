import SwiftUI

struct ContentView: View {
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
                .tabItem { Label("Configuración", systemImage: "gearshape") }
        }
    }
}
