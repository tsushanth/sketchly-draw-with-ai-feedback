//
//  GalleryViewModel.swift
//  Sketchly
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class GalleryViewModel {
    var posts: [GalleryPostModel] = []
    var isLoading: Bool = false
    var showPostSheet: Bool = false
    var selectedPost: GalleryPostModel?

    // Mock community posts for display
    var communityPosts: [MockGalleryPost] = MockGalleryPost.samplePosts

    func loadPosts(userPosts: [GalleryPostModel]) {
        posts = userPosts
    }

    func likePost(_ post: MockGalleryPost) {
        if let index = communityPosts.firstIndex(where: { $0.id == post.id }) {
            communityPosts[index].isLiked.toggle()
            communityPosts[index].likesCount += communityPosts[index].isLiked ? 1 : -1
        }
        HapticManager.impact(style: .light)
    }

    func sharePost(image: UIImage, caption: String, context: Any?) {
        AnalyticsService.shared.track(.galleryPostShared)
        HapticManager.notification(type: .success)
    }
}

// MARK: - Mock Gallery Post (for community feed display)
struct MockGalleryPost: Identifiable {
    let id: UUID
    let authorName: String
    let authorInitials: String
    let authorColor: Color
    let caption: String
    var likesCount: Int
    let commentsCount: Int
    let lessonTitle: String?
    let timeAgo: String
    var isLiked: Bool = false
    let gradientColors: [Color]

    static let samplePosts: [MockGalleryPost] = [
        MockGalleryPost(
            id: UUID(),
            authorName: "Sarah K.",
            authorInitials: "SK",
            authorColor: .purple,
            caption: "Finally nailed the eye drawing lesson! So happy with how this turned out 🎨",
            likesCount: 47,
            commentsCount: 8,
            lessonTitle: "Eye Drawing Basics",
            timeAgo: "2h ago",
            gradientColors: [.purple.opacity(0.6), .pink.opacity(0.6)]
        ),
        MockGalleryPost(
            id: UUID(),
            authorName: "Marco R.",
            authorInitials: "MR",
            authorColor: .blue,
            caption: "Manga face study - working on proportions. Feedback welcome!",
            likesCount: 32,
            commentsCount: 12,
            lessonTitle: "Manga Character Faces",
            timeAgo: "4h ago",
            gradientColors: [.blue.opacity(0.6), .cyan.opacity(0.6)]
        ),
        MockGalleryPost(
            id: UUID(),
            authorName: "Aisha T.",
            authorInitials: "AT",
            authorColor: .orange,
            caption: "Still life practice after the composition lesson. Coffee mug is my muse ☕",
            likesCount: 28,
            commentsCount: 5,
            lessonTitle: "Still Life Composition",
            timeAgo: "6h ago",
            gradientColors: [.orange.opacity(0.6), .yellow.opacity(0.6)]
        ),
        MockGalleryPost(
            id: UUID(),
            authorName: "James L.",
            authorInitials: "JL",
            authorColor: .green,
            caption: "Day 30 of daily drawing challenge. The improvement is real!",
            likesCount: 89,
            commentsCount: 21,
            lessonTitle: nil,
            timeAgo: "1d ago",
            gradientColors: [.green.opacity(0.6), .teal.opacity(0.6)]
        ),
        MockGalleryPost(
            id: UUID(),
            authorName: "Priya M.",
            authorInitials: "PM",
            authorColor: .pink,
            caption: "Portrait sketch with new shading techniques. AI feedback really helped! ✨",
            likesCount: 63,
            commentsCount: 14,
            lessonTitle: "Shading Fundamentals",
            timeAgo: "1d ago",
            gradientColors: [.pink.opacity(0.6), .red.opacity(0.4)]
        ),
    ]
}
