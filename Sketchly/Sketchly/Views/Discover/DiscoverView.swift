//
//  DiscoverView.swift
//  Sketchly
//

import SwiftUI
import SwiftData

struct DiscoverView: View {
    @Environment(PremiumManager.self) private var premiumManager
    @Query private var lessons: [LessonModel]
    @State private var viewModel = DiscoverViewModel()
    @State private var showPaywall = false
    @State private var selectedLesson: LessonModel?
    @State private var showLessonDetail = false
    @State private var showCustomLesson = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Search bar
                    searchBar

                    // Custom Lesson CTA
                    customLessonBanner

                    // Categories
                    categoryScrollView

                    // Continue Learning
                    if !viewModel.continueLessons.isEmpty {
                        continueLearningSection
                    }

                    // Featured Lessons
                    featuredSection

                    // All Lessons or Filtered
                    allLessonsSection

                    Spacer(minLength: 100)
                }
                .padding(.top, 8)
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !premiumManager.isPremium {
                        Button(action: { showPaywall = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                Text("Pro")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                            )
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(premiumManager)
        }
        .sheet(item: $selectedLesson) { lesson in
            LessonDetailView(lesson: lesson)
                .environment(premiumManager)
        }
        .sheet(isPresented: $showCustomLesson) {
            CustomLessonInputView()
                .environment(premiumManager)
        }
        .onAppear {
            viewModel.loadContent(from: lessons)
            AnalyticsService.shared.logScreenView(screenName: "Discover", screenClass: "DiscoverView")
        }
        .onChange(of: lessons) { _, newLessons in
            viewModel.loadContent(from: newLessons)
        }
        .onChange(of: viewModel.selectedCategory) { _, _ in
            viewModel.loadContent(from: lessons)
        }
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.loadContent(from: lessons)
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search lessons...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Category Scroll
    private var categoryScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // All button
                CategoryChip(
                    title: "All",
                    icon: "square.grid.2x2",
                    color: .orange,
                    isSelected: viewModel.selectedCategory == nil
                ) {
                    viewModel.selectCategory(nil)
                    HapticManager.selection()
                }

                ForEach(LessonCategory.allCases) { category in
                    CategoryChip(
                        title: category.rawValue,
                        icon: category.icon,
                        color: category.color,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.selectCategory(category)
                        HapticManager.selection()
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Continue Learning
    private var continueLearningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Continue Learning", icon: "play.circle.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.continueLessons) { lesson in
                        LessonCardView(
                            lesson: lesson,
                            isPremiumUser: premiumManager.isPremium,
                            style: .compact
                        )
                        .onTapGesture {
                            handleLessonTap(lesson)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Featured Section
    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Featured Lessons", icon: "star.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.featuredLessons) { lesson in
                        LessonCardView(
                            lesson: lesson,
                            isPremiumUser: premiumManager.isPremium,
                            style: .featured
                        )
                        .frame(width: 280)
                        .onTapGesture {
                            handleLessonTap(lesson)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - All Lessons
    private var allLessonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: viewModel.selectedCategory?.rawValue ?? "All Lessons",
                icon: "books.vertical.fill",
                count: viewModel.filteredLessons.count
            )

            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredLessons) { lesson in
                    LessonCardView(
                        lesson: lesson,
                        isPremiumUser: premiumManager.isPremium,
                        style: .standard
                    )
                    .onTapGesture {
                        handleLessonTap(lesson)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Custom Lesson Banner
    private var customLessonBanner: some View {
        Button {
            showCustomLesson = true
            HapticManager.impact(style: .medium)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: "wand.and.stars")
                        .font(.title3)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Custom Lesson")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        if !premiumManager.isPremium {
                            PremiumBadge(style: .compact)
                        }
                    }
                    Text("Draw anything — AI creates a step-by-step lesson for you")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(colors: [.orange.opacity(0.3), .pink.opacity(0.3)], startPoint: .leading, endPoint: .trailing),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private func handleLessonTap(_ lesson: LessonModel) {
        if lesson.isPremium && !premiumManager.isPremium {
            showPaywall = true
            AnalyticsService.shared.track(.paywallViewed(trigger: "lesson_tap"))
        } else {
            selectedLesson = lesson
        }
        HapticManager.impact(style: .light)
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.2) : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? color : .secondary)
            .overlay(
                Capsule()
                    .stroke(isSelected ? color : Color.clear, lineWidth: 1.5)
            )
            .clipShape(Capsule())
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let icon: String
    var count: Int? = nil
    var action: (() -> Void)? = nil
    var actionLabel: String = "See All"

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.title3)
                .fontWeight(.bold)

            if let count = count {
                Text("(\(count))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let action = action {
                Button(actionLabel, action: action)
                    .font(.subheadline)
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                    )
            }
        }
        .padding(.horizontal)
    }
}
