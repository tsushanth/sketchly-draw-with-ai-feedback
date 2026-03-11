//
//  DiscoverViewModel.swift
//  Sketchly
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class DiscoverViewModel {
    var selectedCategory: LessonCategory?
    var searchText: String = ""
    var isSearching: Bool = false

    var filteredLessons: [LessonModel] = []
    var featuredLessons: [LessonModel] = []
    var continueLessons: [LessonModel] = []

    func loadContent(from lessons: [LessonModel]) {
        featuredLessons = Array(lessons.filter { !$0.isPremium }.prefix(3))
        continueLessons = lessons.filter { !$0.isCompleted }.prefix(5).map { $0 }

        if let category = selectedCategory {
            filteredLessons = lessons.filter { $0.categoryEnum == category }
        } else if !searchText.isEmpty {
            filteredLessons = lessons.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.lessonDescription.localizedCaseInsensitiveContains(searchText)
            }
        } else {
            filteredLessons = lessons
        }
    }

    func selectCategory(_ category: LessonCategory?) {
        if selectedCategory == category {
            selectedCategory = nil
        } else {
            selectedCategory = category
        }
    }
}
