import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            SongsView()
                .tabItem { Label("Canciones", systemImage: "music.note") }
            AlbumsView()
                .tabItem { Label("Álbumes", systemImage: "square.stack") }
            ArtistsView()
                .tabItem { Label("Artistas", systemImage: "music.mic") }
            FoldersView()
                .tabItem { Label("Carpetas", systemImage: "folder") }
        }
    }
}
