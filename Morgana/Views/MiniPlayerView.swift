import SwiftUI

/// Alto aproximado del mini reproductor (para dejar espacio al final de listas pushadas).
private let miniPlayerHeight: CGFloat = 64

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
                    MarqueeText(text: track.title, font: .subheadline.weight(.semibold), color: .primary)
                    MarqueeText(text: track.artist, font: .caption, color: .secondary)
                }

                Spacer(minLength: 0)

                Button {
                    player.togglePlayPause()
                } label: {
                    PlayPauseIcon(isPlaying: player.isPlaying, size: 20)
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
            // Overlay: el mini reproductor no reserva espacio por sí solo. Cada pantalla con
            // scroll lo reserva con `miniPlayerBottomSpacing()`, así es igual en todas y no se duplica.
            .overlay(alignment: .bottom) {
                MiniPlayerView { showNowPlaying = true }
            }
            .sheet(isPresented: $showNowPlaying) {
                NowPlayingView()
                    .environmentObject(player)
                    .presentationDragIndicator(.visible)
            }
    }
}

/// Deja espacio al final de una pantalla pushada (álbum, artista...) para que el
/// mini reproductor, que vive fuera del NavigationStack, no tape las últimas filas.
struct MiniPlayerBottomSpacing: ViewModifier {
    @EnvironmentObject var player: PlayerManager

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: player.currentTrack == nil ? 0 : miniPlayerHeight)
        }
    }
}

extension View {
    func miniPlayerInset() -> some View {
        modifier(MiniPlayerInset())
    }

    func miniPlayerBottomSpacing() -> some View {
        modifier(MiniPlayerBottomSpacing())
    }
}
