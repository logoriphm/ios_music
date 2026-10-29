import AVFoundation
import UIKit

final class PlayerViewController: UIViewController, AVAudioPlayerDelegate {
    @IBOutlet private weak var coverView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var artistLabel: UILabel!
    @IBOutlet private weak var previousButton: UIButton!
    @IBOutlet private weak var playPauseButton: UIButton!
    @IBOutlet private weak var nextButton: UIButton!

    private let tracks = TrackLibrary.tracks
    private var trackIndex = 0
    private var player: AVAudioPlayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.accessibilityTraits.insert(.header)
        titleLabel.accessibilityIdentifier = "trackTitle"
        coverView.isAccessibilityElement = false
        previousButton.accessibilityIdentifier = "previous"
        previousButton.accessibilityLabel = "Предыдущий трек"
        playPauseButton.accessibilityIdentifier = "playPause"
        nextButton.accessibilityIdentifier = "next"
        nextButton.accessibilityLabel = "Следующий трек"

        let symbolStyle = UIImage.SymbolConfiguration(pointSize: 21, weight: .semibold)
        for button in [previousButton, playPauseButton, nextButton].compactMap({ $0 }) {
            button.setPreferredSymbolConfiguration(symbolStyle, forImageIn: .normal)
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(audioWasInterrupted(_:)),
            name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance()
        )
        loadTrack(autoplay: false)
    }

    @IBAction private func previousTapped(_ sender: UIButton) {
        move(by: -1, autoplay: player?.isPlaying == true)
    }

    @IBAction private func nextTapped(_ sender: UIButton) {
        move(by: 1, autoplay: player?.isPlaying == true)
    }

    @IBAction private func playPauseTapped(_ sender: UIButton) {
        guard let player = player else {
            loadTrack(autoplay: true)
            return
        }
        if player.isPlaying {
            player.pause()
        } else {
            startPlayback(player)
        }
        refreshScreen()
    }

    private func move(by step: Int, autoplay: Bool) {
        trackIndex = (trackIndex + step + tracks.count) % tracks.count
        loadTrack(autoplay: autoplay)
    }

    private func loadTrack(autoplay: Bool) {
        player?.delegate = nil
        player?.stop()
        player = nil
        defer { refreshScreen() }

        let track = tracks[trackIndex]
        guard let url = Bundle.main.url(forResource: track.fileName, withExtension: "m4a") else {
            print("В ресурсах приложения отсутствует файл \(track.fileName).m4a")
            return
        }
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            guard newPlayer.prepareToPlay() else {
                print("Не удалось подготовить файл \(url.lastPathComponent) к воспроизведению.")
                return
            }
            newPlayer.delegate = self
            player = newPlayer
            if autoplay { startPlayback(newPlayer) }
        } catch {
            print("Не удалось открыть \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private func startPlayback(_ audioPlayer: AVAudioPlayer) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            if !audioPlayer.play() {
                print("Не удалось начать воспроизведение трека \(tracks[trackIndex].title).")
            }
        } catch {
            print("Не удалось активировать аудиосессию: \(error.localizedDescription)")
        }
    }

    private func refreshScreen() {
        let track = tracks[trackIndex]
        titleLabel.text = track.title
        artistLabel.text = track.artist
        coverView.image = UIImage(named: track.coverImageName)
        let playing = player?.isPlaying == true
        playPauseButton.setImage(UIImage(systemName: playing ? "pause.fill" : "play.fill"), for: .normal)
        playPauseButton.accessibilityLabel = playing ? "Пауза" : "Воспроизвести"
    }

    @objc private func audioWasInterrupted(_ notification: Notification) {
        guard let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: value) == .began else { return }
        player?.pause()
        refreshScreen()
    }

    func audioPlayerDidFinishPlaying(_ finishedPlayer: AVAudioPlayer, successfully flag: Bool) {
        guard finishedPlayer === player else { return }
        if flag {
            move(by: 1, autoplay: true)
        } else {
            print("Воспроизведение трека \(tracks[trackIndex].title) прервано.")
            refreshScreen()
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ failedPlayer: AVAudioPlayer, error: Error?) {
        guard failedPlayer === player else { return }
        print("Ошибка декодирования \(tracks[trackIndex].fileName): \(error?.localizedDescription ?? "неизвестная ошибка")")
        player = nil
        refreshScreen()
    }
}
