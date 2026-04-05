//
//  DrawingLessonService.swift
//  Sketchly
//

import Foundation
import UIKit

// MARK: - Models

struct DrawingLessonPlan: Codable {
    let subject: String
    let steps: [DrawingStep]
}

struct DrawingStep: Identifiable, Codable {
    let id: UUID
    let number: Int
    let instruction: String   // spoken by TTS
    let newSVGPath: String    // ONLY the new strokes for this step
    let description: String   // e.g. "head circle"

    init(number: Int, instruction: String, newSVGPath: String, description: String) {
        self.id = UUID()
        self.number = number
        self.instruction = instruction
        self.newSVGPath = newSVGPath
        self.description = description
    }
}

struct StepEvaluation {
    let passed: Bool
    let feedback: String
}

// MARK: - Errors

enum DrawingLessonError: LocalizedError {
    case apiError
    case parseError
    case imageError

    var errorDescription: String? {
        switch self {
        case .apiError: return "Could not reach the AI. Please check your connection."
        case .parseError: return "Failed to parse the lesson plan. Please try again."
        case .imageError: return "Could not export your drawing. Please try again."
        }
    }
}

// MARK: - Service

final class DrawingLessonService {
    static let shared = DrawingLessonService()

    private let apiKey = "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"
    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!

    // In-memory cache by title
    private var cache: [String: DrawingLessonPlan] = [:]

    private static var cacheDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("lessonplans", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cacheFileURL(for title: String) -> URL {
        let slug = title
            .lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return DrawingLessonService.cacheDirectory.appendingPathComponent("\(slug).json")
    }

    private func loadFromDisk(title: String) -> DrawingLessonPlan? {
        let url = cacheFileURL(for: title)
        guard let data = try? Data(contentsOf: url),
              let plan = try? JSONDecoder().decode(DrawingLessonPlan.self, from: data) else { return nil }
        return plan
    }

    private func saveToDisk(_ plan: DrawingLessonPlan, title: String) {
        let url = cacheFileURL(for: title)
        guard let data = try? JSONEncoder().encode(plan) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private init() {}

    // MARK: - Generate Lesson Plan

    func generateLessonPlan(title: String, category: String, difficulty: String) async throws -> DrawingLessonPlan {
        if let cached = cache[title] { return cached }
        if let onDisk = loadFromDisk(title: title) {
            cache[title] = onDisk
            return onDisk
        }

        let prompt = """
        You are an expert drawing instructor. Generate a 5-step drawing lesson for "\(title)" (category: \(category), difficulty: \(difficulty)).

        Canvas size: 300x300 pixels. Each step provides ONLY the NEW strokes for that step (not cumulative).

        CRITICAL PATH RULES:
        - ONLY use M, L, C, Q, Z commands. NO arcs (A command).
        - For circles: use 4 cubic bezier curves with k=0.5523 (Bezier circle approximation).
          Example circle at center (150,150) radius 50:
          M 150,100 C 177.6,100 200,122.4 200,150 C 200,177.6 177.6,200 150,200 C 122.4,200 100,177.6 100,150 C 100,122.4 122.4,100 150,100 Z
        - Use realistic proportions that fit within the 300x300 canvas.
        - Each newSvgPath should be a complete, valid SVG path data string.

        Respond ONLY with valid JSON, no other text:
        {
          "subject": "\(title)",
          "steps": [
            {
              "instruction": "<2-3 sentence spoken instruction for what to draw in this step>",
              "newSvgPath": "<SVG path data using only M, L, C, Q, Z commands>",
              "description": "<short label like 'head circle' or 'left eye'>"
            }
          ]
        }

        Generate exactly 5 steps that build progressively to complete the \(title) drawing.
        """

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 2000,
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
            throw DrawingLessonError.apiError
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = (json["content"] as? [[String: Any]])?.first,
              let text = content["text"] as? String else {
            throw DrawingLessonError.apiError
        }

        let plan = try parseLessonPlan(from: text)
        cache[title] = plan
        saveToDisk(plan, title: title)
        return plan
    }

    private func parseLessonPlan(from text: String) throws -> DrawingLessonPlan {
        let jsonString: String
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            jsonString = String(text[start...end])
        } else {
            jsonString = text
        }

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DrawingLessonError.parseError
        }

        let subject = json["subject"] as? String ?? "Drawing"
        var steps: [DrawingStep] = []

        if let stepsJson = json["steps"] as? [[String: Any]] {
            for (index, stepJson) in stepsJson.enumerated() {
                let instruction = stepJson["instruction"] as? String ?? "Draw this step."
                let newSVGPath = stepJson["newSvgPath"] as? String ?? "M 0 0"
                let description = stepJson["description"] as? String ?? "Step \(index + 1)"
                steps.append(DrawingStep(
                    number: index + 1,
                    instruction: instruction,
                    newSVGPath: newSVGPath,
                    description: description
                ))
            }
        }

        guard !steps.isEmpty else { throw DrawingLessonError.parseError }
        return DrawingLessonPlan(subject: subject, steps: steps)
    }

    // MARK: - Evaluate Step

    func evaluateStep(userImage: UIImage, step: DrawingStep, subject: String) async throws -> StepEvaluation {
        guard let imageData = userImage.jpegData(compressionQuality: 0.7) else {
            throw DrawingLessonError.imageError
        }
        let base64Image = imageData.base64EncodedString()

        let prompt = """
        You are a friendly drawing instructor evaluating a student's drawing attempt.
        The student was asked to draw: "\(step.description)" as part of a "\(subject)" drawing lesson.
        Their instruction was: "\(step.instruction)"

        Look at their drawing and evaluate whether they made a reasonable attempt at drawing the described element.
        Be lenient and encouraging — if they drew something that resembles the requested element, count it as passed.

        Respond ONLY with valid JSON:
        {"passed": true or false, "feedback": "<1-2 sentences of encouraging feedback>"}
        """

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 200,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": prompt
                        ]
                    ]
                ]
            ]
        ]

        do {
            var request = URLRequest(url: apiURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return StepEvaluation(passed: true, feedback: "Good work! Moving on.")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = (json["content"] as? [[String: Any]])?.first,
                  let text = content["text"] as? String else {
                return StepEvaluation(passed: true, feedback: "Good work! Moving on.")
            }

            return parseEvaluation(from: text)
        } catch {
            return StepEvaluation(passed: true, feedback: "Good work! Moving on.")
        }
    }

    private func parseEvaluation(from text: String) -> StepEvaluation {
        let jsonString: String
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            jsonString = String(text[start...end])
        } else {
            return StepEvaluation(passed: true, feedback: "Good work! Moving on.")
        }

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return StepEvaluation(passed: true, feedback: "Good work! Moving on.")
        }

        let passed = json["passed"] as? Bool ?? true
        let feedback = json["feedback"] as? String ?? "Good work! Moving on."
        return StepEvaluation(passed: passed, feedback: feedback)
    }
}
