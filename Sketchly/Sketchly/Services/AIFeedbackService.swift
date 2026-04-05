//
//  AIFeedbackService.swift
//  Sketchly
//
//  Real AI drawing analysis via Claude claude-sonnet-4-6 vision API
//

import Foundation
import UIKit

// MARK: - Anthropic API Models

private struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }

    struct Message: Encodable {
        let role: String
        let content: [ContentBlock]
    }

    enum ContentBlock: Encodable {
        case text(String)
        case image(mediaType: String, data: String)

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let text):
                try container.encode("text", forKey: .type)
                try container.encode(text, forKey: .text)
            case .image(let mediaType, let data):
                try container.encode("image", forKey: .type)
                let source = ImageSource(type: "base64", mediaType: mediaType, data: data)
                try container.encode(source, forKey: .source)
            }
        }

        enum CodingKeys: String, CodingKey {
            case type, text, source
        }

        struct ImageSource: Encodable {
            let type: String
            let mediaType: String
            let data: String
            enum CodingKeys: String, CodingKey {
                case type
                case mediaType = "media_type"
                case data
            }
        }
    }
}

private struct AnthropicResponse: Decodable {
    let content: [ContentBlock]

    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
}

// MARK: - AI Feedback Service

@MainActor
final class AIFeedbackService {
    static let shared = AIFeedbackService()

    private let apiKey = "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"
    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!

    private init() {}

    // MARK: - Analyze Drawing

    func analyzeDrawing(image: UIImage) async throws -> AIDrawingFeedback {
        guard apiKey != "YOUR_ANTHROPIC_API_KEY" else {
            // Fall back to mock if key not set
            try await Task.sleep(nanoseconds: 1_500_000_000)
            return generateMockFeedback()
        }

        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw AIFeedbackError.imageEncodingFailed
        }

        let base64Image = imageData.base64EncodedString()

        let prompt = """
        You are an expert drawing teacher analyzing a student's drawing. Analyze this drawing and respond ONLY with a valid JSON object in exactly this format, with no other text:

        {
          "proportions": {
            "score": <integer 1-10>,
            "comment": "<one sentence observation>",
            "suggestions": ["<tip 1>", "<tip 2>", "<tip 3>"]
          },
          "shading": {
            "score": <integer 1-10>,
            "comment": "<one sentence observation>",
            "suggestions": ["<tip 1>", "<tip 2>"]
          },
          "lineWeight": {
            "score": <integer 1-10>,
            "comment": "<one sentence observation>",
            "suggestions": ["<tip 1>", "<tip 2>"]
          },
          "composition": {
            "score": <integer 1-10>,
            "comment": "<one sentence observation>",
            "suggestions": ["<tip 1>", "<tip 2>"]
          },
          "overallScore": <integer 1-100>,
          "encouragement": "<2-3 encouraging sentences about their specific work>",
          "topTip": "<the single most impactful tip for this drawing>"
        }

        Be specific to what you actually see in the drawing. Scores should reflect real quality — don't inflate.
        """

        let request = AnthropicRequest(
            model: "claude-sonnet-4-6",
            maxTokens: 1024,
            messages: [
                .init(role: "user", content: [
                    .image(mediaType: "image/jpeg", data: base64Image),
                    .text(prompt)
                ])
            ]
        )

        var urlRequest = URLRequest(url: apiURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AIFeedbackError.apiError
        }

        let apiResponse = try JSONDecoder().decode(AnthropicResponse.self, from: data)

        guard let text = apiResponse.content.first?.text else {
            throw AIFeedbackError.emptyResponse
        }

        return try parseFeedback(from: text)
    }

    // MARK: - Parse JSON Response

    private func parseFeedback(from text: String) throws -> AIDrawingFeedback {
        // Extract JSON from response (handle any surrounding text)
        let jsonString: String
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            jsonString = String(text[start...end])
        } else {
            jsonString = text
        }

        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw AIFeedbackError.parseError
        }

        func feedbackItem(from dict: [String: Any]?) -> AIDrawingFeedback.FeedbackItem {
            guard let dict else { return .init(score: 5, comment: "Unable to analyze.", suggestions: []) }
            return .init(
                score: dict["score"] as? Int ?? 5,
                comment: dict["comment"] as? String ?? "",
                suggestions: dict["suggestions"] as? [String] ?? []
            )
        }

        return AIDrawingFeedback(
            proportions: feedbackItem(from: json["proportions"] as? [String: Any]),
            shading: feedbackItem(from: json["shading"] as? [String: Any]),
            lineWeight: feedbackItem(from: json["lineWeight"] as? [String: Any]),
            composition: feedbackItem(from: json["composition"] as? [String: Any]),
            overallScore: json["overallScore"] as? Int ?? 50,
            encouragement: json["encouragement"] as? String ?? "",
            topTip: json["topTip"] as? String ?? ""
        )
    }

    // MARK: - Mock Fallback

    private func generateMockFeedback() -> AIDrawingFeedback {
        AIDrawingFeedback(
            proportions: .init(score: 7, comment: "Good overall proportions with minor inconsistencies.", suggestions: ["Use light guidelines before committing to final lines", "Check symmetry by flipping your reference"]),
            shading: .init(score: 6, comment: "Shading shows understanding of light source, but transitions could be smoother.", suggestions: ["Build up tone in multiple light layers", "Identify your light source before shading"]),
            lineWeight: .init(score: 8, comment: "Confident line work with good variation.", suggestions: ["Use heavier lines for foreground elements", "Taper lines at endpoints"]),
            composition: .init(score: 7, comment: "Subject is well-placed. Consider the rule of thirds.", suggestions: ["Try placing the subject off-center", "Leave negative space intentionally"]),
            overallScore: 72,
            encouragement: "Great effort! Your line confidence is improving. Focus on smooth shading transitions to take your work to the next level.",
            topTip: "Practice the five elements of shading: flat light, shadow edge, core shadow, reflected light, and cast shadow."
        )
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

// MARK: - Errors

enum AIFeedbackError: LocalizedError {
    case imageEncodingFailed
    case apiError
    case emptyResponse
    case parseError

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed: return "Failed to process the image."
        case .apiError: return "AI service is currently unavailable. Please try again."
        case .emptyResponse: return "Received an empty response from the AI."
        case .parseError: return "Failed to parse AI feedback."
        }
    }
}
