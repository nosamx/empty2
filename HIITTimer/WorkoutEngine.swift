import AVFoundation
import Foundation

/// Speaks prompts over any music that is playing, ducking it only while talking.
/// All audio work runs on a background queue so it never stalls the timer display.
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    private let queue = DispatchQueue(label: "hiit.speaker", qos: .userInitiated)
    private let synthesizer = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice(language: "en-US")
    private var generation = 0
    var enabled = true

    override init() {
        super.init()
        synthesizer.delegate = self
        queue.async {
            try? AVAudioSession.sharedInstance().setCategory(
                .playback, mode: .voicePrompt, options: [.mixWithOthers, .duckOthers])
        }
    }

    func speak(_ text: String) {
        guard enabled else { return }
        queue.async { [self] in
            generation += 1
            if synthesizer.isSpeaking {
                synthesizer.stopSpeaking(at: .immediate)
            }
            try? AVAudioSession.sharedInstance().setActive(true)
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice
            utterance.rate = 0.52
            utterance.volume = 1.0
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        queue.async { [self] in
            generation += 1
            synthesizer.stopSpeaking(at: .immediate)
            releaseSessionSoon()
        }
    }

    /// Lets music return to full volume once nothing has been said for a moment.
    /// The delay keeps the session open across the 3-2-1 countdown.
    private func releaseSessionSoon() {
        let current = generation
        queue.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, self.generation == current, !self.synthesizer.isSpeaking else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        queue.async { [weak self] in self?.releaseSessionSoon() }
    }
}

final class WorkoutEngine: ObservableObject {
    @Published private(set) var steps: [WorkoutStep] = []
    @Published private(set) var index = 0
    @Published private(set) var remaining: Double = 0
    @Published private(set) var isPaused = false
    @Published private(set) var isFinished = false

    private let speaker = Speaker()
    private var endDate = Date()
    private var timer: Timer?
    private var lastSecond = -1

    var currentStep: WorkoutStep? {
        steps.indices.contains(index) ? steps[index] : nil
    }

    var secondsLeft: Int { Int(remaining.rounded(.up)) }

    var stepProgress: Double {
        guard let step = currentStep, step.duration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / Double(step.duration)))
    }

    /// Seconds left in the whole workout, including the current step.
    var totalSecondsLeft: Int {
        guard !isFinished, steps.indices.contains(index) else { return 0 }
        return secondsLeft + steps[(index + 1)...].reduce(0) { $0 + $1.duration }
    }

    func start(with settings: WorkoutSettings) {
        stop()
        speaker.enabled = settings.voiceEnabled
        steps = settings.buildSteps()
        isFinished = false
        isPaused = false
        guard !steps.isEmpty else { return }
        begin(stepAt: 0)
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        speaker.stop()
    }

    func togglePause() {
        guard !isFinished else { return }
        if isPaused {
            endDate = Date().addingTimeInterval(remaining)
            isPaused = false
        } else {
            remaining = max(0, endDate.timeIntervalSinceNow)
            isPaused = true
            speaker.stop()
        }
    }

    func skipForward() {
        guard !isFinished else { return }
        advance()
    }

    func skipBack() {
        guard !isFinished else { return }
        // Restart the current step, or go to the previous one if it only just began.
        let elapsed = Double(currentStep?.duration ?? 0) - remaining
        begin(stepAt: elapsed < 2 && index > 0 ? index - 1 : index)
    }

    private func begin(stepAt newIndex: Int) {
        index = newIndex
        let step = steps[newIndex]
        remaining = Double(step.duration)
        endDate = Date().addingTimeInterval(remaining)
        lastSecond = step.duration
        speaker.speak(announcement(for: step))
    }

    private func announcement(for step: WorkoutStep) -> String {
        switch step.kind {
        case .prepare:
            return "Get ready. First up, \(step.next ?? "")"
        case .work:
            return step.title
        case .rest:
            guard let next = step.next else { return "Rest" }
            // Keep it short on brief rests so it finishes before the countdown.
            return step.duration < 8 ? "Next, \(next)" : "Rest. Next up, \(next)"
        }
    }

    private func advance() {
        if index + 1 < steps.count {
            begin(stepAt: index + 1)
        } else {
            finish()
        }
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        remaining = 0
        isFinished = true
        speaker.speak("Workout complete. Great job!")
    }

    private func tick() {
        guard !isPaused, !isFinished, currentStep != nil else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining <= 0 {
            advance()
            return
        }
        let second = secondsLeft
        if second != lastSecond {
            lastSecond = second
            if (1...3).contains(second) {
                speaker.speak("\(second)")
            }
        }
    }
}
