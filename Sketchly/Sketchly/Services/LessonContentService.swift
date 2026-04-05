//
//  LessonContentService.swift
//  Sketchly
//
//  Generates AI-powered step-by-step drawing lessons via Claude
//

import Foundation

// MARK: - Lesson Content Models

struct AILessonContent {
    let intro: String
    let materials: [String]
    let steps: [AILessonStep]
    let finalChallenge: String
}

struct AILessonStep: Identifiable {
    let id = UUID()
    let number: Int
    let title: String
    let instruction: String
    let tip: String?
    let durationMinutes: Int
}

// MARK: - Lesson Content Service

final class LessonContentService {
    static let shared = LessonContentService()

    private let apiKey = "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"
    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!

    // Cache so reopening a lesson doesn't re-call the API
    private var cache: [String: AILessonContent] = [:]

    private init() {}

    func generateLesson(title: String, category: String, difficulty: String, durationMinutes: Int) async throws -> AILessonContent {
        let cacheKey = "\(title)-\(difficulty)"
        if let cached = cache[cacheKey] { return cached }

        let stepCount = max(3, min(6, durationMinutes / 5))

        let prompt = """
        You are an expert drawing instructor creating a lesson for a mobile drawing app. The student will read your instructions and draw along on their device screen with their finger or stylus.

        Lesson: "\(title)"
        Category: \(category)
        Difficulty: \(difficulty)
        Total duration: \(durationMinutes) minutes
        Number of steps: \(stepCount)

        Respond ONLY with a valid JSON object in exactly this format, no other text:
        {
          "intro": "<2-3 sentences explaining what the student will learn and create>",
          "materials": ["<item1>", "<item2>"],
          "steps": [
            {
              "title": "<short step title>",
              "instruction": "<clear, specific 2-4 sentence instruction for what to draw. Be very concrete — describe exact shapes, proportions, placement on the page>",
              "tip": "<one short pro tip or common mistake to avoid, or null>",
              "durationMinutes": <integer>
            }
          ],
          "finalChallenge": "<1-2 sentences describing a small challenge to try after finishing the guided steps>"
        }

        Important: instructions must work for someone drawing on a phone/tablet screen. Don't reference physical pencils or paper — they are using a digital canvas with a stylus or finger. Steps should build on each other progressively.
        """

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 1500,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LessonContentError.apiError
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = (json["content"] as? [[String: Any]])?.first,
              let text = content["text"] as? String else {
            throw LessonContentError.parseError
        }

        let result = try parseLessonContent(from: text)
        cache[cacheKey] = result
        return result
    }

    private func parseLessonContent(from text: String) throws -> AILessonContent {
        let jsonString: String
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            jsonString = String(text[start...end])
        } else {
            jsonString = text
        }

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LessonContentError.parseError
        }

        let intro = json["intro"] as? String ?? "Let's learn to draw!"
        let materials = json["materials"] as? [String] ?? ["Digital canvas"]
        let finalChallenge = json["finalChallenge"] as? String ?? "Try drawing this again from memory!"

        var steps: [AILessonStep] = []
        if let stepsJson = json["steps"] as? [[String: Any]] {
            for (index, stepJson) in stepsJson.enumerated() {
                steps.append(AILessonStep(
                    number: index + 1,
                    title: stepJson["title"] as? String ?? "Step \(index + 1)",
                    instruction: stepJson["instruction"] as? String ?? "",
                    tip: stepJson["tip"] as? String,
                    durationMinutes: stepJson["durationMinutes"] as? Int ?? 3
                ))
            }
        }

        return AILessonContent(intro: intro, materials: materials, steps: steps, finalChallenge: finalChallenge)
    }
}

enum LessonContentError: LocalizedError {
    case apiError, parseError

    var errorDescription: String? {
        switch self {
        case .apiError: return "Could not reach the AI instructor. Please check your connection."
        case .parseError: return "Failed to load lesson content. Please try again."
        }
    }
}
