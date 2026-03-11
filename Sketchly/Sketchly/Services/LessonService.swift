//
//  LessonService.swift
//  Sketchly
//
//  Manages lesson data and seeding
//

import Foundation
import SwiftData

@MainActor
final class LessonService {
    static let shared = LessonService()

    private init() {}

    // MARK: - Seed Lessons

    func seedLessonsIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<LessonModel>()
        let count = (try? context.fetchCount(descriptor)) ?? 0

        guard count == 0 else { return }

        // Insert free lessons
        for (index, lessonData) in LessonSeedData.freeLessons.enumerated() {
            let lesson = LessonModel(
                title: lessonData.0,
                category: lessonData.1,
                difficulty: lessonData.2,
                duration: lessonData.3,
                thumbnailName: "lesson_thumb_\(index + 1)",
                isPremium: false,
                description: lessonData.4,
                orderIndex: index
            )
            context.insert(lesson)
        }

        // Insert premium lessons
        for (index, lessonData) in LessonSeedData.premiumLessons.enumerated() {
            let lesson = LessonModel(
                title: lessonData.0,
                category: lessonData.1,
                difficulty: lessonData.2,
                duration: lessonData.3,
                thumbnailName: "lesson_thumb_premium_\(index + 1)",
                isPremium: true,
                description: lessonData.4,
                orderIndex: index + LessonSeedData.freeLessons.count
            )
            context.insert(lesson)
        }

        try? context.save()
    }

    // MARK: - Seed User Progress

    func seedUserProgressIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<UserProgressModel>()
        let count = (try? context.fetchCount(descriptor)) ?? 0

        guard count == 0 else { return }

        let progress = UserProgressModel()
        context.insert(progress)
        try? context.save()
    }

    // MARK: - Update Streak

    func updateStreak(progress: UserProgressModel) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastActive = calendar.startOfDay(for: progress.lastActiveDate)

        let daysDiff = calendar.dateComponents([.day], from: lastActive, to: today).day ?? 0

        if daysDiff == 0 {
            // Already active today, no change
            return
        } else if daysDiff == 1 {
            // Consecutive day
            progress.currentStreak += 1
            if progress.currentStreak > progress.longestStreak {
                progress.longestStreak = progress.currentStreak
            }
        } else {
            // Streak broken
            progress.currentStreak = 1
        }

        progress.lastActiveDate = Date()
        AnalyticsService.shared.track(.streakUpdated(days: progress.currentStreak))
    }

    // MARK: - Mark Lesson Complete

    func markLessonComplete(_ lesson: LessonModel, progress: UserProgressModel) {
        guard !lesson.isCompleted else { return }

        lesson.isCompleted = true
        progress.completedLessonsCount += 1
        updateStreak(progress: progress)

        ReviewManager.shared.recordSuccessfulAction()
        AnalyticsService.shared.track(.lessonCompleted(
            lessonId: lesson.id.uuidString,
            duration: lesson.duration * 60
        ))
    }

    // MARK: - Featured Lessons

    func featuredLessons(from lessons: [LessonModel]) -> [LessonModel] {
        Array(lessons.filter { !$0.isPremium }.prefix(3))
    }

    func continueLesson(from lessons: [LessonModel]) -> LessonModel? {
        lessons.first { !$0.isCompleted }
    }
}
