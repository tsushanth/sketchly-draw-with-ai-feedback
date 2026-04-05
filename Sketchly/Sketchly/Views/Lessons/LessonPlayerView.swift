//
//  LessonPlayerView.swift
//  Sketchly
//

import SwiftUI
import PencilKit
import AVFoundation
import SwiftData

// MARK: - SVG Path Parser

func parseSVGPath(_ d: String) -> Path {
    var path = Path()
    let tokens = tokenizeSVGPath(d)
    var index = 0
    var currentPoint = CGPoint.zero
    var startPoint = CGPoint.zero

    func nextFloat() -> CGFloat? {
        while index < tokens.count {
            let t = tokens[index]
            if let v = Double(t) {
                index += 1
                return CGFloat(v)
            } else {
                return nil
            }
        }
        return nil
    }

    func nextPoint() -> CGPoint? {
        guard let x = nextFloat(), let y = nextFloat() else { return nil }
        return CGPoint(x: x, y: y)
    }

    while index < tokens.count {
        let token = tokens[index]
        // Check if token is a command letter
        guard token.count == 1, let cmd = token.first, cmd.isLetter, !"eE".contains(cmd) else {
            index += 1
            continue
        }
        index += 1

        switch cmd {
        case "M":
            if let pt = nextPoint() {
                path.move(to: pt)
                currentPoint = pt
                startPoint = pt
                // Additional coords become LineTo
                while index < tokens.count, let _ = Double(tokens[index]) {
                    if let pt2 = nextPoint() {
                        path.addLine(to: pt2)
                        currentPoint = pt2
                    } else { break }
                }
            }
        case "m":
            if let pt = nextPoint() {
                let abs = CGPoint(x: currentPoint.x + pt.x, y: currentPoint.y + pt.y)
                path.move(to: abs)
                currentPoint = abs
                startPoint = abs
                while index < tokens.count, let _ = Double(tokens[index]) {
                    if let pt2 = nextPoint() {
                        let abs2 = CGPoint(x: currentPoint.x + pt2.x, y: currentPoint.y + pt2.y)
                        path.addLine(to: abs2)
                        currentPoint = abs2
                    } else { break }
                }
            }
        case "L":
            while index < tokens.count, Double(tokens[index]) != nil {
                if let pt = nextPoint() {
                    path.addLine(to: pt)
                    currentPoint = pt
                } else { break }
            }
        case "l":
            while index < tokens.count, Double(tokens[index]) != nil {
                if let pt = nextPoint() {
                    let abs = CGPoint(x: currentPoint.x + pt.x, y: currentPoint.y + pt.y)
                    path.addLine(to: abs)
                    currentPoint = abs
                } else { break }
            }
        case "H":
            while index < tokens.count, let x = nextFloat() {
                let pt = CGPoint(x: x, y: currentPoint.y)
                path.addLine(to: pt)
                currentPoint = pt
            }
        case "h":
            while index < tokens.count, let dx = nextFloat() {
                let pt = CGPoint(x: currentPoint.x + dx, y: currentPoint.y)
                path.addLine(to: pt)
                currentPoint = pt
            }
        case "V":
            while index < tokens.count, let y = nextFloat() {
                let pt = CGPoint(x: currentPoint.x, y: y)
                path.addLine(to: pt)
                currentPoint = pt
            }
        case "v":
            while index < tokens.count, let dy = nextFloat() {
                let pt = CGPoint(x: currentPoint.x, y: currentPoint.y + dy)
                path.addLine(to: pt)
                currentPoint = pt
            }
        case "C":
            while index < tokens.count, Double(tokens[index]) != nil {
                guard let c1 = nextPoint(), let c2 = nextPoint(), let end = nextPoint() else { break }
                path.addCurve(to: end, control1: c1, control2: c2)
                currentPoint = end
            }
        case "c":
            while index < tokens.count, Double(tokens[index]) != nil {
                guard let dc1 = nextPoint(), let dc2 = nextPoint(), let dend = nextPoint() else { break }
                let c1 = CGPoint(x: currentPoint.x + dc1.x, y: currentPoint.y + dc1.y)
                let c2 = CGPoint(x: currentPoint.x + dc2.x, y: currentPoint.y + dc2.y)
                let end = CGPoint(x: currentPoint.x + dend.x, y: currentPoint.y + dend.y)
                path.addCurve(to: end, control1: c1, control2: c2)
                currentPoint = end
            }
        case "Q":
            while index < tokens.count, Double(tokens[index]) != nil {
                guard let ctrl = nextPoint(), let end = nextPoint() else { break }
                path.addQuadCurve(to: end, control: ctrl)
                currentPoint = end
            }
        case "q":
            while index < tokens.count, Double(tokens[index]) != nil {
                guard let dctrl = nextPoint(), let dend = nextPoint() else { break }
                let ctrl = CGPoint(x: currentPoint.x + dctrl.x, y: currentPoint.y + dctrl.y)
                let end = CGPoint(x: currentPoint.x + dend.x, y: currentPoint.y + dend.y)
                path.addQuadCurve(to: end, control: ctrl)
                currentPoint = end
            }
        case "Z", "z":
            path.closeSubpath()
            currentPoint = startPoint
        default:
            break
        }
    }
    return path
}

