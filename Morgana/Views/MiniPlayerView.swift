import SwiftUI

/// Separación entre el mini reproductor flotante y la barra de pestañas.
private let miniPlayerGap: CGFloat = 8
/// Alto total que ocupa el mini reproductor, separación incluida (para dejar espacio al final de las listas).
private let miniPlayerHeight: CGFloat = 72

struct MiniPlayerView: View {
    @EnvironmentObject var player: PlayerManager
    var onTap: () -> Void

    @State private var tint: Color?

    var body: some View {
        if let track = player.currentTrack {
            HStack(spacing: 12) {
                ArtworkView(key: track.artworkKey, pixels: 150)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(text: track.title, font: .subheadline.weight(.semibold), color: Color.primary)
                    MarqueeText(text: track.artist, font: .caption, color: Color.secondary)
                }

                Button {
                    player.togglePlayPause()
                } label: {
                    PlayPauseIcon(isPlaying: player.isPlaying, size: 22)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(PressableButtonStyle())

                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 22))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(PressableButtonStyle())
            }
            .foregroundStyle(Color.primary)
            .padding(.leading, 10)
            .padding(.trailing, 14)
            .frame(height: miniPlayerHeight - miniPlayerGap)
            .background { glass }
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.7), Color.white.opacity(0.15)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(0.18), radius: 14, y: 6)
            .contentShape(Capsule())
            .onTapGesture(perform: onTap)
            .padding(.horizontal, 12)
            .padding(.bottom, miniPlayerGap)
            .task(id: track.artworkKey) { @MainActor in
                let key = track.artworkKey
                let result = await Task.detached(priority: .utility) {
                    PaletteExtractor.palette(key: key)
                }.value
                withAnimation(.easeInOut(duration: 0.5)) {
                    tint = result?.primary
                }
            }
        }
    }

    /// Cristal translúcido con un velo del color de la carátula.
    private var glass: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            if let tint {
                Rectangle().fill(tint.opacity(0.28))
            }
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
