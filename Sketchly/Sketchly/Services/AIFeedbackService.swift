//
//  AIFeedbackService.swift
//  Sketchly
//
//  Mock AI feedback service - returns structured drawing critique
//

import Foundation
import UIKit

// MARK: - AI Feedback Service

@MainActor
final class AIFeedbackService {
    static let shared = AIFeedbackService()

    private init() {}

    // MARK: - Analyze Drawing

    func analyzeDrawing(image: UIImage) async throws -> AIDrawingFeedback {
        // Simulate network delay for AI processing
        try await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 seconds

        // Return mock feedback based on drawing analysis
        return generateMockFeedback()
    }

    // MARK: - Mock Feedback Generator

    private func generateMockFeedback() -> AIDrawingFeedback {
        let feedbackSets: [AIDrawingFeedback] = [
            AIDrawingFeedback(
                proportions: .init(
                    score: 7,
                    comment: "Good overall proportions with minor inconsistencies in the upper section.",
                    suggestions: [
                        "Use light guidelines before committing to final lines",
                        "Check symmetry by flipping your reference photo",
                        "Measure key distances relative to each other"
                    ]
                ),
                shading: .init(
                    score: 6,
                    comment: "Shading shows understanding of light source, but transitions could be smoother.",
                    suggestions: [
                        "Try blending with a tortillon or soft tissue",
                        "Build up tone in multiple light layers",
                        "Identify your light source before shading"
                    ]
                ),
                lineWeight: .init(
                    score: 8,
                    comment: "Confident line work with good variation between thick and thin lines.",
                    suggestions: [
                        "Use heavier lines for foreground elements",
                        "Taper lines at endpoints for a polished look"
                    ]
                ),
                composition: .init(
                    score: 7,
                    comment: "Subject is well-centered. Consider using the rule of thirds next time.",
                    suggestions: [
                        "Try placing the subject off-center for more dynamic composition",
                        "Leave negative space intentionally"
                    ]
                ),
                overallScore: 72,
                encouragement: "Great effort! Your line confidence is improving. Focus on smooth shading transitions to take your work to the next level.",
                topTip: "Practice the 'five elements of shading' — flat light, shadow edge, core shadow, reflected light, and cast shadow."
            ),
            AIDrawingFeedback(
                proportions: .init(
                    score: 8,
                    comment: "Proportions are well-balanced. The head-to-body ratio looks natural.",
                    suggestions: [
                        "Practice measuring with your pencil held at arm's length",
                        "Compare widths and heights as ratios"
                    ]
                ),
                shading: .init(
                    score: 9,
                    comment: "Excellent tonal range from light highlights to deep shadows.",
                    suggestions: [
                        "Try adding subtle reflected light on shadow edges for more dimension",
                        "Experiment with different pencil grades (H, HB, 2B, 4B)"
                    ]
                ),
                lineWeight: .init(
                    score: 7,
                    comment: "Mostly consistent line weight. Some areas could benefit from more pressure variation.",
                    suggestions: [
                        "Vary pressure for emphasis on important contours",
                        "Use lighter lines for background elements"
                    ]
                ),
                composition: .init(
                    score: 8,
                    comment: "Strong composition that draws the eye naturally through the image.",
                    suggestions: [
                        "Consider adding a simple background to anchor the subject"
                    ]
                ),
                overallScore: 80,
                encouragement: "Impressive work! Your shading skills are a real strength. Keep pushing your proportional accuracy.",
                topTip: "When drawing from life, spend 60% of your time observing and only 40% drawing."
            ),
            AIDrawingFeedback(
                proportions: .init(
                    score: 5,
                    comment: "Some proportion challenges visible — the eyes appear slightly large relative to the head.",
                    suggestions: [
                        "In realistic portraits, eyes are roughly halfway down the head",
                        "Draw a center line to check symmetry",
                        "Use the Loomis method for head proportions"
                    ]
                ),
                shading: .init(
                    score: 5,
                    comment: "Basic shading present but lacks depth. The shadow areas need more darkness.",
                    suggestions: [
                        "Push your darkest darks — don't be afraid of 4B or 6B pencil",
                        "Look for the core shadow (darkest part of shadow side)",
                        "Avoid harsh lines between light and shadow — blend gradually"
                    ]
                ),
                lineWeight: .init(
                    score: 6,
                    comment: "Line weight is fairly uniform. Adding variation will bring drawings to life.",
                    suggestions: [
                        "Press harder for outlines and contour lines",
                        "Use lighter touch for texture and detail lines",
                        "Study how professional artists use line hierarchy"
                    ]
                ),
                composition: .init(
                    score: 6,
                    comment: "Decent placement but the subject could be cropped more dynamically.",
                    suggestions: [
                        "Try a closer crop to focus on the most interesting features",
                        "Thumbnail multiple compositions before starting"
                    ]
                ),
                overallScore: 55,
                encouragement: "You're building good foundations! Every master was once a beginner. Keep practicing daily and you'll see rapid improvement.",
                topTip: "Do at least 5 minutes of gesture drawing daily at sketchdaily.com to build confidence and fluidity."
            )
        ]

        return feedbackSets.randomElement() ?? feedbackSets[0]
    }

    // MARK: - Score Color

    static func scoreColor(for score: Int) -> String {
        switch score {
        case 8...10: return "green"
        case 6..<8: return "orange"
        default: return "red"
        }
    }
}
