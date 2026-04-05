//
//  CustomLessonPlayerView.swift
//  Sketchly
//
//  Step-by-step lesson player for custom (server-generated) lessons.
//  Uses the same SVG demo + PencilKit canvas approach as LessonPlayerView,
//  but all evaluation goes through the server agent which holds session state.
//

import SwiftUI
import PencilKit
import AVFoundation

struct CustomLessonPlayerView: View {
    let lessonResponse: CustomLessonResponse

    @Environment(PremiumManager.self) private var premiumManager
    @Environment(\.dismiss) private var dismiss

    // State machine
    @State private var state: CustomPlayerState = .preview
    @State private var sessionId: String = ""
    @State private var allSteps: [CustomLessonStep] = []
    @State private var completedPaths: [String] = []
    @State private var currentStepIndex: Int = 0

    // Animation
    @State private var trimProgress: CGFloat = 0

    // Drawing
    @State private var drawing = PKDrawing()

    // TTS
    @State private var synthesizer = AVSpeechSynthesizer()

    // Evaluation results
    @State private var lastFeedback: String = ""
    @State private var lastPassed: Bool = false
    @State private var lastScore: Int?
    @State private var weakSteps: [WeakStep] = []
    @State private var lessonSummary: LessonSummary?

    // Revisit
    @State private var showRevisitSheet = false
    @State private var showPaywall = false

