//
//  ProgressViewModel.swift
//  Sketchly
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class ProgressViewModel {
    var selectedTrack: CurriculumTrack?
    var showTrackDetail: Bool = false
    var showCertificate: Bool = false
    var earnedCertificateTrack: CurriculumTrack?

    func selectTrack(_ track: CurriculumTrack, premiumManager: PremiumManager) {
        guard premiumManager.isPremium else { return }
        selectedTrack = track
        showTrackDetail = true
        AnalyticsService.shared.track(.trackEnrolled(track: track.rawValue))
    }

    func completionPercent(for track: CurriculumTrack, completedLessons: Int) -> Double {
        let total = track.lessonCount
        let completed = min(completedLessons, total)
        return Double(completed) / Double(total)
    }

    func badgeTitle(for streak: Int) -> String {
        switch streak {
        case 0: return "Start Drawing"
        case 1..<7: return "Early Bird"
        case 7..<14: return "Week Warrior"
        case 14..<30: return "Dedicated Artist"
        case 30..<60: return "Month Master"
        default: return "Drawing Legend"
        }
    }

    func badgeIcon(for streak: Int) -> String {
        switch streak {
        case 0: return "pencil.circle"
        case 1..<7: return "flame"
        case 7..<14: return "star.fill"
        case 14..<30: return "crown"
        case 30..<60: return "trophy.fill"
        default: return "medal.fill"
        }
    }

    func badgeColor(for streak: Int) -> Color {
        switch streak {
        case 0: return .gray
        case 1..<7: return .orange
        case 7..<14: return .yellow
        case 14..<30: return .green
        case 30..<60: return .blue
        default: return .purple
        }
    }
}
