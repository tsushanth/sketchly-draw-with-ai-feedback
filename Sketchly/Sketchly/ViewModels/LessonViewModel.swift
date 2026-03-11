//
//  LessonViewModel.swift
//  Sketchly
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class LessonViewModel {
    var selectedLesson: LessonModel?
    var isPlaying: Bool = false
    var progress: Double = 0.0
    var selectedCategory: LessonCategory?
    var selectedDifficulty: DifficultyLevel?

    private var playbackTimer: Timer?

    func startLesson(_ lesson: LessonModel) {
        selectedLesson = lesson
        isPlaying = true
        progress = 0
        AnalyticsService.shared.track(.lessonStarted(
            lessonId: lesson.id.uuidString,
            category: lesson.category
        ))
    }

    func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            startProgress()
        } else {
            stopProgress()
        }
    }

    private func startProgress() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.progress < 1.0 {
                    self.progress += 0.01
                } else {
                    self.stopProgress()
                }
            }
        }
    }

    private func stopProgress() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    func filteredLessons(from allLessons: [LessonModel]) -> [LessonModel] {
        var result = allLessons

        if let category = selectedCategory {
            result = result.filter { $0.categoryEnum == category }
        }

        if let difficulty = selectedDifficulty {
            result = result.filter { $0.difficultyEnum == difficulty }
        }

        return result.sorted { $0.orderIndex < $1.orderIndex }
    }

    func lessonsByCategory(_ lessons: [LessonModel]) -> [LessonCategory: [LessonModel]] {
        Dictionary(grouping: lessons) { $0.categoryEnum }
    }
}
