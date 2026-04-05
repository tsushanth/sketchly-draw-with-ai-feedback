//
//  CustomLessonService.swift
//  Sketchly
//
//  Talks to the Sketchly Agent on the server for custom drawing lessons.
//  User types a subject (e.g. "wolf") → server finds an outline, decomposes
//  it into steps, and returns a lesson. One call, no image picking.
//  Session is ephemeral — progress resets when user leaves the lesson.
//

import Foundation
import UIKit

// MARK: - Models

struct CustomLessonStep: Codable, Identifiable {
    var id: Int { number }
    let number: Int
    let instruction: String
    let newSvgPath: String
    let description: String
    let symmetryHint: String?

    // Populated after evaluation (from session state endpoint)
    var status: String?   // "pending", "passed", "attempted"
    var score: Int?
    var attempts: Int?

    // Handle both newSvgPath and newSVGPath from server
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        number = (try? container.decode(Int.self, forKey: DynamicCodingKey(stringValue: "number")!)) ?? 1
        instruction = (try? container.decode(String.self, forKey: DynamicCodingKey(stringValue: "instruction")!)) ?? "Draw this step."
        description = (try? container.decode(String.self, forKey: DynamicCodingKey(stringValue: "description")!)) ?? "Step"
        symmetryHint = try? container.decode(String.self, forKey: DynamicCodingKey(stringValue: "symmetryHint")!)
        status = try? container.decode(String.self, forKey: DynamicCodingKey(stringValue: "status")!)
        score = try? container.decode(Int.self, forKey: DynamicCodingKey(stringValue: "score")!)
        attempts = try? container.decode(Int.self, forKey: DynamicCodingKey(stringValue: "attempts")!)

        if let path = try? container.decode(String.self, forKey: DynamicCodingKey(stringValue: "newSvgPath")!) {
            newSvgPath = path
        } else if let path = try? container.decode(String.self, forKey: DynamicCodingKey(stringValue: "newSVGPath")!) {
            newSvgPath = path
        } else {
            newSvgPath = "M 0 0"
        }
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
    init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
}

struct CustomLessonResponse: Codable {
    let sessionId: String
    let subject: String
    let totalSteps: Int
    let estimatedMinutes: Int
    let currentStep: Int
    let step: CustomLessonStep
    let hasReferenceImage: Bool?
    let note: String?
}

struct WeakStep: Codable {
    let stepIndex: Int
    let description: String
    let score: Int?
    let suggestion: String?
}

struct EvaluationResponse: Codable {
    let passed: Bool
    let feedback: String
    let score: Int?
    let nextAction: String  // "next", "retry", "complete"
    let nextStep: CustomLessonStep?
    let weakSteps: [WeakStep]?
    let summary: LessonSummary?
}

struct LessonSummary: Codable {
    let totalSteps: Int
    let stepsCompleted: Int
    let averageScore: Int
    let totalAttempts: Int
    let weakSteps: [WeakStep]?
}

struct RevisitResponse: Codable {
    let step: CustomLessonStep
    let previousScore: Int?
    let previousFeedback: String?
    let tip: String
}

struct SessionStateResponse: Codable {
    let sessionId: String
    let subject: String
    let difficulty: String
    let totalSteps: Int
    let currentStep: Int
    let steps: [CustomLessonStep]
}

// MARK: - Service

final class CustomLessonService {
    static let shared = CustomLessonService()

    private let baseURL = "http://178.156.192.31:3458"

    private let workerSecret = "sketchly-agent-secret-2026"

    private init() {}

    // MARK: - Create a custom lesson (single call)

    /// User provides a subject like "wolf" or "face".
    /// mode: "web" = find real outline image from web, "ai" = AI generates SVG from scratch
    func createLesson(subject: String, difficulty: String = "beginner", mode: String = "web") async throws -> CustomLessonResponse {
        let body: [String: Any] = [
            "subject": subject,
            "difficulty": difficulty,
            "mode": mode
        ]
        let data = try await request(method: "POST", path: "/custom/lesson", body: body)
        return try JSONDecoder().decode(CustomLessonResponse.self, from: data)
    }

    // MARK: - Evaluate a step

    func evaluateStep(sessionId: String, stepIndex: Int, image: UIImage) async throws -> EvaluationResponse {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw CustomLessonError.imageExportFailed
        }

        let body: [String: Any] = [
            "sessionId": sessionId,
            "stepIndex": stepIndex,
            "imageBase64": imageData.base64EncodedString()
        ]
        let data = try await request(method: "POST", path: "/custom/evaluate", body: body)
        return try JSONDecoder().decode(EvaluationResponse.self, from: data)
    }

    // MARK: - Revisit a step

    func revisitStep(sessionId: String, stepIndex: Int) async throws -> RevisitResponse {
        let body: [String: Any] = [
            "sessionId": sessionId,
            "stepIndex": stepIndex
        ]
        let data = try await request(method: "POST", path: "/custom/revisit", body: body)
        return try JSONDecoder().decode(RevisitResponse.self, from: data)
    }

    // MARK: - Get session state

    func getSession(sessionId: String) async throws -> SessionStateResponse {
        let data = try await request(method: "GET", path: "/custom/session/\(sessionId)", timeout: 15)
        return try JSONDecoder().decode(SessionStateResponse.self, from: data)
    }

    // MARK: - Networking

    private func request(method: String, path: String, body: [String: Any]? = nil, timeout: TimeInterval = 90) async throws -> Data {
        guard let url = URL(string: baseURL + path) else {
            throw CustomLessonError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(workerSecret, forHTTPHeaderField: "x-worker-secret")
        request.timeoutInterval = timeout
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CustomLessonError.networkError
        }
        if http.statusCode == 404 {
            throw CustomLessonError.sessionExpired
        }
        guard (200...299).contains(http.statusCode) else {
            throw CustomLessonError.serverError(http.statusCode)
        }
        return data
    }
}

// MARK: - Errors

enum CustomLessonError: LocalizedError {
    case invalidURL
    case networkError
    case imageExportFailed
    case sessionExpired
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL."
        case .networkError: return "Could not reach the lesson server. Check your connection."
        case .imageExportFailed: return "Could not export your drawing."
        case .sessionExpired: return "Your lesson session has expired. Start a new one."
        case .serverError(let code): return "Server error (\(code)). Please try again."
        }
    }
}