    private let svgSize: CGFloat = 300
    private let displaySize: CGFloat = 260
    private var displayScale: CGFloat { displaySize / svgSize }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                switch state {
                case .preview:
                    previewScreen
                case .complete:
                    completionScreen
                case .error(let msg):
                    errorScreen(msg)
                default:
                    mainLayout
                }
            }
            .navigationTitle(lessonResponse.subject)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        synthesizer.stopSpeaking(at: .immediate)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !weakSteps.isEmpty {
                        Button {
                            showRevisitSheet = true
                        } label: {
                            Label("Revisit", systemImage: "arrow.counterclockwise")
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .onDisappear { synthesizer.stopSpeaking(at: .immediate) }
        .sheet(isPresented: $showRevisitSheet) {
            revisitSheet
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(premiumManager)
        }
        .onAppear {
            sessionId = lessonResponse.sessionId
            allSteps = buildAllSteps()
            // Fetch all steps from server for the preview
            Task { await loadAllSteps() }
        }
    }

    // MARK: - Build steps from initial response

    private func buildAllSteps() -> [CustomLessonStep] {
        return [lessonResponse.step]
    }

    private func loadAllSteps() async {
        do {
            let session = try await CustomLessonService.shared.getSession(sessionId: sessionId)
            allSteps = session.steps
        } catch {
            // If we can't load all steps, we still have step 0 — preview with what we have
        }
    }

    // MARK: - Preview Screen

    private var previewScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Here's what we'll draw")
                .font(.title2)
                .fontWeight(.bold)

            Text(lessonResponse.subject.capitalized)
                .font(.headline)
                .foregroundColor(.orange)

            // Show all SVG paths combined
            ZStack {
                Color(.secondarySystemBackground)
                    .cornerRadius(20)

                ZStack {
                    ForEach(Array(allSteps.enumerated()), id: \.offset) { _, step in
                        parseSVGPath(step.newSvgPath)
                            .stroke(Color.primary.opacity(0.7), lineWidth: 2)
                            .frame(width: svgSize, height: svgSize)
                    }
                }
                .scaleEffect(displayScale)
            }
            .frame(width: displaySize + 40, height: displaySize + 40)

            // Step count and time estimate
            HStack(spacing: 20) {
                Label("\(lessonResponse.totalSteps) steps", systemImage: "list.number")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Label("~\(lessonResponse.estimatedMinutes) min", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("Follow each step to recreate this drawing.\nYour canvas builds up as you go!")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button {
                startWatchingStep(0)
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Drawing")
                }
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

    // MARK: - Main Layout

    private var mainLayout: some View {
        VStack(spacing: 0) {
            // SVG Demo panel
            ZStack {
                Color(.secondarySystemBackground)
                    .frame(height: 280)

                ZStack {
                    // Completed paths in gray
                    ForEach(Array(completedPaths.enumerated()), id: \.offset) { _, svgPath in
                        parseSVGPath(svgPath)
                            .stroke(Color.primary.opacity(0.5), lineWidth: 2)
                            .frame(width: svgSize, height: svgSize)
                    }

                    // Current step path
                    if currentStepIndex < allSteps.count {
                        let currentPath = allSteps[currentStepIndex].newSvgPath

                        if case .watchingDemo = state {
                            // Animated drawing
                            parseSVGPath(currentPath)
                                .trim(from: 0, to: trimProgress)
                                .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: svgSize, height: svgSize)
                        } else {
                            // Static dashed outline
                            parseSVGPath(currentPath)
                                .stroke(Color.orange.opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4]))
                                .frame(width: svgSize, height: svgSize)
                        }
                    }
                }
                .scaleEffect(displayScale)

                // Overlay for non-interactive states
                if case .evaluating = state {
                    Color.black.opacity(0.35)
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                        Text("AI is evaluating...")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(height: 280)

            // Step info bar
            if currentStepIndex < allSteps.count {
                let step = allSteps[currentStepIndex]
                HStack {
                    Text("Step \(currentStepIndex + 1) of \(lessonResponse.totalSteps)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(step.description)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)

                    if let hint = step.symmetryHint {
                        Image(systemName: "arrow.left.and.right")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .help(hint)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Instruction text
                Text(allSteps[currentStepIndex].instruction)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            Divider()

            // User canvas
            ZStack {
                DrawingCanvasView(drawing: $drawing)

                // Block touches during demo
                if case .watchingDemo = state {
                    Color.black.opacity(0.01)
                        .contentShape(Rectangle())
                        .allowsHitTesting(true)
                }

                // Evaluating overlay on canvas
                if case .evaluating = state {
                    Color.black.opacity(0.5)
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.4)
                            .tint(.white)
                        Text("AI is evaluating your drawing...")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }

                // Feedback overlay
                if case .showingFeedback = state {
                    Color.black.opacity(0.65)
                    VStack(spacing: 16) {
                        Image(systemName: lastPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(lastPassed ? .green : .red)

                        if let score = lastScore {
                            HStack(spacing: 4) {
                                ForEach(0..<10, id: \.self) { i in
                                    Circle()
                                        .fill(i < score ? scoreColor(score) : Color.white.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                }
                            }
                            Text("\(score)/10")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }

                        Text(lastPassed ? "Great job!" : "Keep trying!")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text(lastFeedback)
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
                .disabled(!isInteractive)

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
        case .preview:
            EmptyView()

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

        case .showingFeedback:
            if lastPassed {
                if currentStepIndex + 1 < lessonResponse.totalSteps {
                    Button("Next Step") {
                        advanceToNextStep()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Finish!") {
                        finishLesson()
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

        case .complete, .error:
            EmptyView()
        }
    }

    // MARK: - Completion Screen

    private var completionScreen: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                Image(systemName: "star.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)

                Text("Lesson Complete!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("You've drawn \(lessonResponse.subject) step by step!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Completed drawing
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

                // Summary stats
                if let summary = lessonSummary {
                    VStack(spacing: 12) {
                        HStack(spacing: 24) {
                            StatBubble(label: "Score", value: "\(summary.averageScore)/10", color: scoreColor(summary.averageScore))
                            StatBubble(label: "Steps", value: "\(summary.stepsCompleted)/\(summary.totalSteps)", color: .blue)
                            StatBubble(label: "Attempts", value: "\(summary.totalAttempts)", color: .purple)
                        }
                    }
                    .padding(.horizontal)

                    // Weak steps to revisit
                    if let weak = summary.weakSteps, !weak.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Could improve")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            ForEach(weak, id: \.stepIndex) { ws in
                                HStack {
                                    Text("Step \(ws.stepIndex + 1): \(ws.description)")
                                        .font(.caption)
                                    Spacer()
                                    Text("\(ws.score ?? 0)/10")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                    Button("Revisit") {
                                        revisitStepAt(ws.stepIndex)
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                }
                                .padding(10)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }
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
    }

    // MARK: - Error Screen

    private func errorScreen(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("Something went wrong")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") {
                state = .userTurn(currentStepIndex)
            }
            .buttonStyle(.bordered)
            Button("Close") { dismiss() }
                .buttonStyle(.bordered)
            Spacer()
        }
    }

    // MARK: - Revisit Sheet

    private var revisitSheet: some View {
        NavigationStack {
            List {
                Section("Steps you can improve") {
                    ForEach(weakSteps, id: \.stepIndex) { ws in
                        Button {
                            showRevisitSheet = false
                            revisitStepAt(ws.stepIndex)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Step \(ws.stepIndex + 1): \(ws.description)")
                                        .font(.subheadline)
                                    if let suggestion = ws.suggestion {
                                        Text(suggestion)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(ws.score ?? 0)/10")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Revisit Steps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showRevisitSheet = false }
                }
            }
        }
    }

    // MARK: - State Machine

    private func startWatchingStep(_ index: Int) {
        currentStepIndex = index
        trimProgress = 0
        state = .watchingDemo(index)

        if index < allSteps.count {
            speakInstruction(allSteps[index].instruction, using: synthesizer)
        }

        // Animate path
        withAnimation(.linear(duration: 2.5)) {
            trimProgress = 1.0
        }

        // Auto-advance to user turn after animation
        Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if case .watchingDemo(let i) = state, i == index {
                state = .userTurn(index)
            }
        }
    }

    private func skipToUserTurn() {
        if case .watchingDemo(let i) = state {
            trimProgress = 1.0
            state = .userTurn(i)
        }
    }

    private func submitDrawing() async {
        guard case .userTurn(let i) = state else { return }

        state = .evaluating(i)

        guard let image = exportCanvasAsImage(drawing) else {
            lastPassed = true
            lastFeedback = "Good work! Moving on."
            lastScore = 6
            state = .showingFeedback(i)
            return
        }

        do {
            let evaluation = try await CustomLessonService.shared.evaluateStep(
                sessionId: sessionId,
                stepIndex: i,
                image: image
            )

            lastPassed = evaluation.passed
            lastFeedback = evaluation.feedback
            lastScore = evaluation.score
            weakSteps = evaluation.weakSteps ?? weakSteps

            // If server sent next step, store it
            if let nextStep = evaluation.nextStep {
                if allSteps.count <= i + 1 {
                    allSteps.append(nextStep)
                } else {
                    allSteps[i + 1] = nextStep
                }
            }

            // Store summary if lesson complete
            if let summary = evaluation.summary {
                lessonSummary = summary
            }

            state = .showingFeedback(i)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func advanceToNextStep() {
        // Add current step's path to completed
        if currentStepIndex < allSteps.count {
            completedPaths.append(allSteps[currentStepIndex].newSvgPath)
        }

        let nextIndex = currentStepIndex + 1
        if nextIndex < lessonResponse.totalSteps {
            // Keep the drawing — user builds on previous steps
            startWatchingStep(nextIndex)
        } else {
            finishLesson()
        }
    }

    private func finishLesson() {
        state = .complete
        premiumManager.recordLessonCompleted()

        if premiumManager.shouldShowPostLessonPaywall() {
            premiumManager.recordPostLessonPaywallShown()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showPaywall = true
            }
        }
    }

    private func revisitStepAt(_ stepIndex: Int) {
        Task {
            do {
                let response = try await CustomLessonService.shared.revisitStep(
                    sessionId: sessionId,
                    stepIndex: stepIndex
                )

                // Update step data
                if stepIndex < allSteps.count {
                    allSteps[stepIndex] = response.step
                }

                drawing = PKDrawing()
                currentStepIndex = stepIndex

                // Rebuild completedPaths up to (but not including) this step
                completedPaths = Array(allSteps.prefix(stepIndex).map(\.newSvgPath))

                startWatchingStep(stepIndex)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Helpers

    private var isInteractive: Bool {
        switch state {
        case .userTurn, .showingFeedback: return true
        default: return false
        }
    }

}

// MARK: - State Enum

enum CustomPlayerState {
    case preview         // Show full drawing before starting
    case watchingDemo(Int)
    case userTurn(Int)
    case evaluating(Int)
    case showingFeedback(Int)
    case complete
    case error(String)
}

// MARK: - Stat Bubble

struct StatBubble: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}
