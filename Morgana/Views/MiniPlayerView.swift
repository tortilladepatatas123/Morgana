import SwiftUI

/// Separación entre el mini reproductor flotante y la barra de pestañas (solo sin el accesorio del sistema).
private let miniPlayerGap: CGFloat = 8
/// Alto de la cápsula del mini reproductor (solo sin el accesorio del sistema).
private let miniPlayerCapsuleHeight: CGFloat = 48
/// Espacio que hay que dejar al final de las listas cuando el mini reproductor es propio.
private let miniPlayerHeight: CGFloat = miniPlayerCapsuleHeight + miniPlayerGap + 8

enum MiniPlayerStyle {
    /// A partir de iOS 26 el mini reproductor es el accesorio inferior de la barra de pestañas
    /// (`tabViewBottomAccessory`), el mismo que usa Apple Música: cápsula de cristal del sistema.
    /// En versiones anteriores, o si se compila con un Xcode más antiguo, se dibuja una cápsula propia.
    static var usesSystemAccessory: Bool {
        #if compiler(>=6.2)
        if #available(iOS 26, *) { return true }
        #endif
        return false
    }
}

/// Contenido del mini reproductor, sin fondo: carátula, título, artista, reproducir/pausa y siguiente.
struct MiniPlayerContent: View {
    @EnvironmentObject var player: PlayerManager

    var body: some View {
        let track = player.currentTrack

        HStack(spacing: 12) {
            Group {
                if let track {
                    ArtworkView(key: track.artworkKey, pixels: 150)
                } else {
                    Color(.tertiarySystemFill)
                        .overlay(Image(systemName: "music.note").foregroundStyle(Color.secondary))
                }
            }
            .frame(width: 30, height: 30)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                MarqueeText(
                    text: track?.title ?? "No se está reproduciendo",
                    font: .subheadline.weight(.semibold),
                    color: track == nil ? Color.secondary : Color.primary
                )
                if let track {
                    MarqueeText(text: track.artist, font: .caption, color: Color.secondary)
                }
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
        .padding(.horizontal, 12)
        .disabled(track == nil)
        .contentShape(Rectangle())
        .onTapGesture {
            if track != nil { player.showNowPlaying = true }
        }
    }
}

/// Cápsula propia (solo cuando no hay accesorio del sistema): material translúcido, sin más efectos.
struct MiniPlayerView: View {
    @EnvironmentObject var player: PlayerManager

    var body: some View {
        if player.currentTrack != nil {
            MiniPlayerContent()
                .frame(height: miniPlayerCapsuleHeight)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.horizontal, 12)
                .padding(.bottom, miniPlayerGap)
        }
    }
}

/// Coloca el mini reproductor como accesorio inferior de la barra de pestañas (iOS 26 o superior).
struct MiniPlayerAccessory: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26, *) {
            content.tabViewBottomAccessory {
                MiniPlayerContent()
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

/// Solo con el mini reproductor propio: lo dibuja flotando sobre la pantalla.
struct MiniPlayerInset: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if MiniPlayerStyle.usesSystemAccessory {
            content
        } else {
            // Overlay: no reserva espacio por sí solo. Cada pantalla con scroll lo reserva con
            // `miniPlayerBottomSpacing()`.
            content.overlay(alignment: .bottom) { MiniPlayerView() }
        }
    }
}

/// Deja espacio al final de una pantalla con scroll para que el mini reproductor propio no tape las
/// últimas filas. Con el accesorio del sistema no hace falta: iOS ya ajusta el margen.
struct MiniPlayerBottomSpacing: ViewModifier {
    @EnvironmentObject var player: PlayerManager

    @ViewBuilder
    func body(content: Content) -> some View {
        if MiniPlayerStyle.usesSystemAccessory {
            content
        } else {
            content.safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: player.currentTrack == nil ? 0 : miniPlayerHeight)
            }
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

    func miniPlayerAccessory() -> some View {
        modifier(MiniPlayerAccessory())
    }
}
