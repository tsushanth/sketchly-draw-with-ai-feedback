//
//  LessonCategoryView.swift
//  Sketchly
//

import SwiftUI

struct LessonCategoryView: View {
    @Environment(PremiumManager.self) private var premiumManager
    let category: LessonCategory
    let lessons: [LessonModel]
    @State private var selectedLesson: LessonModel?
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Category Header
                categoryHeader

                // Lessons
                ForEach(lessons.sorted { $0.orderIndex < $1.orderIndex }) { lesson in
                    LessonCardView(
                        lesson: lesson,
                        isPremiumUser: premiumManager.isPremium,
                        style: .standard
                    )
                    .onTapGesture {
                        if lesson.isPremium && !premiumManager.isPremium {
                            showPaywall = true
                        } else {
                            selectedLesson = lesson
                        }
                        HapticManager.impact(style: .light)
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 80)
            }
        }
        .navigationTitle(category.rawValue)
        .sheet(item: $selectedLesson) { lesson in
            LessonDetailView(lesson: lesson)
                .environment(premiumManager)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(premiumManager)
        }
    }

    private var categoryHeader: some View {
        ZStack {
            LinearGradient(
                colors: [category.color.opacity(0.8), category.color.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 56))
                    .foregroundColor(.white)

                Text(category.rawValue)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("\(lessons.count) lessons")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.vertical, 40)
        }
    }
}
