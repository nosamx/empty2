import SwiftUI

extension FigureLibrary {
    /// Picks an animation from the exercise name, so renamed or custom
    /// exercises with a recognisable name still get the right figure.
    static func animation(for name: String) -> FigureAnimation {
        let n = name.lowercased().replacingOccurrences(of: "-", with: " ")
        func has(_ words: String...) -> Bool { words.contains { n.contains($0) } }

        let isPushup = has("push", "press up")
        if has("diamond") { return diamondPushups }
        if has("wide") && isPushup { return widePushups }
        if isPushup { return pushups }
        if has("pull", "chin up", "chinup") { return pullUps }
        if has("squat") { return squats }
        if has("calf") { return calfRaises }
        if has("wall sit") { return wallSits }
        if has("side plank") { return has("left") ? sidePlankLeft : sidePlankRight }
        if has("plank") { return planks }
        if has("burpee") { return burpees }
        if has("mountain") { return mountainClimbers }
        if has("lunge") { return lunges }
        if has("twist") { return russianTwists }
        if has("bicycle", "crunch") { return bicycleCrunches }
        return generic
    }
}

/// An animated stick figure that loops through an exercise's key poses.
struct FigureView: View {
    let animation: FigureAnimation
    var paused = false

    var body: some View {
        TimelineView(.animation(paused: paused)) { timeline in
            Canvas { context, size in
                draw(in: &context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func pose(at time: Double) -> [CGFloat] {
        let frames = animation.frames
        guard frames.count > 1 else { return frames.first ?? [] }
        let position = time / animation.segment
        let index = Int(position.rounded(.down))
        let fraction = position - Double(index)
        let eased = CGFloat(0.5 - 0.5 * cos(Double.pi * fraction))
        let from = frames[((index % frames.count) + frames.count) % frames.count]
        let to = frames[(((index + 1) % frames.count) + frames.count) % frames.count]
        return zip(from, to).map { $0 + ($1 - $0) * eased }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let values = pose(at: time)
        guard values.count >= 26 else { return }
        let scale = min(size.width, size.height) / 100
        let origin = CGPoint(x: (size.width - 100 * scale) / 2, y: (size.height - 100 * scale) / 2)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }
        func joint(_ i: Int) -> CGPoint { point(values[i * 2], values[i * 2 + 1]) }
        func line(_ joints: [Int]) -> Path {
            var path = Path()
            path.move(to: joint(joints[0]))
            for j in joints.dropFirst() { path.addLine(to: joint(j)) }
            return path
        }

        // Ground and equipment.
        var scenery = Path()
        if animation.showsGround {
            scenery.move(to: point(4, 91))
            scenery.addLine(to: point(96, 91))
        }
        for prop in animation.props where prop.count == 4 {
            scenery.move(to: point(prop[0], prop[1]))
            scenery.addLine(to: point(prop[2], prop[3]))
        }
        context.stroke(scenery, with: .color(.white.opacity(0.4)),
                       style: StrokeStyle(lineWidth: 1.5 * scale, lineCap: .round))

        let limb = StrokeStyle(lineWidth: 4.5 * scale, lineCap: .round, lineJoin: .round)
        let far = GraphicsContext.Shading.color(.white.opacity(0.55))
        let near = GraphicsContext.Shading.color(.white)
        context.stroke(line([1, 3, 4]), with: far, style: limb)
        context.stroke(line([2, 7, 8, 9]), with: far, style: limb)
        context.stroke(line([1, 2]), with: near, style: limb)
        context.stroke(line([2, 10, 11, 12]), with: near, style: limb)
        context.stroke(line([1, 5, 6]), with: near, style: limb)

        let head = joint(0)
        let radius = 6.5 * scale
        context.fill(Path(ellipseIn: CGRect(x: head.x - radius, y: head.y - radius,
                                            width: radius * 2, height: radius * 2)), with: near)
    }
}