private func tokenizeSVGPath(_ d: String) -> [String] {
    var tokens: [String] = []
    var current = ""

    func flush() {
        let t = current.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { tokens.append(t) }
        current = ""
    }

    let commandLetters = CharacterSet.letters.subtracting(CharacterSet(charactersIn: "eE"))
    var prevChar: Character = " "

    for ch in d {
        let scalar = ch.unicodeScalars.first!
        if commandLetters.contains(scalar) {
            flush()
            tokens.append(String(ch))
        } else if ch == " " || ch == "," || ch == "\t" || ch == "\n" || ch == "\r" {
            flush()
        } else if ch == "-" && !current.isEmpty && prevChar != "e" && prevChar != "E" {
            // A minus sign in the middle of a number sequence starts a new token
            flush()
            current.append(ch)
        } else {
            current.append(ch)
        }
        prevChar = ch
    }
    flush()
    return tokens
}

// MARK: - Player State

enum PlayerState {
    case loadingPlan
    case watchingDemo(Int)
    case userTurn(Int)
    case evaluating(Int)
    case showingFeedback(Int, String, Bool)
    case lessonComplete
    case error(String)
}

// MARK: - LessonPlayerView

struct LessonPlayerView: View {
    let lesson: LessonModel
    @Environment(PremiumManager.self) private var premiumManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var state: PlayerState = .loadingPlan
    @State private var lessonPlan: DrawingLessonPlan?
    @State private var completedPaths: [String] = []
    @State private var animationTrigger = UUID()
    @State private var trimProgress: CGFloat = 0
    @State private var drawing = PKDrawing()
    @State private var synthesizer = AVSpeechSynthesizer()
    @State private var showPaywall = false

