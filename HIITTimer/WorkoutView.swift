import SwiftUI
import UIKit

struct WorkoutView: View {
    @ObservedObject var engine: WorkoutEngine
    @Environment(\.dismiss) private var dismiss

    private var background: Color {
        if engine.isFinished { return Color(red: 0.35, green: 0.25, blue: 0.75) }
        switch engine.currentStep?.kind {
        case .work: return Color(red: 0.85, green: 0.25, blue: 0.15)
        case .rest: return Color(red: 0.10, green: 0.45, blue: 0.75)
        default: return Color(red: 0.90, green: 0.55, blue: 0.10)
        }
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            VStack(spacing: 24) {
                header
                Spacer()
                if engine.isFinished {
                    finished
                } else if let step = engine.currentStep {
                    active(step)
                }
                Spacer()
                if !engine.isFinished {
                    controls
                }
            }
            .padding()
            .foregroundStyle(.white)
        }
        .animation(.easeInOut(duration: 0.3), value: engine.index)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .padding(12)
                    .background(.white.opacity(0.2), in: Circle())
            }
            .accessibilityLabel("End workout")
            Spacer()
            if !engine.isFinished {
                Text("\(formatTime(engine.totalSecondsLeft)) left")
                    .font(.headline)
                    .monospacedDigit()
            }
        }
    }

    private func active(_ step: WorkoutStep) -> some View {
        VStack(spacing: 14) {
            if step.kind != .prepare {
                Text("Round \(step.round) · Exercise \(step.exerciseNumber)")
                    .font(.subheadline.weight(.semibold))
                    .opacity(0.85)
            }
            Text(step.title)
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(2)

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.25), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: 1 - engine.stepProgress)
                    .stroke(.white, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                // Shows the current exercise, or a preview of the next one while resting.
                FigureView(animation: FigureLibrary.animation(for: figureName(for: step)),
                           paused: engine.isPaused)
                    .padding(44)
                    .opacity(step.kind == .work ? 1 : 0.6)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 280, maxHeight: 280)

            Text("\(engine.secondsLeft)")
                .font(.system(size: 84, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)

            Text(step.next.map { "Next: \($0)" } ?? "Last one!")
                .font(.title3.weight(.semibold))
                .opacity(0.9)
        }
    }

    private func figureName(for step: WorkoutStep) -> String {
        step.kind == .work ? step.title : (step.next ?? step.title)
    }

    private var finished: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 96))
            Text("Workout Complete")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.25), in: Capsule())
            }
            .padding(.top, 12)
        }
    }

    private var controls: some View {
        HStack(spacing: 36) {
            controlButton("backward.fill", label: "Previous", size: 24) { engine.skipBack() }
            controlButton(engine.isPaused ? "play.fill" : "pause.fill",
                          label: engine.isPaused ? "Resume" : "Pause", size: 36) { engine.togglePause() }
            controlButton("forward.fill", label: "Skip", size: 24) { engine.skipForward() }
        }
        .padding(.bottom, 12)
    }

    private func controlButton(_ icon: String, label: String, size: CGFloat,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .bold))
                .frame(width: size * 2.4, height: size * 2.4)
                .background(.white.opacity(0.2), in: Circle())
        }
        .accessibilityLabel(label)
    }
}
