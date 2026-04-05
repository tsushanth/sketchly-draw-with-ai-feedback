//
//  CurriculumTrackView.swift
//  Sketchly
//

import SwiftUI
import SwiftData

struct CurriculumTrackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PremiumManager.self) private var premiumManager
    @Query private var lessons: [LessonModel]
    @State private var selectedTrack: CurriculumTrack = .mangaMaster
    @State private var showCertificate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Track selector
                    trackSelectorPicker

                    // Track header
                    trackHeader

                    // Lessons for track
                    trackLessons

                    // Certificate section
                    certificateSection

                    Spacer(minLength: 80)
                }
            }
            .navigationTitle("Curriculum Tracks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showCertificate) {
            CertificateView(track: selectedTrack)
        }
    }

    // MARK: - Track Selector
    private var trackSelectorPicker: some View {
        Picker("Track", selection: $selectedTrack) {
            ForEach(CurriculumTrack.allCases) { track in
                Text(track.displayName).tag(track)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: - Track Header
    private var trackHeader: some View {
        ZStack {
            LinearGradient(
                colors: [selectedTrack.color.opacity(0.8), selectedTrack.color.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 160)
            .cornerRadius(20)
            .padding(.horizontal)

            VStack(spacing: 12) {
                Image(systemName: selectedTrack.icon)
                    .font(.system(size: 44))
                    .foregroundColor(.white)

                Text(selectedTrack.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("\(selectedTrack.lessonCount) lessons • Certificate on completion")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Track Lessons
    private var trackLessons: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lessons")
                .font(.headline)
                .padding(.horizontal)

            let trackLessons = lessons.filter { lesson in
                lessonBelongsToTrack(lesson, track: selectedTrack)
            }

            if trackLessons.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("More lessons coming soon")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("We're building out this track. Check back for new lessons.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(trackLessons.enumerated()), id: \.element.id) { index, lesson in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(lesson.isCompleted ? Color.green : Color(.systemGray5))
                                    .frame(width: 36, height: 36)
                                if lesson.isCompleted {
                                    Image(systemName: "checkmark")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                } else {
                                    Text("\(index + 1)")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.secondary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(lesson.title)
                                    .font(.subheadline)
                                Text("\(lesson.duration) min")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: - Certificate Section
    private var certificateSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "rosette")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Certificate of Completion")
                        .font(.headline)
                    Text("Complete all lessons to earn your \(selectedTrack.displayName) certificate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)
            .padding(.horizontal)

            Button(action: { showCertificate = true }) {
                Text("Preview Certificate")
                    .font(.subheadline)
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                    )
            }
        }
    }

    private func lessonBelongsToTrack(_ lesson: LessonModel, track: CurriculumTrack) -> Bool {
        switch track {
        case .mangaMaster: return lesson.categoryEnum == .manga
        case .portraitPro: return lesson.categoryEnum == .portraits
        case .landscapeArtist: return lesson.categoryEnum == .landscapes
        }
    }


}

// MARK: - Certificate View
struct CertificateView: View {
    @Environment(\.dismiss) private var dismiss
    let track: CurriculumTrack

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Certificate
                    ZStack {
                        LinearGradient(
                            colors: [track.color.opacity(0.1), track.color.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        VStack(spacing: 24) {
                            // Border decoration
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    LinearGradient(
                                        colors: [.orange, track.color],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                                .padding(16)
                                .overlay {
                                    VStack(spacing: 20) {
                                        Image(systemName: "rosette")
                                            .font(.system(size: 60))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [.orange, .yellow],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )

                                        Text("Certificate of Achievement")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.secondary)

                                        Text("Sketchly")
                                            .font(.largeTitle)
                                            .fontWeight(.black)
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [.orange, .pink],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )

                                        Text("This certifies that")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)

                                        Text("Artist Name")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                            .underline()

                                        Text("has successfully completed")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)

                                        Text(track.displayName)
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(track.color)

                                        Text("with \(track.lessonCount) lessons completed")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        Text(Date().formatted(date: .long, time: .omitted))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(32)
                                }
                        }
                        .padding()
                    }

                    Text("Complete all lessons in this track to earn your certificate!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .navigationTitle("Certificate Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
