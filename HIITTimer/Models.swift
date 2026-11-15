import Foundation

struct Exercise: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var duration: Int
    var enabled = true
}

struct WorkoutSettings: Codable, Equatable {
    var exercises: [Exercise]
    var rest = 15
    var rounds = 1
    var voiceEnabled = true

    static let defaultDuration = 40

    static let defaultNames = [
        "Pushups", "Pull Ups", "Squats", "Calf Raises", "Wall Sits", "Planks",
        "Burpees", "Side Plank Right", "Side Plank Left", "Mountain Climbers",
        "Lunges", "Diamond Pushups", "Wide Pushups", "Russian Twists",
        "Bicycle Crunches",
    ]

    static var standard: WorkoutSettings {
        WorkoutSettings(exercises: defaultNames.map { Exercise(name: $0, duration: defaultDuration) })
    }

    var activeExercises: [Exercise] { exercises.filter(\.enabled) }

    /// Total workout time in seconds, excluding the get-ready countdown.
    var totalSeconds: Int {
        let active = activeExercises
        guard !active.isEmpty else { return 0 }
        let work = active.reduce(0) { $0 + $1.duration } * rounds
        let rests = (active.count * rounds - 1) * rest
        return work + rests
    }
}

enum StepKind {
    case prepare, work, rest
}

struct WorkoutStep {
    var kind: StepKind
    var title: String
    var duration: Int
    var next: String?
    var round: Int
    var exerciseNumber: Int
}

extension WorkoutSettings {
    static let prepareSeconds = 10

    func buildSteps() -> [WorkoutStep] {
        let active = activeExercises
        guard !active.isEmpty else { return [] }
        var steps = [
            WorkoutStep(kind: .prepare, title: "Get Ready", duration: Self.prepareSeconds,
                        next: active[0].name, round: 1, exerciseNumber: 0)
        ]
        for round in 1...rounds {
            for (i, exercise) in active.enumerated() {
                let isLast = round == rounds && i == active.count - 1
                let next: String? = isLast ? nil : active[(i + 1) % active.count].name
                steps.append(WorkoutStep(kind: .work, title: exercise.name, duration: exercise.duration,
                                         next: next, round: round, exerciseNumber: i + 1))
                if !isLast && rest > 0 {
                    steps.append(WorkoutStep(kind: .rest, title: "Rest", duration: rest,
                                             next: next, round: round, exerciseNumber: i + 1))
                }
            }
        }
        return steps
    }
}

final class SettingsStore: ObservableObject {
    private static let key = "workoutSettings.v1"

    @Published var settings: WorkoutSettings {
        didSet {
            if let data = try? JSONEncoder().encode(settings) {
                UserDefaults.standard.set(data, forKey: Self.key)
            }
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(WorkoutSettings.self, from: data) {
            settings = saved
        } else {
            settings = .standard
        }
    }
}

func formatTime(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}
