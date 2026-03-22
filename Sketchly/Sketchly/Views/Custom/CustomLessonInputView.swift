//
//  CustomLessonInputView.swift
//  Sketchly
//
//  User types a subject → server creates a lesson → navigates to player.
//

import SwiftUI

struct CustomLessonInputView: View {
    @Environment(PremiumManager.self) private var premiumManager
    @Environment(\.dismiss) private var dismiss

    @State private var subject = ""
    @State private var selectedDifficulty: String = "beginner"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lessonResponse: CustomLessonResponse?
    @State private var showPlayer = false
    @State private var showPaywall = false

    private let difficulties = ["beginner", "intermediate", "advanced"]
    private let suggestions = [
        "Cat face", "Rose flower", "Wolf", "Butterfly",
        "Cartoon dog", "Human eye", "Tree", "Fish",
        "Car", "House", "Dragon head", "Bird"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 44))
                            .foregroundStyle(
                                LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                            )
                        Text("Custom Drawing Lesson")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Tell us what you want to draw and AI will create a step-by-step lesson for you.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 20)

                    // Subject input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What do you want to draw?")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack(spacing: 10) {
                            Image(systemName: "pencil.tip")
                                .foregroundColor(.orange)
                            TextField("e.g. Wolf, Cat face, Rose...", text: $subject)
                                .textFieldStyle(.plain)
                                .submitLabel(.go)
                                .onSubmit { startLesson() }
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Quick suggestions
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quick picks")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        FlowLayout(spacing: 8) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button {
                                    subject = suggestion
                                    HapticManager.selection()
                                } label: {
                                    Text(suggestion)
                                        .font(.subheadline)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(subject == suggestion ? Color.orange.opacity(0.2) : Color(.secondarySystemBackground))
                                        .foregroundColor(subject == suggestion ? .orange : .primary)
                                        .cornerRadius(20)
                                        .overlay(
                                            Capsule()
                                                .stroke(subject == suggestion ? Color.orange : Color.clear, lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Difficulty picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Difficulty")
                            .font(.headline)
                            .padding(.horizontal)

                        Picker("Difficulty", selection: $selectedDifficulty) {
                            ForEach(difficulties, id: \.self) { level in
                                Text(level.capitalized).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        Text(difficultyDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }

                    // Info banner
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.subheadline)
                        Text("Custom lessons are created on the fly and don't save progress. Complete them in one sitting!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(10)
                    .padding(.horizontal)

                    // Error message
                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal)
                    }

                    // Start button
                    Button(action: startLesson) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                Text("Creating lesson...")
                            } else {
                                Image(systemName: "play.fill")
                                Text("Create Lesson")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: subject.trimmingCharacters(in: .whitespaces).isEmpty || isLoading
                                    ? [.gray] : [.orange, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                    }
                    .disabled(subject.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Custom Lesson")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            if let response = lessonResponse {
                CustomLessonPlayerView(lessonResponse: response)
                    .environment(premiumManager)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(premiumManager)
        }
    }

    private var difficultyDescription: String {
        switch selectedDifficulty {
        case "beginner": return "More steps with simpler shapes (8-10 steps)"
        case "intermediate": return "Moderate detail with fewer guidance (6-8 steps)"
        case "advanced": return "Minimal steps, you fill in the details (4-5 steps)"
        default: return ""
        }
    }

    private func startLesson() {
        let trimmed = subject.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Premium check
        if !premiumManager.isPremium {
            showPaywall = true
            AnalyticsService.shared.track(.paywallViewed(trigger: "custom_lesson"))
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await CustomLessonService.shared.createLesson(
                    subject: trimmed,
                    difficulty: selectedDifficulty,
                    mode: "ai"
                )
                lessonResponse = response
                showPlayer = true
                AnalyticsService.shared.track(.lessonStarted(
                    lessonId: "custom_\(response.sessionId)",
                    category: "custom"
                ))
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Flow Layout (wrapping tag layout)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
