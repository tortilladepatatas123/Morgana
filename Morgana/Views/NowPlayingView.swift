import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var player: PlayerManager
    @Environment(\.dismiss) private var dismiss

    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0

    private var displayedTime: Double {
        isScrubbing ? scrubValue : player.currentTime
    }

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            if let track = player.currentTrack {
                ArtworkView(key: track.artworkKey, pixels: 900)
                    .frame(maxWidth: 360, maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 12, y: 6)
                    .padding(.horizontal, 24)

                VStack(spacing: 4) {
                    Text(track.title)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(track.artist)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(track.formatDescription)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 24)

                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { displayedTime },
                            set: { scrubValue = $0 }
                        ),
                        in: 0...max(player.duration, 1),
                        onEditingChanged: { editing in
                            if editing {
                                scrubValue = player.currentTime
                                isScrubbing = true
                            } else {
                                player.seek(to: scrubValue)
                                isScrubbing = false
                            }
                        }
                    )
                    HStack {
                        Text(formatTime(displayedTime))
                        Spacer()
                        Text("-" + formatTime(max(player.duration - displayedTime, 0)))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)

                HStack(spacing: 36) {
                    Button {
                        player.repeatMode = player.repeatMode.next
                    } label: {
                        Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                            .font(.title3)
                            .foregroundStyle(player.repeatMode == .off ? Color.secondary : Color.accentColor)
                    }

                    Button { player.previous() } label: {
                        Image(systemName: "backward.fill").font(.title)
                    }

                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                    }

                    Button { player.next() } label: {
                        Image(systemName: "forward.fill").font(.title)
                    }

                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            } else {
                Spacer()
                Text("No hay nada en reproducción")
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.bottom, 16)
    }
}
