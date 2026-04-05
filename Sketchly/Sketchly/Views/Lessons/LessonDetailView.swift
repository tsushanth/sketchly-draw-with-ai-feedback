//
//  LessonDetailView.swift
//  Sketchly
//

import SwiftUI
import SwiftData

struct LessonDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumManager.self) private var premiumManager
    let lesson: LessonModel

    @State private var lessonContent: AILessonContent?
    @State private var isLoadingContent = false
    @State private var loadError: String?
    @State private var expandedSteps: Set<UUID> = []
    @State private var showPractice = false
    @State private var showPaywall = false
    @State private var showCompletionAlert = false
    @State private var showPlayer = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    lessonHeader

                    // Content
                    if isLoadingContent {
                        loadingView
                    } else if let error = loadError {
                        errorView(error)
                    } else if let content = lessonContent {
                        lessonBody(content)
                    }

                    Spacer(minLength: 100)
                }
            }
            .navigationTitle(lesson.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        lesson.isFavorited.toggle()
                        try? modelContext.save()
                        HapticManager.impact(style: .light)
                    }) {
                        Image(systemName: lesson.isFavorited ? "heart.fill" : "heart")
                            .foregroundStyle(lesson.isFavorited ?
                                AnyShapeStyle(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)) :
                                AnyShapeStyle(Color.secondary))
                    }
                }
            }
        }
        .sheet(isPresented: $showPractice) {
            PracticeView(associatedLesson: lesson)
                .environment(premiumManager)
        }
        .fullScreenCover(isPresented: $showPlayer) {
            LessonPlayerView(lesson: lesson)
                .environment(premiumManager)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(premiumManager)
        }
        .alert("Lesson Complete!", isPresented: $showCompletionAlert) {
            Button("Practice Now") { showPractice = true }
            Button("Done", role: .cancel) { dismiss() }
        } message: {
            Text("You've read through all the steps for '\(lesson.title)'. Open the canvas and draw it!")
        }
        .task {
            await loadLessonContent()
        }
        .onAppear {
            AnalyticsService.shared.track(.lessonStarted(
                lessonId: lesson.id.uuidString,
                category: lesson.category
            ))
        }
    }

    // MARK: - Header

    private var lessonHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [lesson.categoryEnum.color, lesson.categoryEnum.color.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 160)

            Image(systemName: lesson.categoryEnum.icon)
                .font(.system(size: 90))
                .foregroundColor(.white.opacity(0.15))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 20)
                .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Label(lesson.categoryEnum.rawValue, systemImage: lesson.categoryEnum.icon)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))

                    Label("\(lesson.duration) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))

                    Label(lesson.difficultyEnum.rawValue, systemImage: lesson.difficultyEnum.icon)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }

                if lesson.isPremium {
                    Label("Premium Lesson", systemImage: "crown.fill")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                }
            }
            .padding()
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            ProgressView()
                .scaleEffect(1.2)
            VStack(spacing: 6) {
                Text("AI is preparing your lesson…")
                    .font(.headline)
                Text("Claude is crafting personalized step-by-step instructions for \"\(lesson.title)\"")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
        .frame(minHeight: 300)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
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
                Task { await loadLessonContent() }
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .frame(minHeight: 300)
    }

    // MARK: - Lesson Body

    private func lessonBody(_ content: AILessonContent) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // Intro
            VStack(alignment: .leading, spacing: 10) {
                Text("What you'll learn")
                    .font(.headline)
                Text(content.intro)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Materials
                if !content.materials.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(content.materials, id: \.self) { material in
                            Text(material)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(20)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)

            Divider().padding(.horizontal)

            // Steps
            VStack(alignment: .leading, spacing: 12) {
                Text("Step-by-Step Instructions")
                    .font(.headline)
                    .padding(.horizontal)

                ForEach(content.steps) { step in
                    StepCard(step: step, isExpanded: expandedSteps.contains(step.id)) {
                        withAnimation(.spring(response: 0.3)) {
                            if expandedSteps.contains(step.id) {
                                expandedSteps.remove(step.id)
                            } else {
                                expandedSteps.insert(step.id)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Divider().padding(.horizontal)

            // Final Challenge
            VStack(alignment: .leading, spacing: 8) {
                Label("Final Challenge", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundColor(.orange)
                Text(content.finalChallenge)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color.orange.opacity(0.08))
            .cornerRadius(12)
            .padding(.horizontal)

            // Start Lesson button
            Button(action: {
                if lesson.isPremium && !premiumManager.isPremium {
                    showPaywall = true
                } else {
                    showPlayer = true
                }
                HapticManager.impact(style: .medium)
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Lesson")
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
            .padding(.horizontal)
        }
    }

    // MARK: - Helpers

    private func loadLessonContent() async {
        isLoadingContent = true
        loadError = nil
        do {
            lessonContent = try await LessonContentService.shared.generateLesson(
                title: lesson.title,
                category: lesson.categoryEnum.rawValue,
                difficulty: lesson.difficultyEnum.rawValue,
                durationMinutes: lesson.duration
            )
            // Auto-expand first step
            if let first = lessonContent?.steps.first {
                expandedSteps.insert(first.id)
            }
        } catch {
            loadError = error.localizedDescription
        }
        isLoadingContent = false
    }

    private func markComplete() {
        guard !lesson.isCompleted else { return }
        let descriptor = FetchDescriptor<UserProgressModel>()
        if let progress = try? modelContext.fetch(descriptor).first {
            LessonService.shared.markLessonComplete(lesson, progress: progress)
            try? modelContext.save()
        }
    }
}

// MARK: - Step Card

struct StepCard: View {
    let step: AILessonStep
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button(action: onTap) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isExpanded ? Color.orange : Color.orange.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Text("\(step.number)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(isExpanded ? .white : .orange)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text("\(step.durationMinutes) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()

                    Text(step.instruction)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)

                    if let tip = step.tip {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                                .padding(.top, 2)
                            Text(tip)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)
                    }

                    Spacer().frame(height: 4)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
