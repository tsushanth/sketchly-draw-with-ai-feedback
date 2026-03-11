//
//  GalleryPostView.swift
//  Sketchly
//

import SwiftUI

struct GalleryPostView: View {
    let post: MockGalleryPost
    let onLike: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author header
            authorHeader

            // Drawing preview (gradient placeholder)
            drawingPreview

            // Caption
            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 4)
            }

            // Lesson tag
            if let lessonTitle = post.lessonTitle {
                Label(lessonTitle, systemImage: "book.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 4)
            }

            // Actions
            actionBar
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Author Header
    private var authorHeader: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [post.authorColor.opacity(0.8), post.authorColor.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Text(post.authorInitials)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(post.authorName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(post.timeAgo)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Drawing Preview
    private var drawingPreview: some View {
        ZStack {
            LinearGradient(
                colors: post.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .cornerRadius(12)

            // Decorative sketch-like elements
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "paintbrush.pointed")
                        .font(.largeTitle)
                        .foregroundColor(.white.opacity(0.3))
                        .rotationEffect(.degrees(45))
                        .padding()
                }
                Spacer()
            }

            Image(systemName: "pencil.and.outline")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.15))
        }
    }

    // MARK: - Action Bar
    private var actionBar: some View {
        HStack(spacing: 20) {
            // Like
            Button(action: onLike) {
                HStack(spacing: 6) {
                    Image(systemName: post.isLiked ? "heart.fill" : "heart")
                        .foregroundColor(post.isLiked ? .red : .secondary)
                    Text("\(post.likesCount)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Comment
            HStack(spacing: 6) {
                Image(systemName: "bubble.right")
                    .foregroundColor(.secondary)
                Text("\(post.commentsCount)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Share
            Button(action: {}) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }
}
