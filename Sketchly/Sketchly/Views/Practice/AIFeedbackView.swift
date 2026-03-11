//
//  AIFeedbackView.swift
//  Sketchly
//

import SwiftUI
import PhotosUI

struct AIFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PremiumManager.self) private var premiumManager
    let drawingImage: UIImage?

    @State private var isAnalyzing: Bool = false
    @State private var feedback: AIDrawingFeedback?
    @State private var errorMessage: String?
    @State private var selectedItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var showCamera: Bool = false
    @State private var imageSource: ImageSource = .canvas

    enum ImageSource {
        case canvas, camera, photoLibrary
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let feedback = feedback {
                        feedbackResultView(feedback: feedback)
                    } else {
                        analyzeView
                    }

                    Spacer(minLength: 80)
                }
                .padding()
            }
            .navigationTitle("AI Drawing Critique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                if feedback != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Analyze Again") {
                            self.feedback = nil
                        }
                    }
                }
            }
        }
        .onAppear {
            if let image = drawingImage {
                capturedImage = image
                Task { await analyzeDrawing(image: image) }
            }
        }
    }

    // MARK: - Analyze View
    private var analyzeView: some View {
        VStack(spacing: 24) {
            // Image preview
            if let image = capturedImage ?? drawingImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 250)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            } else {
                // Image source selection
                imageSourceSelection
            }

            if isAnalyzing {
                analyzingIndicator
            } else if capturedImage == nil && drawingImage == nil {
                analyzeButton
            } else if let error = errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var imageSourceSelection: some View {
        VStack(spacing: 16) {
            Text("Choose your drawing to analyze")
                .font(.headline)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                // Camera option
                PhotoCaptureButton(
                    icon: "camera.fill",
                    title: "Take a Photo",
                    subtitle: "Photograph your drawing on paper",
                    color: .blue
                ) {
                    showCamera = true
                }

                // Photo Library option
                PhotosPickerButton(
                    selectedItem: $selectedItem,
                    icon: "photo.fill",
                    title: "Choose from Library",
                    subtitle: "Pick an existing drawing photo",
                    color: .green
                )
                .onChange(of: selectedItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            capturedImage = image
                            await analyzeDrawing(image: image)
                        }
                    }
                }
            }
        }
    }

    private var analyzeButton: some View {
        Button(action: {
            if let image = capturedImage ?? drawingImage {
                Task { await analyzeDrawing(image: image) }
            }
        }) {
            HStack {
                Image(systemName: "brain.head.profile")
                Text("Analyze Drawing")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(16)
        }
    }

    private var analyzingIndicator: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(
                    LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                )

            Text("AI is analyzing your drawing...")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Checking proportions, shading, and line weight")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    // MARK: - Feedback Result View
    private func feedbackResultView(feedback: AIDrawingFeedback) -> some View {
        VStack(spacing: 20) {
            // Overall Score
            overallScoreCard(score: feedback.overallScore)

            // Encouragement
            Text(feedback.encouragement)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

            // Category scores
            VStack(spacing: 12) {
                feedbackCategoryCard(title: "Proportions", systemIcon: "ruler", item: feedback.proportions)
                feedbackCategoryCard(title: "Shading", systemIcon: "sun.max.fill", item: feedback.shading)
                feedbackCategoryCard(title: "Line Weight", systemIcon: "pencil.tip", item: feedback.lineWeight)
                feedbackCategoryCard(title: "Composition", systemIcon: "viewfinder", item: feedback.composition)
            }

            // Top Tip
            topTipCard(tip: feedback.topTip)
        }
    }

    private func overallScoreCard(score: Int) -> some View {
        VStack(spacing: 8) {
            Text("Overall Score")
                .font(.headline)
                .foregroundColor(.secondary)

            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(
                        LinearGradient(
                            colors: scoreGradient(score: score),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: scoreGradient(score: score), startPoint: .leading, endPoint: .trailing)
                        )
                    Text("/ 100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private func feedbackCategoryCard(title: String, systemIcon: String, item: AIDrawingFeedback.FeedbackItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: systemIcon)
                    .font(.headline)

                Spacer()

                // Score badge
                Text("\(item.score)/10")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor(item.score))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(scoreColor(item.score).opacity(0.15))
                    .cornerRadius(8)
            }

            // Score bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: scoreGradient(score: item.score * 10),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(item.score) / 10, height: 6)
                }
            }
            .frame(height: 6)

            Text(item.comment)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if !item.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tips:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)

                    ForEach(item.suggestions, id: \.self) { suggestion in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.top, 1)

                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func topTipCard(tip: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Pro Tip")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                    )

                Text(tip)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Int) -> Color {
        if score >= 8 { return .green }
        if score >= 6 { return .orange }
        return .red
    }

    private func scoreGradient(score: Int) -> [Color] {
        if score >= 80 { return [.green, .teal] }
        if score >= 60 { return [.orange, .yellow] }
        return [.red, .orange]
    }

    private func analyzeDrawing(image: UIImage) async {
        isAnalyzing = true
        errorMessage = nil
        AnalyticsService.shared.track(.aiFeedbackRequested)

        do {
            let result = try await AIFeedbackService.shared.analyzeDrawing(image: image)
            feedback = result
            AnalyticsService.shared.track(.aiFeedbackReceived)
            HapticManager.notification(type: .success)
        } catch {
            errorMessage = "Failed to analyze drawing. Please try again."
            HapticManager.notification(type: .error)
        }

        isAnalyzing = false
    }
}

// MARK: - Photo Capture Button
struct PhotoCaptureButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Photos Picker Button
struct PhotosPickerButton: View {
    @Binding var selectedItem: PhotosPickerItem?
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}
