import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SettingsStore
    @StateObject private var engine = WorkoutEngine()
    @State private var showingWorkout = false
    @State private var confirmingReset = false
    @State private var addingExercise = false
    @State private var newExerciseName = ""

    private let durationRange = 5...600

    /// Reads the shared duration (if every exercise matches) and writes to all of them.
    private var allDurations: Binding<Int> {
        Binding(
            get: { store.settings.exercises.first?.duration ?? WorkoutSettings.defaultDuration },
            set: { newValue in
                for i in store.settings.exercises.indices {
                    store.settings.exercises[i].duration = newValue
                }
            }
        )
    }

    private var allDurationsLabel: String {
        let durations = Set(store.settings.exercises.map(\.duration))
        if durations.count == 1, let only = durations.first {
            return "\(only)s"
        }
        return "Mixed"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Stepper(value: $store.settings.rounds, in: 1...20) {
                        settingRow("Rounds", value: "\(store.settings.rounds)")
                    }
                    Stepper(value: $store.settings.rest, in: 0...300, step: 5) {
                        settingRow("Rest between exercises",
                                   value: store.settings.rest == 0 ? "Off" : "\(store.settings.rest)s")
                    }
                    Toggle("Voice announcements", isOn: $store.settings.voiceEnabled)
                } header: {
                    Text("Workout")
                } footer: {
                    Text("Total time: \(formatTime(store.settings.totalSeconds))")
                }

                Section {
                    Stepper(value: allDurations, in: durationRange, step: 5) {
                        settingRow("Set all exercises", value: allDurationsLabel)
                    }
                } footer: {
                    Text("Changes every exercise at once. Adjust individual lengths below.")
                }

                Section {
                    ForEach($store.settings.exercises) { $exercise in
                        Stepper(value: $exercise.duration, in: durationRange, step: 5) {
                            HStack {
                                Button {
                                    exercise.enabled.toggle()
                                } label: {
                                    Image(systemName: exercise.enabled ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(exercise.enabled ? Color.orange : Color.secondary)
                                }
                                .buttonStyle(.plain)
                                Text(exercise.name)
                                    .foregroundStyle(exercise.enabled ? Color.primary : Color.secondary)
                                Spacer()
                                Text("\(exercise.duration)s")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onMove { from, to in
                        store.settings.exercises.move(fromOffsets: from, toOffset: to)
                    }
                    .onDelete { offsets in
                        store.settings.exercises.remove(atOffsets: offsets)
                    }
                    Button {
                        newExerciseName = ""
                        addingExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Exercises")
                } footer: {
                    Text("Tap the circle to include or skip an exercise. Swipe left to delete. Tap Edit to reorder.")
                }

                Section {
                    Button("Reset to defaults", role: .destructive) {
                        confirmingReset = true
                    }
                }
            }
            .navigationTitle("HIIT Timer")
            .toolbar {
                EditButton()
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    engine.start(with: store.settings)
                    showingWorkout = true
                } label: {
                    Text("Start Workout")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(store.settings.activeExercises.isEmpty)
                .padding()
                .background(.bar)
            }
            .confirmationDialog("Reset all settings to defaults?", isPresented: $confirmingReset,
                                titleVisibility: .visible) {
                Button("Reset", role: .destructive) {
                    store.settings = .standard
                }
            }
            .alert("New Exercise", isPresented: $addingExercise) {
                TextField("Name", text: $newExerciseName)
                Button("Add") {
                    let name = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        store.settings.exercises.append(
                            Exercise(name: name, duration: WorkoutSettings.defaultDuration))
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showingWorkout, onDismiss: { engine.stop() }) {
                WorkoutView(engine: engine)
            }
        }
    }

    private func settingRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
