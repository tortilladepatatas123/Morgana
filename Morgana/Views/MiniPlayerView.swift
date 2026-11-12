import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var player: PlayerManager
    var onTap: () -> Void

    var body: some View {
        if let track = player.currentTrack {
            HStack(spacing: 12) {
                ArtworkView(key: track.artworkKey, pixels: 150)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 40, height: 40)
                }

                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .frame(width: 40, height: 40)
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .overlay(alignment: .top) { Divider() }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
    }
}

struct MiniPlayerInset: ViewModifier {
    @EnvironmentObject var player: PlayerManager
    @State private var showNowPlaying = false

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MiniPlayerView { showNowPlaying = true }
            }
            .sheet(isPresented: $showNowPlaying) {
                NowPlayingView()
                    .environmentObject(player)
            }
    }
}

extension View {
    func miniPlayerInset() -> some View {
        modifier(MiniPlayerInset())
    }
}
