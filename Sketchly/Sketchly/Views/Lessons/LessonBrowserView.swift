//
//  LessonBrowserView.swift
//  Sketchly
//

import SwiftUI
import SwiftData

struct LessonBrowserView: View {
    @Environment(PremiumManager.self) private var premiumManager
    @Query(sort: \LessonModel.orderIndex) private var lessons: [LessonModel]
    @State private var viewModel = LessonViewModel()
    @State private var showPaywall = false
    @State private var selectedLesson: LessonModel?
    @State private var displayMode: DisplayMode = .list

    enum DisplayMode {
        case list, grid
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filters
                filterBar

                // Content
                if viewModel.filteredLessons(from: lessons).isEmpty {
                    EmptyStateView(
                        icon: "books.vertical",
                        title: "No Lessons Found",
                        message: "Try adjusting your filters"
                    )
                } else {
                    if displayMode == .list {
                        listView
                    } else {
                        gridView
                    }
                }
            }
            .navigationTitle("Lessons")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { displayMode = displayMode == .list ? .grid : .list }) {
                            Image(systemName: displayMode == .list ? "square.grid.2x2" : "list.bullet")
                        }
                        .foregroundColor(.primary)
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
        .onAppear {
            AnalyticsService.shared.logScreenView(screenName: "Lessons", screenClass: "LessonBrowserView")
        }
    }

    // MARK: - Filter Bar
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Category filter
                Menu {
                    Button("All Categories") { viewModel.selectedCategory = nil }
                    Divider()
                    ForEach(LessonCategory.allCases) { cat in
                        Button(cat.rawValue) { viewModel.selectedCategory = cat }
                    }
                } label: {
                    FilterChip(
                        title: viewModel.selectedCategory?.rawValue ?? "Category",
                        isActive: viewModel.selectedCategory != nil
                    )
                }

                // Difficulty filter
                Menu {
                    Button("All Levels") { viewModel.selectedDifficulty = nil }
                    Divider()
                    ForEach(DifficultyLevel.allCases) { diff in
                        Button(diff.rawValue) { viewModel.selectedDifficulty = diff }
                    }
                } label: {
                    FilterChip(
                        title: viewModel.selectedDifficulty?.rawValue ?? "Difficulty",
                        isActive: viewModel.selectedDifficulty != nil
                    )
                }

                // Premium filter
                if !premiumManager.isPremium {
                    Button(action: { showPaywall = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                            Text("Unlock All")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [.orange.opacity(0.2), .pink.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(
                            LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    // MARK: - List View
    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredLessons(from: lessons)) { lesson in
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
                Spacer(minLength: 100)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Grid View
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(viewModel.filteredLessons(from: lessons)) { lesson in
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
            .padding()
            Spacer(minLength: 100)
        }
    }

    private func handleLessonTap(_ lesson: LessonModel) {
        if lesson.isPremium && !premiumManager.isPremium {
            showPaywall = true
            AnalyticsService.shared.track(.paywallViewed(trigger: "lesson_browser"))
        } else {
            selectedLesson = lesson
        }
        HapticManager.impact(style: .light)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.subheadline)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isActive ? Color.orange.opacity(0.2) : Color(.secondarySystemBackground))
        .foregroundColor(isActive ? .orange : .secondary)
        .overlay(
            Capsule().stroke(isActive ? Color.orange : Color.clear, lineWidth: 1.5)
        )
        .clipShape(Capsule())
    }
}
