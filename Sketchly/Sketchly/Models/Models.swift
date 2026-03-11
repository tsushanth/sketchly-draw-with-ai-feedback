//
//  Models.swift
//  Sketchly
//
//  SwiftData models for local persistence
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - SwiftData Models

@Model
final class LessonModel: Identifiable {
    var id: UUID
    var title: String
    var category: String
    var difficulty: String
    var duration: Int // in minutes
    var thumbnailName: String
    var videoURL: String
    var isPremium: Bool
    var isCompleted: Bool
    var isFavorited: Bool
    var lessonDescription: String
    var orderIndex: Int
    var createdAt: Date

    var categoryEnum: LessonCategory {
        get { LessonCategory(rawValue: category) ?? .portraits }
        set { category = newValue.rawValue }
    }

    var difficultyEnum: DifficultyLevel {
        get { DifficultyLevel(rawValue: difficulty) ?? .beginner }
        set { difficulty = newValue.rawValue }
    }

    init(
        title: String,
        category: LessonCategory,
        difficulty: DifficultyLevel,
        duration: Int,
        thumbnailName: String = "",
        videoURL: String = "",
        isPremium: Bool = false,
        isCompleted: Bool = false,
        isFavorited: Bool = false,
        description: String = "",
        orderIndex: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.category = category.rawValue
        self.difficulty = difficulty.rawValue
        self.duration = duration
        self.thumbnailName = thumbnailName
        self.videoURL = videoURL
        self.isPremium = isPremium
        self.isCompleted = isCompleted
        self.isFavorited = isFavorited
        self.lessonDescription = description
        self.orderIndex = orderIndex
        self.createdAt = Date()
    }
}

@Model
final class DrawingSessionModel {
    var id: UUID
    var lessonId: UUID?
    var canvasData: Data
    var createdAt: Date
    var feedbackNotes: String
    var durationSeconds: Int

    init(lessonId: UUID? = nil, canvasData: Data = Data(), feedbackNotes: String = "", durationSeconds: Int = 0) {
        self.id = UUID()
        self.lessonId = lessonId
        self.canvasData = canvasData
        self.createdAt = Date()
        self.feedbackNotes = feedbackNotes
        self.durationSeconds = durationSeconds
    }
}

@Model
final class UserProgressModel {
    var id: UUID
    var completedLessonsCount: Int
    var currentStreak: Int
    var longestStreak: Int
    var totalDrawingTime: Int // in seconds
    var skillLevelRaw: String
    var selectedTrackRaw: String?
    var lastActiveDate: Date
    var joinedDate: Date

    var skillLevel: SkillLevel {
        get { SkillLevel(rawValue: skillLevelRaw) ?? .beginner }
        set { skillLevelRaw = newValue.rawValue }
    }

    var selectedTrack: CurriculumTrack? {
        get {
            guard let raw = selectedTrackRaw else { return nil }
            return CurriculumTrack(rawValue: raw)
        }
        set { selectedTrackRaw = newValue?.rawValue }
    }

    init() {
        self.id = UUID()
        self.completedLessonsCount = 0
        self.currentStreak = 0
        self.longestStreak = 0
        self.totalDrawingTime = 0
        self.skillLevelRaw = SkillLevel.beginner.rawValue
        self.selectedTrackRaw = nil
        self.lastActiveDate = Date()
        self.joinedDate = Date()
    }
}

@Model
final class GalleryPostModel {
    var id: UUID
    var imageData: Data
    var lessonId: UUID?
    var likesCount: Int
    var commentsCount: Int
    var createdAt: Date
    var isPremium: Bool
    var caption: String
    var authorName: String

    init(imageData: Data, lessonId: UUID? = nil, caption: String = "", authorName: String = "You") {
        self.id = UUID()
        self.imageData = imageData
        self.lessonId = lessonId
        self.likesCount = 0
        self.commentsCount = 0
        self.createdAt = Date()
        self.isPremium = true
        self.caption = caption
        self.authorName = authorName
    }
}

@Model
final class CurriculumTrackModel {
    var id: UUID
    var name: String
    var trackDescription: String
    var trackRaw: String
    var completionPercent: Double
    var certificateEarned: Bool
    var totalLessons: Int
    var completedLessons: Int
    var isUnlocked: Bool

    var track: CurriculumTrack {
        get { CurriculumTrack(rawValue: trackRaw) ?? .mangaMaster }
        set { trackRaw = newValue.rawValue }
    }

    init(track: CurriculumTrack, totalLessons: Int) {
        self.id = UUID()
        self.name = track.displayName
        self.trackDescription = track.description
        self.trackRaw = track.rawValue
        self.completionPercent = 0
        self.certificateEarned = false
        self.totalLessons = totalLessons
        self.completedLessons = 0
        self.isUnlocked = false
    }
}

// MARK: - Enums

enum LessonCategory: String, Codable, CaseIterable, Identifiable {
    case portraits = "Portraits"
    case manga = "Manga & Anime"
    case landscapes = "Landscapes"
    case stillLife = "Still Life"
    case figures = "Figures"
    case animals = "Animals"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .portraits: return "person.fill"
        case .manga: return "sparkles"
        case .landscapes: return "mountain.2.fill"
        case .stillLife: return "cup.and.saucer.fill"
        case .figures: return "figure.stand"
        case .animals: return "pawprint.fill"
        }
    }

    var color: Color {
        switch self {
        case .portraits: return .blue
        case .manga: return .purple
        case .landscapes: return .green
        case .stillLife: return .orange
        case .figures: return .pink
        case .animals: return .brown
        }
    }
}

