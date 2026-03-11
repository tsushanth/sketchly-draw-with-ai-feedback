//
//  OnboardingViewModel.swift
//  Sketchly
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class OnboardingViewModel {
    var currentStep: Int = 0
    var selectedGoal: DrawingGoal?
    var selectedSkillLevel: SkillLevel?
    var isCompleted: Bool = false

    let totalSteps = 3

    var canAdvance: Bool {
        switch currentStep {
        case 0: return true
        case 1: return selectedGoal != nil
        case 2: return selectedSkillLevel != nil
        default: return false
        }
    }

    var progress: Double {
        Double(currentStep + 1) / Double(totalSteps)
    }

    func advance() {
        if currentStep < totalSteps - 1 {
            currentStep += 1
            AnalyticsService.shared.track(.onboardingStepCompleted(step: currentStep))
        } else {
            complete()
        }
    }

    func back() {
        if currentStep > 0 {
            currentStep -= 1
        }
    }

    func skip() {
        AnalyticsService.shared.track(.onboardingSkipped(atStep: currentStep))
        complete()
    }

    private func complete() {
        UserDefaults.standard.set(true, forKey: "com.appfactory.sketchly.hasCompletedOnboarding")
        if let goal = selectedGoal {
            UserDefaults.standard.set(goal.rawValue, forKey: "com.appfactory.sketchly.selectedGoal")
        }
        if let level = selectedSkillLevel {
            UserDefaults.standard.set(level.rawValue, forKey: "com.appfactory.sketchly.skillLevel")
        }
        AnalyticsService.shared.track(.onboardingCompleted(goal: selectedGoal?.rawValue ?? "none"))
        isCompleted = true
    }
}
