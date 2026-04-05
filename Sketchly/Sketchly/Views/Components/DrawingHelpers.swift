//
//  DrawingHelpers.swift
//  Sketchly
//
//  Shared helper functions used by both LessonPlayerView and CustomLessonPlayerView.
//

import SwiftUI
import PencilKit
import AVFoundation
import UIKit

// MARK: - Canvas Export

func exportCanvasAsImage(_ drawing: PKDrawing) -> UIImage? {
    let size = CGSize(width: 390, height: 350)
    let drawingBounds = CGRect(origin: .zero, size: size)
    let drawingImage = drawing.image(from: drawingBounds, scale: UIScreen.main.scale)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        UIColor.white.setFill()
        ctx.fill(drawingBounds)
        drawingImage.draw(in: drawingBounds)
    }
}

// MARK: - Speech

func speakInstruction(_ text: String, using synthesizer: AVSpeechSynthesizer) {
    synthesizer.stopSpeaking(at: .immediate)
    let utterance = AVSpeechUtterance(string: text)
    utterance.rate = 0.48
    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    synthesizer.speak(utterance)
}

// MARK: - Score Color

func scoreColor(_ score: Int) -> Color {
    if score >= 8 { return .green }
    if score >= 6 { return .orange }
    return .red
}
