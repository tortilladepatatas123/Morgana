import AVFoundation
import MediaPlayer
import Combine
import UIKit

enum RepeatMode {
    case off, all, one

    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
}

/// Se crea fuera de la clase para que el cierre no herede el aislamiento a MainActor
/// (el sistema lo llama desde otro hilo).
private func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
    MPMediaItemArtwork(boundsSize: image.size) { _ in image }
}

@MainActor
final class PlayerManager: ObservableObject {
    @Published private(set) var queue: [Track] = []
    @Published private(set) var currentIndex: Int?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var repeatMode: RepeatMode = .off

    var urlProvider: (@MainActor (Track) -> URL?)?

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()
    private var itemStatusCancellable: AnyCancellable?

    var currentTrack: Track? {
        guard let index = currentIndex, queue.indices.contains(index) else { return nil }
        return queue[index]
    }

    init() {
        configureSession()
        observePlayer()
        configureRemoteCommands()
        observeSessionEvents()
    }

    // MARK: - Control

    func play(tracks: [Track], startAt index: Int = 0, shuffle: Bool = false) {
        guard !tracks.isEmpty else { return }
        if shuffle {
            queue = tracks.shuffled()
            load(0)
        } else {
            queue = tracks
            load(min(max(index, 0), tracks.count - 1))
        }
    }

    func resume() {
        guard player.currentItem != nil else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
    }

    func pause() {
        player.pause()
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }

    func next() {
        guard let index = currentIndex else { return }
        if index + 1 < queue.count {
            load(index + 1)
        } else if repeatMode == .all {
            load(0)
        }
    }

    func previous() {
        guard let index = currentIndex else { return }
        if currentTime > 3 || index == 0 {
            seek(to: 0)
        } else {
            load(index - 1)
        }
    }

    func seek(to seconds: Double) {
        let target = CMTime(seconds: max(seconds, 0), preferredTimescale: 600)
        currentTime = max(seconds, 0)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in self?.updateNowPlayingInfo() }
        }
    }

    // MARK: - Carga de pistas

    private func load(_ index: Int) {
        guard queue.indices.contains(index) else { return }
        let track = queue[index]

        guard let url = urlProvider?(track) else {
            skipUnplayable(from: index)
            return
        }

        currentIndex = index
        duration = track.duration
        currentTime = 0

        let item = AVPlayerItem(url: url)

        if let old = endObserver { NotificationCenter.default.removeObserver(old) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.trackDidFinish() }
        }

        itemStatusCancellable = item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .failed { self?.skipUnplayable(from: index) }
            }

        player.replaceCurrentItem(with: item)
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
        updateNowPlayingInfo()
    }

    private func skipUnplayable(from index: Int) {
        if index + 1 < queue.count {
            load(index + 1)
        } else {
            player.pause()
        }
    }

    private func trackDidFinish() {
        guard let index = currentIndex else { return }
        switch repeatMode {
        case .one:
            seek(to: 0)
            player.play()
        case .all:
            load((index + 1) % queue.count)
        case .off:
            if index + 1 < queue.count {
                load(index + 1)
            } else {
                player.pause()
                seek(to: 0)
            }
        }
    }

    // MARK: - Sesión de audio y eventos

    private func configureSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
    }

    private func observePlayer() {
        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isPlaying = (status != .paused)
                self?.updateNowPlayingInfo()
            }
            .store(in: &cancellables)

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            let seconds = time.seconds
            Task { @MainActor in
                guard let self, seconds.isFinite else { return }
                self.currentTime = seconds
            }
        }
    }

    private func observeSessionEvents() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let info = notification.userInfo
            let typeRaw = info?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsRaw = info?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor in
                guard let typeRaw, let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
                if type == .ended, let optionsRaw,
                   AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume) {
                    self?.resume()
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let reasonRaw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in
                guard let reasonRaw,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw),
                      reason == .oldDeviceUnavailable else { return }
                self?.pause()  // por ejemplo, al desconectar los auriculares
            }
        }
    }

    // MARK: - Pantalla de bloqueo y centro de control

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            Task { @MainActor in self?.seek(to: position) }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        let elapsed = player.currentTime().seconds
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: track.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed.isFinite ? elapsed : 0,
            MPNowPlayingInfoPropertyPlaybackRate: player.timeControlStatus == .playing ? 1.0 : 0.0
        ]
        if let image = ArtworkStore.image(key: track.artworkKey, maxPixel: 600) {
            info[MPMediaItemPropertyArtwork] = makeArtwork(image)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
