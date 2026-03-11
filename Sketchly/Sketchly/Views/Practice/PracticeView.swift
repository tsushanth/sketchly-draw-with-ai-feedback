//
//  PracticeView.swift
//  Sketchly
//

import SwiftUI
import SwiftData
import PencilKit

struct PracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumManager.self) private var premiumManager
    var associatedLesson: LessonModel? = nil

    @State private var viewModel = PracticeViewModel()
    @State private var showAIFeedback = false
    @State private var showPaywall = false
    @State private var showSaveAlert = false
    @State private var drawing = PKDrawing()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Canvas
                DrawingCanvasView(drawing: $drawing)
                    .ignoresSafeArea()
                    .onAppear {
                        viewModel.startSession()
                    }

                // Bottom toolbar
                bottomToolbar
            }
            .navigationTitle(associatedLesson?.title ?? "Practice Canvas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.undoLastStroke()
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                    }

                    Button(action: {
                        viewModel.redoLastStroke()
                    }) {
                        Image(systemName: "arrow.uturn.forward")
                    }

                    Button(action: {
                        showSaveAlert = true
                    }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
        }
        .sheet(isPresented: $showAIFeedback) {
            if let image = exportDrawingAsImage() {
                AIFeedbackView(drawingImage: image)
                    .environment(premiumManager)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(premiumManager)
        }
        .alert("Save Drawing", isPresented: $showSaveAlert) {
            Button("Save") {
                Task { await saveDrawing() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save this drawing to your practice sessions?")
        }
        .onAppear {
            AnalyticsService.shared.logScreenView(screenName: "Practice", screenClass: "PracticeView")
        }
    }

    // MARK: - Bottom Toolbar
    private var bottomToolbar: some View {
        HStack(spacing: 20) {
            // Clear
            ToolbarButton(icon: "trash", label: "Clear") {
                viewModel.currentDrawing = PKDrawing()
                drawing = PKDrawing()
                HapticManager.impact(style: .medium)
            }

            Spacer()

            // AI Feedback (premium)
            Button(action: {
                if premiumManager.isPremium {
                    showAIFeedback = true
                    AnalyticsService.shared.track(.aiFeedbackRequested)
                } else {
                    showPaywall = true
                    AnalyticsService.shared.track(.paywallViewed(trigger: "ai_feedback"))
                }
                HapticManager.impact(style: .medium)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                    Text("AI Feedback")
                        .fontWeight(.semibold)
                    if !premiumManager.isPremium {
                        PremiumBadge(style: .compact)
                    }
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [.orange, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }

            Spacer()

            // Gallery share (premium)
            ToolbarButton(icon: "square.and.arrow.up", label: "Share") {
                if premiumManager.isPremium {
                    // Share action
                } else {
                    showPaywall = true
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
        )
    }

    private func exportDrawingAsImage() -> UIImage? {
        let bounds = drawing.bounds.isEmpty ?
            CGRect(x: 0, y: 0, width: 400, height: 400) :
            drawing.bounds.insetBy(dx: -20, dy: -20)
        return drawing.image(from: bounds, scale: UIScreen.main.scale)
    }

    private func saveDrawing() async {
        let drawingData = drawing.dataRepresentation()
        let duration = Int(Date().timeIntervalSince(viewModel.sessionStartTime))

        let session = DrawingSessionModel(
            lessonId: associatedLesson?.id,
            canvasData: drawingData,
            durationSeconds: duration
        )
        modelContext.insert(session)
        try? modelContext.save()

        AnalyticsService.shared.track(.drawingSessionSaved)
        HapticManager.notification(type: .success)
        ReviewManager.shared.recordSuccessfulAction()
    }
}

// MARK: - Toolbar Button
struct ToolbarButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
    }
}