enum DifficultyLevel: String, Codable, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }

    var icon: String {
        switch self {
        case .beginner: return "1.circle.fill"
        case .intermediate: return "2.circle.fill"
        case .advanced: return "3.circle.fill"
        }
    }
}

enum SkillLevel: String, Codable, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case hobbyist = "Hobbyist"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .beginner: return "I'm just starting out"
        case .hobbyist: return "I draw for fun sometimes"
        case .intermediate: return "I draw regularly"
        case .advanced: return "I have strong skills"
        }
    }

    var icon: String {
        switch self {
        case .beginner: return "leaf.fill"
        case .hobbyist: return "pencil"
        case .intermediate: return "pencil.and.outline"
        case .advanced: return "paintbrush.fill"
        }
    }
}

enum DrawingGoal: String, Codable, CaseIterable, Identifiable {
    case manga = "Draw Manga & Anime"
    case portraits = "Draw Portraits"
    case landscapes = "Draw Landscapes"
    case general = "General Drawing"
    case illustration = "Illustration"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .manga: return "sparkles"
        case .portraits: return "person.fill"
        case .landscapes: return "mountain.2.fill"
        case .general: return "pencil.and.ruler.fill"
        case .illustration: return "paintbrush.pointed.fill"
        }
    }

    var color: Color {
        switch self {
        case .manga: return .purple
        case .portraits: return .blue
        case .landscapes: return .green
        case .general: return .orange
        case .illustration: return .pink
        }
    }
}

enum CurriculumTrack: String, Codable, CaseIterable, Identifiable {
    case mangaMaster = "manga_master"
    case portraitPro = "portrait_pro"
    case landscapeArtist = "landscape_artist"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mangaMaster: return "Manga Master"
        case .portraitPro: return "Portrait Pro"
        case .landscapeArtist: return "Landscape Artist"
        }
    }

    var description: String {
        switch self {
        case .mangaMaster: return "Master the art of manga and anime drawing from basics to advanced techniques"
        case .portraitPro: return "Learn portrait drawing fundamentals through professional techniques"
        case .landscapeArtist: return "Capture the beauty of nature with landscape drawing skills"
        }
    }

    var icon: String {
        switch self {
        case .mangaMaster: return "sparkles"
        case .portraitPro: return "person.bust"
        case .landscapeArtist: return "mountain.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .mangaMaster: return .purple
        case .portraitPro: return .blue
        case .landscapeArtist: return .green
        }
    }

    var lessonCount: Int {
        switch self {
        case .mangaMaster: return 18
        case .portraitPro: return 16
        case .landscapeArtist: return 14
        }
    }
}

// MARK: - AI Feedback Models

struct AIDrawingFeedback {
    let proportions: FeedbackItem
    let shading: FeedbackItem
    let lineWeight: FeedbackItem
    let composition: FeedbackItem
    let overallScore: Int
    let encouragement: String
    let topTip: String

    struct FeedbackItem {
        let score: Int // 1-10
        let comment: String
        let suggestions: [String]
    }
}

// MARK: - Lesson Seed Data Helper

struct LessonSeedData {
    static let freeLessons: [(String, LessonCategory, DifficultyLevel, Int, String)] = [
        ("Introduction to Line Drawing", .stillLife, .beginner, 15, "Drawing basic shapes with confident lines"),
        ("Basic Shapes & Forms", .stillLife, .beginner, 20, "Understanding how to break down complex objects into simple shapes"),
        ("Shading Fundamentals", .portraits, .beginner, 25, "Learn the core shading techniques that every artist needs"),
        ("Eye Drawing Basics", .portraits, .beginner, 30, "Step-by-step guide to drawing realistic eyes"),
        ("Manga Character Faces", .manga, .beginner, 35, "Draw your first manga character from scratch"),
    ]

    static let premiumLessons: [(String, LessonCategory, DifficultyLevel, Int, String)] = [
        ("Portrait Proportions", .portraits, .intermediate, 40, "Master the golden ratio for perfect portrait proportions"),
        ("Hair Drawing Techniques", .portraits, .intermediate, 35, "Draw flowing, dynamic hair with depth and texture"),
        ("Nose and Mouth Mastery", .portraits, .intermediate, 30, "Detailed guide to drawing nose and mouth from all angles"),
        ("Full Face Portrait", .portraits, .advanced, 60, "Combine all portrait skills for a complete face drawing"),
        ("Manga Eyes & Expressions", .manga, .intermediate, 40, "Learn to draw expressive anime eyes"),
        ("Manga Body Proportions", .manga, .intermediate, 45, "Understanding manga body structure and proportions"),
        ("Action Poses", .figures, .intermediate, 50, "Draw dynamic figures in action"),
        ("Landscape Perspective", .landscapes, .intermediate, 40, "Master 1-point and 2-point perspective"),
        ("Trees & Foliage", .landscapes, .beginner, 25, "Drawing realistic trees and leaves"),
        ("Sky & Clouds", .landscapes, .beginner, 20, "Capture dramatic skies in your drawings"),
        ("Still Life Composition", .stillLife, .intermediate, 35, "Arrange and draw compelling still life scenes"),
        ("Texture Techniques", .stillLife, .advanced, 45, "Master different textures in pencil drawing"),
        ("Animal Anatomy Basics", .animals, .intermediate, 40, "Understanding animal structure for better drawings"),
        ("Cats & Dogs", .animals, .beginner, 30, "Draw cute and realistic cats and dogs"),
        ("Figure Drawing Fundamentals", .figures, .intermediate, 55, "Core figure drawing skills every artist needs"),
    ]
}
