//
//  OnboardingView.swift
//  Sketchly
//

import SwiftUI

struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                ProgressView(value: viewModel.progress)
                    .tint(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Skip button
                HStack {
                    Spacer()
                    if viewModel.currentStep < 2 {
                        Button("Skip") {
                            viewModel.skip()
                            HapticManager.impact(style: .light)
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                    }
                }

                // Content
                TabView(selection: $viewModel.currentStep) {
                    welcomeStep.tag(0)
                    goalStep.tag(1)
                    skillStep.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: viewModel.currentStep)

                // Navigation buttons
                VStack(spacing: 12) {
                    Button(action: {
                        HapticManager.impact(style: .medium)
                        if viewModel.currentStep == 2 {
                            viewModel.advance()
                            onComplete()
                        } else {
                            viewModel.advance()
                        }
                    }) {
                        Text(viewModel.currentStep == 2 ? "Start Drawing!" : "Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: viewModel.canAdvance ? [.orange, .pink] : [.gray.opacity(0.5), .gray.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                    }
                    .disabled(!viewModel.canAdvance)
                    .padding(.horizontal)

                    if viewModel.currentStep > 0 {
                        Button("Back") {
                            viewModel.back()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onChange(of: viewModel.isCompleted) { _, completed in
            if completed { onComplete() }
        }
    }

    // MARK: - Welcome Step
    private var welcomeStep: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange.opacity(0.2), .pink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: "paintbrush.pointed.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 16) {
                Text("Welcome to Sketchly")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Your personal drawing coach with AI-powered feedback. Learn to draw portraits, manga, landscapes, and more.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 16) {
                featureRow(icon: "brain.head.profile", text: "AI critique of your drawings")
                featureRow(icon: "books.vertical.fill", text: "50+ structured lessons")
                featureRow(icon: "person.2.fill", text: "Community gallery")
                featureRow(icon: "rosette", text: "Earn milestone certificates")
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: 30)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
    }

    // MARK: - Goal Step
    private var goalStep: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("What do you want to draw?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("We'll personalize your learning journey")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(DrawingGoal.allCases) { goal in
                    GoalCard(
                        goal: goal,
                        isSelected: viewModel.selectedGoal == goal
                    ) {
                        viewModel.selectedGoal = goal
                        HapticManager.selection()
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Skill Step
    private var skillStep: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("What's your skill level?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("No pressure — this helps us start you at the right place")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                ForEach(SkillLevel.allCases) { level in
                    SkillLevelCard(
                        level: level,
                        isSelected: viewModel.selectedSkillLevel == level
                    ) {
                        viewModel.selectedSkillLevel = level
                        HapticManager.selection()
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

// MARK: - Goal Card
struct GoalCard: View {
    let goal: DrawingGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: goal.icon)
                    .font(.title)
                    .foregroundStyle(
                        isSelected ?
                        AnyShapeStyle(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)) :
                        AnyShapeStyle(Color.secondary)
                    )

                Text(goal.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.orange.opacity(0.1) : Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ?
                                LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing),
                                lineWidth: 2
                            )
                    )
            )
        }
    }
}

// MARK: - Skill Level Card
struct SkillLevelCard: View {
    let level: SkillLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: level.icon)
                    .font(.title2)
                    .foregroundStyle(
                        isSelected ?
                        AnyShapeStyle(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)) :
                        AnyShapeStyle(Color.secondary)
                    )
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(level.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(
                            LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                        )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange.opacity(0.1) : Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ?
                                LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing),
                                lineWidth: 2
                            )
                    )
            )
        }
    }
}
