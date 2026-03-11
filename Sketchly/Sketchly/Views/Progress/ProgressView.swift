//
//  ProgressView.swift
//  Sketchly
//

import SwiftUI
import SwiftData

struct UserProgressView: View {
    @Environment(PremiumManager.self) private var premiumManager
    @Query private var progressRecords: [UserProgressModel]
    @Query private var lessons: [LessonModel]
    @State private var viewModel = ProgressViewModel()
    @State private var showPaywall = false
    @State private var showTrackView = false

    private var userProgress: UserProgressModel? {
        progressRecords.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Stats overview
                    statsOverview

                    // Streak card
                    streakCard

                    // Curriculum Tracks (premium)
                    curriculumSection

                    // Completed Lessons
                    completedLessonsSection

                    Spacer(minLength: 100)
                }
                .padding(.top, 8)
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(premiumManager)
        }
        .sheet(isPresented: $showTrackView) {
            CurriculumTrackView()
                .environment(premiumManager)
        }
        .onAppear {
            AnalyticsService.shared.logScreenView(screenName: "Progress", screenClass: "ProgressView")
        }
    }

    // MARK: - Stats Overview
    private var statsOverview: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                value: "\(userProgress?.completedLessonsCount ?? 0)",
                label: "Lessons Done",
                icon: "checkmark.circle.fill",
                color: .green
            )

            StatCard(
                value: "\(userProgress?.currentStreak ?? 0)",
                label: "Day Streak",
                icon: "flame.fill",
                color: .orange
            )

            StatCard(
                value: "\(lessons.filter { $0.isCompleted }.count)",
                label: "Drawings Made",
                icon: "pencil.tip.crop.circle.fill",
                color: .blue
            )

            StatCard(
                value: "\(formatTime(userProgress?.totalDrawingTime ?? 0))",
                label: "Hours Practiced",
                icon: "clock.fill",
                color: .purple
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Streak Card
    private var streakCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Current Streak")
                    .font(.headline)
                Spacer()
                if let progress = userProgress {
                    Text("Best: \(progress.longestStreak) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 16) {
                // Badge
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [viewModel.badgeColor(for: userProgress?.currentStreak ?? 0).opacity(0.3),
                                         viewModel.badgeColor(for: userProgress?.currentStreak ?? 0).opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: viewModel.badgeIcon(for: userProgress?.currentStreak ?? 0))
                        .font(.title)
                        .foregroundColor(viewModel.badgeColor(for: userProgress?.currentStreak ?? 0))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.badgeTitle(for: userProgress?.currentStreak ?? 0))
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("\(userProgress?.currentStreak ?? 0) days in a row")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Draw daily to keep your streak!")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                Spacer()
            }

            // Week visualization
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { day in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(day < (userProgress?.currentStreak ?? 0) % 7 ? Color.orange : Color(.systemGray5))
                            .frame(width: 36, height: 36)
                            .overlay {
                                if day < (userProgress?.currentStreak ?? 0) % 7 {
                                    Image(systemName: "flame.fill")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            }
                        Text(dayAbbrev(day))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }

    // MARK: - Curriculum Section
    private var curriculumSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Curriculum Tracks", systemImage: "map.fill")
                    .font(.headline)
                Spacer()
                if !premiumManager.isPremium {
                    PremiumBadge()
                }
            }
            .padding(.horizontal)

            if premiumManager.isPremium {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(CurriculumTrack.allCases) { track in
                            TrackCard(track: track, completionPercent: 0) {
                                viewModel.selectedTrack = track
                                showTrackView = true
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                // Locked preview
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(CurriculumTrack.allCases) { track in
                            TrackCard(track: track, completionPercent: 0) {
                                showPaywall = true
                                AnalyticsService.shared.track(.paywallViewed(trigger: "curriculum_tracks"))
                            }
                            .overlay {
                                Color.black.opacity(0.4)
                                    .cornerRadius(16)
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.white)
                                    .font(.title)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Completed Lessons
    private var completedLessonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Completed Lessons",
                icon: "checkmark.circle.fill",
                count: lessons.filter { $0.isCompleted }.count
            )

            let completedLessons = lessons.filter { $0.isCompleted }

            if completedLessons.isEmpty {
                EmptyStateView(
                    icon: "book.closed",
                    title: "No Completed Lessons",
                    message: "Complete your first lesson to see it here"
                )
                .frame(height: 150)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(completedLessons) { lesson in
                        LessonCardView(
                            lesson: lesson,
                            isPremiumUser: premiumManager.isPremium,
                            style: .standard
                        )
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        if hours > 0 { return "\(hours)h" }
        let minutes = seconds / 60
        return "\(minutes)m"
    }

    private func dayAbbrev(_ day: Int) -> String {
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        return days[day]
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(16)
    }
}

// MARK: - Track Card
struct TrackCard: View {
    let track: CurriculumTrack
    let completionPercent: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: track.icon)
                    .font(.title)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [track.color, track.color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("\(track.lessonCount) lessons")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Progress bar
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: completionPercent)
                        .tint(track.color)

                    Text("\(Int(completionPercent * 100))% complete")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(width: 160)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
    }
}