    // Display scale: SVG is 300x300, display area is ~260x260
    private let svgSize: CGFloat = 300
    private let displaySize: CGFloat = 260
    private var displayScale: CGFloat { displaySize / svgSize }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                switch state {
                case .lessonComplete:
                    completionScreen
                case .error(let msg):
                    errorScreen(msg)
                default:
                    mainLayout
                }
            }
            .navigationTitle(lesson.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        synthesizer.stopSpeaking(at: .immediate)
                        dismiss()
                    }
                }
            }
        }
        .onDisappear { synthesizer.stopSpeaking(at: .immediate) }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(premiumManager)
        }
        .reviewPrompt()
        .task {
            await loadPlan()
        }
    }

    // MARK: - Main Layout

    private var mainLayout: some View {
        VStack(spacing: 0) {
            // AI Demo panel
            ZStack {
                Color(.secondarySystemBackground)
                    .frame(height: 280)

                // SVG canvas
                ZStack {
                    // Completed paths in gray
                    ForEach(Array(completedPaths.enumerated()), id: \.offset) { _, svgPath in
                        parseSVGPath(svgPath)
                            .stroke(Color.primary.opacity(0.5), lineWidth: 2)
                            .frame(width: svgSize, height: svgSize)
                    }

                    // Animating current path in orange
                    if case .watchingDemo(let i) = state, let plan = lessonPlan, i < plan.steps.count {
                        parseSVGPath(plan.steps[i].newSVGPath)
                            .trim(from: 0, to: trimProgress)
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: svgSize, height: svgSize)
                    } else if let plan = lessonPlan {
                        // Show current step's path outline when not animating
                        let currentIndex = currentStepIndex
                        if currentIndex < plan.steps.count {
                            parseSVGPath(plan.steps[currentIndex].newSVGPath)
                                .stroke(Color.orange.opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4]))
                                .frame(width: svgSize, height: svgSize)
                        }
                    }
                }
                .scaleEffect(displayScale)

                // State overlay
                if !isWatching {
                    ZStack {
                        if isUserTurn {
                            // No overlay — just let user draw
                        } else {
                            Color.black.opacity(0.35)
                            VStack(spacing: 8) {
                                Image(systemName: stateIconName)
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                Text(stateOverlayLabel)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 280)
                }
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 0))

            // Step info bar
            if let plan = lessonPlan, currentStepIndex < plan.steps.count {
                HStack {
                    Text("Step \(currentStepIndex + 1) of \(plan.steps.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(plan.steps[currentStepIndex].description)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Instruction
                Text(plan.steps[currentStepIndex].instruction)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            } else {
                Spacer().frame(height: 16)
            }

            Divider()

            // User canvas
            ZStack {
                DrawingCanvasView(drawing: $drawing)

                // Block touches when watching demo
                if isWatching {
                    Color.black.opacity(0.01)
                        .contentShape(Rectangle())
                        .allowsHitTesting(true)
                }

                // Evaluating overlay
                if case .evaluating = state {
                    Color.black.opacity(0.5)
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.4)
                            .tint(.white)
                        Text("AI is evaluating your drawing…")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }

                // Feedback overlay
                if case .showingFeedback(_, let msg, let passed) = state {
                    Color.black.opacity(0.65)
                    VStack(spacing: 16) {
                        Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(passed ? .green : .red)
                        Text(passed ? "Great job!" : "Keep trying!")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(msg)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            // Bottom toolbar
            HStack(spacing: 16) {
                Button(action: { drawing = PKDrawing() }) {
                    Label("Clear", systemImage: "trash")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .disabled(!isUserTurn && !isFeedback)

                Spacer()

                mainActionButton
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private var mainActionButton: some View {
        switch state {
        case .loadingPlan:
            ProgressView()
                .frame(width: 120)
        case .watchingDemo:
            Button("Skip") {
                skipToUserTurn()
            }
            .buttonStyle(PrimaryButtonStyle())
        case .userTurn:
            Button("Submit Drawing") {
                Task { await submitDrawing() }
            }
            .buttonStyle(PrimaryButtonStyle())
        case .evaluating:
            ProgressView()
                .frame(width: 120)
        case .showingFeedback(let i, _, let passed):
            if passed {
                if let plan = lessonPlan, i + 1 < plan.steps.count {
                    Button("Next Step") {
                        advanceToNextStep(from: i)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Finish!") {
                        state = .lessonComplete
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            } else {
                Button("Try Again") {
                    drawing = PKDrawing()
                    state = .userTurn(currentStepIndex)
                }
                .buttonStyle(.bordered)
            }
        case .lessonComplete, .error:
            EmptyView()
        }
    }

    // MARK: - Completion Screen

    private var completionScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "star.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Lesson Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("You've drawn \(lessonPlan?.subject ?? lesson.title) step by step. Amazing work!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Show completed drawing
            ZStack {
                Color(.secondarySystemBackground)
                    .cornerRadius(16)
                ZStack {
                    ForEach(Array(completedPaths.enumerated()), id: \.offset) { _, svgPath in
                        parseSVGPath(svgPath)
                            .stroke(Color.primary.opacity(0.7), lineWidth: 2)
                            .frame(width: svgSize, height: svgSize)
                    }
                }
                .scaleEffect(displayScale)
            }
            .frame(width: displaySize + 20, height: displaySize + 20)
            .padding(.horizontal, 40)

            Spacer()

            // Paywall upsell for non-premium users
            if !premiumManager.isPremium {
                Button(action: { showPaywall = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text("Unlock All Lessons & AI Feedback")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(16)
                }
                .padding(.horizontal, 32)
            }

            Button(action: {
                synthesizer.stopSpeaking(at: .immediate)
                dismiss()
            }) {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(16)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Error Screen

    private func errorScreen(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("Couldn't load lesson")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") {
                Task { await loadPlan() }
            }
            .buttonStyle(.bordered)
            Spacer()
        }
    }

    // MARK: - State Machine

    private func loadPlan() async {
        state = .loadingPlan
        do {
            let plan = try await DrawingLessonService.shared.generateLessonPlan(
                title: lesson.title,
                category: lesson.categoryEnum.rawValue,
                difficulty: lesson.difficultyEnum.rawValue
            )
            lessonPlan = plan
            completedPaths = []
            await startWatchingStep(0)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func startWatchingStep(_ index: Int) async {
        guard let plan = lessonPlan, index < plan.steps.count else { return }
        let step = plan.steps[index]

        trimProgress = 0
        animationTrigger = UUID()
        state = .watchingDemo(index)

        speakInstruction(step.instruction, using: synthesizer)

        // Animate path drawing
        withAnimation(.linear(duration: 2.5)) {
            trimProgress = 1.0
        }

        // Wait for animation + give some time for speech
        try? await Task.sleep(nanoseconds: 3_500_000_000)

        // Auto-advance to user turn (only if still watching this step)
        if case .watchingDemo(let i) = state, i == index {
            state = .userTurn(index)
        }
    }

    private func skipToUserTurn() {
        if case .watchingDemo(let i) = state {
            trimProgress = 1.0
            state = .userTurn(i)
        }
    }

    private func submitDrawing() async {
        guard case .userTurn(let i) = state,
              let plan = lessonPlan,
              i < plan.steps.count else { return }

        state = .evaluating(i)

        guard let image = exportCanvasAsImage(drawing) else {
            state = .showingFeedback(i, "Good work! Moving on.", true)
            return
        }

        do {
            let evaluation = try await DrawingLessonService.shared.evaluateStep(
                userImage: image,
                step: plan.steps[i],
                subject: plan.subject
            )
            state = .showingFeedback(i, evaluation.feedback, evaluation.passed)
        } catch {
            state = .showingFeedback(i, "Good work! Moving on.", true)
        }
    }

    private func advanceToNextStep(from index: Int) {
        guard let plan = lessonPlan else { return }

        // Append this step's path to completed
        if index < plan.steps.count {
            completedPaths.append(plan.steps[index].newSVGPath)
        }

        let nextIndex = index + 1
        if nextIndex < plan.steps.count {
            Task {
                await startWatchingStep(nextIndex)
            }
        } else {
            markLessonComplete()
            state = .lessonComplete
        }
    }

    // MARK: - Helpers

    private var currentStepIndex: Int {
        switch state {
        case .watchingDemo(let i): return i
        case .userTurn(let i): return i
        case .evaluating(let i): return i
        case .showingFeedback(let i, _, _): return i
        default: return 0
        }
    }

    private var isWatching: Bool {
        if case .watchingDemo = state { return true }
        return false
    }

    private var isUserTurn: Bool {
        if case .userTurn = state { return true }
        return false
    }

    private var isFeedback: Bool {
        if case .showingFeedback = state { return true }
        return false
    }

    private var stateOverlayLabel: String {
        switch state {
        case .loadingPlan: return "Preparing your lesson…"
        case .evaluating: return "Evaluating…"
        case .showingFeedback: return ""
        case .lessonComplete: return "Complete!"
        case .error: return "Error"
        default: return ""
        }
    }

    private var stateIconName: String {
        switch state {
        case .loadingPlan: return "sparkles"
        case .evaluating: return "magnifyingglass"
        case .lessonComplete: return "star.fill"
        default: return "pencil.tip"
        }
    }

    private func markLessonComplete() {
        guard !lesson.isCompleted else { return }
        let descriptor = FetchDescriptor<UserProgressModel>()
        if let progress = try? modelContext.fetch(descriptor).first {
            LessonService.shared.markLessonComplete(lesson, progress: progress)
            try? modelContext.save()
        }
        ReviewManager.shared.recordSuccessfulAction()
        premiumManager.recordLessonCompleted()

        // Show paywall nudge after a delay so they see their completed drawing first
        if premiumManager.shouldShowPostLessonPaywall() {
            premiumManager.recordPostLessonPaywallShown()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showPaywall = true
            }
        }
    }

}

// MARK: - Primary Button Style

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .cornerRadius(12)
    }
}
