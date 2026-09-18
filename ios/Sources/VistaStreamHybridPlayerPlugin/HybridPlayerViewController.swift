import AVFoundation
import AVKit
import MobileVLCKit
import UIKit

final class HybridPlayerViewController: UIViewController, VLCMediaPlayerDelegate {
    let options: HybridPlayerOptions
    private(set) var activeEngine: PlaybackEngine
    var onEvent: ((String, [String: Any]) -> Void)?
    var onExit: (([String: Any]) -> Void)?

    private let videoView = UIView()
    private let closeButton = UIButton(type: .system)
    private var avController: AVPlayerViewController?
    private var avStatusObservation: NSKeyValueObservation?
    private var avTimeObserver: Any?
    private var avTimeoutWorkItem: DispatchWorkItem?
    private var vlcPlayer: VLCMediaPlayer?
    private var state = "loading"
    private var lastSeconds = 0.0
    private var duration = 0.0
    private var exiting = false
    private var attemptedEngines: [PlaybackEngine] = []

    init(options: HybridPlayerOptions) {
        self.options = options
        self.activeEngine = Self.initialEngine(for: options)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        videoView.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.accessibilityLabel = "Close player"
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(videoView)
        view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            videoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoView.topAnchor.constraint(equalTo: view.topAnchor),
            videoView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -18),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        configureAudioSession()
        start(engine: activeEngine)
    }

    var snapshot: [String: Any] {
        [
            "engine": activeEngine.rawValue,
            "state": state,
            "seconds": lastSeconds,
            "duration": duration,
            "attemptedEngines": attemptedEngines.map(\.rawValue)
        ]
    }

    func play() {
        if activeEngine == .avplayer { avController?.player?.play() } else { vlcPlayer?.play() }
        updateState("playing")
    }

    func pause() {
        if activeEngine == .avplayer { avController?.player?.pause() } else { vlcPlayer?.pause() }
        updateState("paused")
    }

    func seek(seconds: Double) {
        if activeEngine == .avplayer {
            avController?.player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        } else {
            vlcPlayer?.time = VLCTime(int: Int32(seconds * 1000))
        }
        lastSeconds = seconds
    }

    func selectAudioTrack(id: Int) {
        if activeEngine == .vlc { vlcPlayer?.currentAudioTrackIndex = Int32(id) }
    }

    func selectSubtitleTrack(id: Int) {
        if activeEngine == .vlc { vlcPlayer?.currentVideoSubTitleIndex = Int32(id) }
    }

    func finish() {
        guard !exiting else { return }
        exiting = true
        let payload = snapshot
        cleanup()
        dismiss(animated: true) { [onExit] in onExit?(payload) }
    }

    @objc private func closeTapped() { finish() }

    private func start(engine: PlaybackEngine) {
        cleanup(keepAudioSession: true)
        activeEngine = engine
        if !attemptedEngines.contains(engine) { attemptedEngines.append(engine) }
        state = "loading"
        emit("stateChange")
        engine == .vlc ? startVLC() : startAVPlayer()
    }

    private func startAVPlayer() {
        let asset = AVURLAsset(
            url: options.url,
            options: options.requestHeaders.isEmpty
                ? nil
                : ["AVURLAssetHTTPHeaderFieldsKey": options.requestHeaders]
        )
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = true
        addChild(controller)
        controller.view.frame = videoView.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        videoView.addSubview(controller.view)
        controller.didMove(toParent: self)
        avController = controller

        avStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] observed, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if observed.status == .failed {
                    self.recoverFromAVPlayer(
                        code: "avplayer_failed",
                        message: observed.error?.localizedDescription ?? "AVPlayer could not play this stream."
                    )
                } else if observed.status == .readyToPlay {
                    self.avTimeoutWorkItem?.cancel()
                    self.duration = observed.duration.seconds.isFinite ? observed.duration.seconds : 0
                    if self.options.startAt > 0 { self.seek(seconds: self.options.startAt) }
                    player.play()
                    self.updateState("playing")
                }
            }
        }

        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.activeEngine == .avplayer, self.state == "loading" else { return }
            self.recoverFromAVPlayer(
                code: "connection_timeout",
                message: "AVPlayer did not become ready before the connection timeout."
            )
        }
        avTimeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + options.connectionTimeoutSeconds, execute: timeout)

        avTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 2),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            self.lastSeconds = max(0, time.seconds.isFinite ? time.seconds : 0)
            self.emit("progress")
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(avEnded),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(avFailed),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: item
        )
    }

    private func startVLC() {
        let player = VLCMediaPlayer()
        player.delegate = self
        player.drawable = videoView

        let media = VLCMedia(url: options.url)
        var mediaOptions: [AnyHashable: Any] = [
            "network-caching": options.networkCachingMs,
            "live-caching": options.networkCachingMs,
            "http-reconnect": true
        ]
        if let value = options.userAgent ?? options.header(named: "User-Agent"), !value.isEmpty {
            mediaOptions["http-user-agent"] = value
        }
        if let value = options.referrer ?? options.header(named: "Referer"), !value.isEmpty {
            mediaOptions["http-referrer"] = value
        }
        if let value = options.cookies ?? options.header(named: "Cookie"), !value.isEmpty {
            mediaOptions["http-cookie"] = value
            mediaOptions["http-forward-cookies"] = true
        }
        media.addOptions(mediaOptions)
        player.media = media
        vlcPlayer = player
        player.play()

        if options.startAt > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.seek(seconds: self?.options.startAt ?? 0)
            }
        }
    }

    private func recoverFromAVPlayer(code: String, message: String) {
        avTimeoutWorkItem?.cancel()
        if options.requestedEngine == .auto {
            var payload = snapshot
            payload["message"] = message
            payload["errorCode"] = code
            payload["recoverable"] = true
            onEvent?("stateChange", payload)
            start(engine: .vlc)
        } else {
            updateState("error", message: message, errorCode: code, recoverable: false)
        }
    }

    @objc private func avEnded() {
        updateState("ended")
        emit("exit")
    }

    @objc private func avFailed(_ notification: Notification) {
        let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
        recoverFromAVPlayer(
            code: "avplayer_failed",
            message: error?.localizedDescription ?? "AVPlayer could not finish this stream."
        )
    }

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let player = vlcPlayer else { return }
        duration = max(0, Double(player.media?.length.intValue ?? 0) / 1000)
        lastSeconds = max(0, Double(player.time.intValue) / 1000)
        switch player.state {
        case .opening: updateState("loading")
        case .buffering: updateState("buffering")
        case .playing: updateState("playing")
        case .paused: updateState("paused")
        case .ended: updateState("ended"); emit("exit")
        case .error:
            updateState(
                "error",
                message: "The provider stream failed in AVPlayer and MobileVLCKit.",
                errorCode: "vlc_failed",
                recoverable: false
            )
        default: break
        }
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        guard let player = vlcPlayer else { return }
        lastSeconds = max(0, Double(player.time.intValue) / 1000)
        duration = max(0, Double(player.media?.length.intValue ?? 0) / 1000)
        emit("progress")
    }

    private func updateState(
        _ value: String,
        message: String? = nil,
        errorCode: String? = nil,
        recoverable: Bool? = nil
    ) {
        state = value
        emit("stateChange", message: message, errorCode: errorCode, recoverable: recoverable)
    }

    private func emit(
        _ name: String,
        message: String? = nil,
        errorCode: String? = nil,
        recoverable: Bool? = nil
    ) {
        var payload = snapshot
        if let message { payload["message"] = message }
        if let errorCode { payload["errorCode"] = errorCode }
        if let recoverable { payload["recoverable"] = recoverable }
        onEvent?(name, payload)
    }

    private func cleanup(keepAudioSession: Bool = false) {
        avTimeoutWorkItem?.cancel()
        avTimeoutWorkItem = nil
        avStatusObservation = nil
        if let observer = avTimeObserver, let player = avController?.player {
            player.removeTimeObserver(observer)
        }
        avTimeObserver = nil
        avController?.player?.pause()
        avController?.willMove(toParent: nil)
        avController?.view.removeFromSuperview()
        avController?.removeFromParent()
        avController = nil
        vlcPlayer?.stop()
        vlcPlayer?.delegate = nil
        vlcPlayer = nil
        NotificationCenter.default.removeObserver(self)
        if !keepAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(options.backgroundEnabled ? .playback : .ambient, mode: .moviePlayback)
        try? session.setActive(true)
    }

    private static func initialEngine(for options: HybridPlayerOptions) -> PlaybackEngine {
        if options.requestedEngine != .auto { return options.requestedEngine }
        return ["mkv", "avi", "ts", "mpeg", "mpg", "webm"].contains(options.url.pathExtension.lowercased())
            ? .vlc
            : .avplayer
    }

    deinit { cleanup() }
}
