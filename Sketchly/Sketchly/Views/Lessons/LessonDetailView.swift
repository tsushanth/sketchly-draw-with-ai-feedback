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

    @State private var isPlaying: Bool = false
    @State private var progress: Double = 0
    @State private var showPractice: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showCompletionAlert: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Video Placeholder
                    videoPlayerArea

                    // Lesson Info
                    lessonInfo

                    // Description
                    lessonDescription

                    // Exercises section
                    exercisesSection

                    // Practice button
                    practiceButton
                        .padding()

                    Spacer(minLength: 80)
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
                                AnyShapeStyle(Color.secondary)
                            )
                    }
                }
            }
        }
        .sheet(isPresented: $showPractice) {
            PracticeView(associatedLesson: lesson)
                .environment(premiumManager)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(premiumManager)
        }
        .alert("Lesson Complete!", isPresented: $showCompletionAlert) {
            Button("Keep Drawing") {
                showPractice = true
            }
            Button("Done", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Great job finishing '\(lesson.title)'! Practice what you learned in the canvas.")
        }
        .onAppear {
            AnalyticsService.shared.track(.lessonStarted(
                lessonId: lesson.id.uuidString,
                category: lesson.category
            ))
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            if isPlaying && progress < 1.0 {
                progress += 0.003
            } else if progress >= 1.0 {
                isPlaying = false
                markComplete()
            }
        }
    }

    // MARK: - Video Player Area
    private var videoPlayerArea: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [lesson.categoryEnum.color.opacity(0.8), lesson.categoryEnum.color.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 220)

            // Category icon
            Image(systemName: lesson.categoryEnum.icon)
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.3))

            // Play button overlay
            VStack {
                Spacer()
                HStack {
                    // Play/Pause
                    Button(action: {
                        isPlaying.toggle()
                        HapticManager.impact(style: .light)
                    }) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    Spacer()

                    // Progress
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(timeString(from: progress))
                            .font(.caption)
                            .foregroundColor(.white)
                        Text("/ \(lesson.duration) min")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding()

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 3)

                        Rectangle()
                            .fill(Color.white)
                            .frame(width: geo.size.width * progress, height: 3)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .frame(height: 220)
    }

    // MARK: - Lesson Info
    private var lessonInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.title)
                        .font(.title3)
                        .fontWeight(.bold)

                    HStack(spacing: 12) {
                        Label(lesson.categoryEnum.rawValue, systemImage: lesson.categoryEnum.icon)
                            .font(.caption)
                            .foregroundColor(lesson.categoryEnum.color)

                        Label("\(lesson.duration) min", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label(lesson.difficultyEnum.rawValue, systemImage: lesson.difficultyEnum.icon)
                            .font(.caption)
                            .foregroundColor(lesson.difficultyEnum.color)
                    }
                }

                Spacer()

                if lesson.isPremium {
                    PremiumBadge()
                }
            }

            if lesson.isCompleted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Completed")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
    }

    // MARK: - Description
    private var lessonDescription: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About This Lesson")
                .font(.headline)
                .padding(.horizontal)

            Text(lesson.lessonDescription.isEmpty ?
                 "Learn the fundamentals of \(lesson.title.lowercased()) with step-by-step guidance. This lesson covers all the core techniques you need to improve your drawing skills." :
                 lesson.lessonDescription
            )
            .font(.body)
            .foregroundColor(.secondary)
            .padding(.horizontal)

            Divider()
                .padding(.vertical, 8)
        }
    }

    // MARK: - Exercises
    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                exerciseRow(number: 1, title: "Warm-up sketch", duration: "5 min", isCompleted: false)
                exerciseRow(number: 2, title: "Follow along with instructor", duration: "\(max(5, lesson.duration - 10)) min", isCompleted: false)
                exerciseRow(number: 3, title: "Independent practice", duration: "5 min", isCompleted: false)
            }
            .padding(.horizontal)
        }
    }

    private func exerciseRow(number: Int, title: String, duration: String, isCompleted: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green : Color.orange.opacity(0.2))
                    .frame(width: 32, height: 32)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(duration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    // MARK: - Practice Button
    private var practiceButton: some View {
        Button(action: {
            showPractice = true
            HapticManager.impact(style: .medium)
        }) {
            HStack {
                Image(systemName: "pencil.tip")
                Text("Practice on Canvas")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [.orange, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
        }
    }

    private func markComplete() {
        guard !lesson.isCompleted else { return }

        let descriptor = FetchDescriptor<UserProgressModel>()
        if let progress = try? modelContext.fetch(descriptor).first {
            LessonService.shared.markLessonComplete(lesson, progress: progress)
            try? modelContext.save()
        }
        showCompletionAlert = true
        HapticManager.notification(type: .success)
    }

    private func timeString(from progress: Double) -> String {
        let totalSeconds = Int(progress * Double(lesson.duration * 60))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
