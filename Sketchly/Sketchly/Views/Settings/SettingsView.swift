//
//  SettingsView.swift
//  Sketchly
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(PremiumManager.self) private var premiumManager
    @State private var showPaywall = false
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""
    @State private var isRestoring = false
    @AppStorage("com.appfactory.sketchly.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("com.appfactory.sketchly.darkModeEnabled") private var appearanceMode = 0 // 0=system, 1=light, 2=dark

    var body: some View {
        NavigationStack {
            List {
                // Premium Section
                if !premiumManager.isPremium {
                    Section {
                        Button(action: { showPaywall = true }) {
                            HStack(spacing: 16) {
                                Image(systemName: "crown.fill")
                                    .font(.title2)
                                    .foregroundStyle(
                                        LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Unlock Sketchly Premium")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("AI critique, full library, and more")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    Section {
                        HStack(spacing: 16) {
                            Image(systemName: "crown.fill")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sketchly Premium")
                                    .font(.headline)
                                Text("Active subscription")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }

                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // App Settings
                Section(header: Text("App Settings")) {
                    Toggle("Drawing Reminders", isOn: $notificationsEnabled)

                    Picker("Appearance", selection: $appearanceMode) {
                        Text("System").tag(0)
                        Text("Light").tag(1)
                        Text("Dark").tag(2)
                    }
                }

                // Account
                Section(header: Text("Account")) {
                    Button(action: {
                        Task { await restorePurchases() }
                    }) {
                        HStack {
                            Label("Restore Purchases", systemImage: "arrow.clockwise.circle")
                            if isRestoring {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRestoring)

                    if premiumManager.isPremium {
                        Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                            Label("Manage Subscription", systemImage: "creditcard")
                        }
                    }
                }

                // Learning
                Section(header: Text("Learning")) {
                    NavigationLink(destination: UserProgressView().environment(premiumManager)) {
                        Label("My Progress", systemImage: "chart.bar.fill")
                    }

                    NavigationLink(destination: SkillLevelSettingsView()) {
                        Label("My Skill Level", systemImage: "pencil.tip")
                    }

                    NavigationLink(destination: DrawingGoalSettingsView()) {
                        Label("Drawing Goal", systemImage: "target")
                    }
                }

                // Support
                Section(header: Text("Support")) {
                    Link(destination: URL(string: "mailto:support@appfactory.dev?subject=Sketchly Support")!) {
                        Label("Contact Support", systemImage: "envelope")
                    }

                    Link(destination: URL(string: "https://appfactory.dev/sketchly/help")!) {
                        Label("Help Center", systemImage: "questionmark.circle")
                    }

                    Button(action: {
                        guard let scene = UIApplication.shared.connectedScenes
                            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
                        SKStoreReviewController.requestReview(in: scene)
                    }) {
                        Label("Rate Sketchly", systemImage: "star.fill")
                    }

                    Link(destination: URL(string: "https://appfactory.dev/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }

                    Link(destination: URL(string: "https://appfactory.dev/terms")!) {
                        Label("Terms of Use", systemImage: "doc.text.fill")
                    }
                }

                // App Info
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Bundle ID")
                        Spacer()
                        Text("com.appfactory.sketchlydrawwithaifeedback")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(premiumManager)
        }
        .alert("Restore Purchases", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage)
        }
    }

    private func restorePurchases() async {
        isRestoring = true
        await premiumManager.restorePurchases()
        isRestoring = false

        if premiumManager.isPremium {
            restoreMessage = "Your purchases have been restored successfully!"
        } else {
            restoreMessage = "No previous purchases found for this account."
        }
        showRestoreAlert = true
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - Skill Level Settings
struct SkillLevelSettingsView: View {
    @AppStorage("com.appfactory.sketchly.skillLevel") private var currentLevel = SkillLevel.beginner.rawValue

    var body: some View {
        List {
            ForEach(SkillLevel.allCases) { level in
                Button(action: {
                    currentLevel = level.rawValue
                    HapticManager.selection()
                }) {
                    HStack {
                        Image(systemName: level.icon)
                            .foregroundColor(.orange)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(level.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Text(level.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if currentLevel == level.rawValue {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .navigationTitle("Skill Level")
    }
}

// MARK: - Drawing Goal Settings
struct DrawingGoalSettingsView: View {
    @AppStorage("com.appfactory.sketchly.selectedGoal") private var selectedGoal = DrawingGoal.general.rawValue

    var body: some View {
        List {
            ForEach(DrawingGoal.allCases) { goal in
                Button(action: {
                    selectedGoal = goal.rawValue
                    HapticManager.selection()
                }) {
                    HStack {
                        Image(systemName: goal.icon)
                            .foregroundColor(goal.color)
                            .frame(width: 30)

                        Text(goal.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Spacer()

                        if selectedGoal == goal.rawValue {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .navigationTitle("Drawing Goal")
    }
}
