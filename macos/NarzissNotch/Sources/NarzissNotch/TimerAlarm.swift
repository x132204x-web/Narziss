import AppKit
import Combine

enum AlarmTone: String, CaseIterable, Identifiable {
    case glass = "Glass", hero = "Hero", ping = "Ping", submarine = "Submarine", morse = "Morse"
    var id: String { rawValue }
}

@MainActor
protocol AlarmSoundPlaying: AnyObject {
    func play(_ tone: AlarmTone, repeating: Bool) -> Bool
    func stop()
}

@MainActor
final class SystemAlarmSound: AlarmSoundPlaying {
    private var sound: NSSound?
    func play(_ tone: AlarmTone, repeating: Bool) -> Bool {
        stop()
        sound = NSSound(named: NSSound.Name(tone.rawValue))
        sound?.loops = repeating
        sound?.volume = 1
        return sound?.play() ?? false
    }
    func stop() { sound?.stop(); sound = nil }
}

@MainActor
final class TimerAlarm: ObservableObject {
    private let defaults: UserDefaults
    private let player: AlarmSoundPlaying
    @Published var tone: AlarmTone {
        didSet {
            defaults.set(tone.rawValue, forKey: "timer.alarmTone")
            if isRinging { start() }
        }
    }
    @Published var isMuted: Bool {
        didSet {
            defaults.set(isMuted, forKey: "timer.alarmMuted")
            if isMuted { stop() }
        }
    }
    @Published var showBanner: Bool { didSet { defaults.set(showBanner, forKey: "timer.showBanner") } }
    @Published private(set) var isRinging = false
    @Published private(set) var error: String?

    init(defaults: UserDefaults = .standard, player: AlarmSoundPlaying? = nil) {
        self.defaults = defaults
        self.player = player ?? SystemAlarmSound()
        tone = defaults.string(forKey: "timer.alarmTone").flatMap(AlarmTone.init(rawValue:)) ?? .glass
        isMuted = defaults.bool(forKey: "timer.alarmMuted")
        showBanner = defaults.bool(forKey: "timer.showBanner")
    }
    func start() {
        stop()
        guard !isMuted else { return }
        isRinging = player.play(tone, repeating: true)
        if !isRinging { error = "Couldn’t play the alarm. Check your Mac’s sound output." }
    }
    func preview() {
        stop()
        guard !isMuted else { return }
        if !player.play(tone, repeating: false) { error = "Couldn’t play the selected sound." }
    }
    func stop() { player.stop(); isRinging = false; error = nil }
}
