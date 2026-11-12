import SwiftUI

@main
struct MorganaApp: App {
    @StateObject private var store = LibraryStore()
    @StateObject private var player = PlayerManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(player)
                .onAppear {
                    player.urlProvider = { [weak store] track in store?.url(for: track) }
                }
        }
    }
}
