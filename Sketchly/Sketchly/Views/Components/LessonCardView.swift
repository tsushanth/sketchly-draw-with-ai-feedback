//
//  LessonCardView.swift
//  Sketchly
//

import SwiftUI

struct LessonCardView: View {
    let lesson: LessonModel
    let isPremiumUser: Bool
    var style: CardStyle = .standard

    enum CardStyle {
        case standard
        case compact
        case featured
    }

    private var isLocked: Bool {
        lesson.isPremium && !isPremiumUser
    }

    var body: some View {
        switch style {
        case .featured:
            featuredCard
        case .compact:
            compactCard
        case .standard:
            standardCard
        }
    }

    // MARK: - Featured Card
    private var featuredCard: some View {
        ZStack(alignment: .bottomLeading) {
            // Thumbnail gradient background
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [lesson.categoryEnum.color.opacity(0.8), lesson.categoryEnum.color.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 180)
                .overlay {
                    VStack {
                        Image(systemName: lesson.categoryEnum.icon)
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }

            VStack(alignment: .leading, spacing: 8) {
                if lesson.isCompleted {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                }

                Text(lesson.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label("\(lesson.duration) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))

                    Text(lesson.difficultyEnum.rawValue)
                        .font(.caption)
                        .foregroundColor(lesson.difficultyEnum.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(4)

                    if isLocked {
                        Spacer()
                        PremiumBadge()
                    }
                }
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Standard Card
    private var standardCard: some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [lesson.categoryEnum.color.opacity(0.7), lesson.categoryEnum.color.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: lesson.categoryEnum.icon)
                    .font(.title2)
                    .foregroundColor(.white)

                if isLocked {
                    Color.black.opacity(0.4)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Image(systemName: "lock.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }

                if lesson.isCompleted {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .background(Color.white.clipShape(Circle()))
                                .padding(4)
                        }
                        Spacer()
                    }
                    .frame(width: 80, height: 80)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(lesson.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)

                    Spacer()

                    if isLocked {
                        PremiumBadge(style: .compact)
                    }
                }

                Text(lesson.lessonDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label("\(lesson.duration) min", systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Circle()
                        .fill(lesson.difficultyEnum.color)
                        .frame(width: 6, height: 6)

                    Text(lesson.difficultyEnum.rawValue)
                        .font(.caption2)
                        .foregroundColor(lesson.difficultyEnum.color)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Compact Card
    private var compactCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [lesson.categoryEnum.color.opacity(0.7), lesson.categoryEnum.color.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 90)
                    .frame(maxWidth: .infinity)

                Image(systemName: lesson.categoryEnum.icon)
                    .font(.title)
                    .foregroundColor(.white.opacity(0.6))

                if isLocked {
                    Color.black.opacity(0.4)
                        .cornerRadius(10)
                    Image(systemName: "lock.fill")
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                Text("\(lesson.duration) min")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .frame(width: 130)
    }
}
