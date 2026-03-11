//
//  PracticeViewModel.swift
//  Sketchly
//

import Foundation
import SwiftUI
import PencilKit

@MainActor
@Observable
final class PracticeViewModel {
    var canvasView = PKCanvasView()
    var currentDrawing = PKDrawing()
    var toolPicker = PKToolPicker()
    var isSaving: Bool = false
    var savedSession: DrawingSessionModel?
    var showSaveConfirmation: Bool = false
    var selectedTool: DrawingTool = .pencil
    var strokeColor: Color = .black
    var strokeWidth: CGFloat = 2.0
    var showColorPicker: Bool = false
    var sessionStartTime: Date = Date()

    func startSession() {
        sessionStartTime = Date()
        AnalyticsService.shared.track(.drawingSessionStarted)
    }

    func clearCanvas() {
        currentDrawing = PKDrawing()
        canvasView.drawing = currentDrawing
        HapticManager.impact(style: .medium)
    }

    func undoLastStroke() {
        canvasView.undoManager?.undo()
        HapticManager.impact(style: .light)
    }

    func redoLastStroke() {
        canvasView.undoManager?.redo()
        HapticManager.impact(style: .light)
    }

    func saveDrawing(context: Any?) async -> DrawingSessionModel? {
        isSaving = true
        defer { isSaving = false }

        let drawingData = canvasView.drawing.dataRepresentation()
        let duration = Int(Date().timeIntervalSince(sessionStartTime))

        let session = DrawingSessionModel(
            canvasData: drawingData,
            durationSeconds: duration
        )

        AnalyticsService.shared.track(.drawingSessionSaved)
        HapticManager.notification(type: .success)
        savedSession = session
        showSaveConfirmation = true

        return session
    }

    func exportAsImage() -> UIImage? {
        let image = canvasView.drawing.image(
            from: canvasView.drawing.bounds,
            scale: UIScreen.main.scale
        )
        return image
    }
}

// MARK: - Drawing Tools
enum DrawingTool: String, CaseIterable, Identifiable {
    case pencil = "Pencil"
    case pen = "Pen"
    case marker = "Marker"
    case eraser = "Eraser"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pencil: return "pencil"
        case .pen: return "pencil.tip"
        case .marker: return "highlighter"
        case .eraser: return "eraser"
        }
    }
}
