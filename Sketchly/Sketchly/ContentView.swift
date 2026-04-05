//
//  ContentView.swift
//  Sketchly
//
//  Root TabView with Discover, Learn, Practice, Settings tabs
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(PremiumManager.self) private var premiumManager
    @Environment(\.modelContext) private var modelContext

    @AppStorage("com.appfactory.sketchly.hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showOnboarding: Bool = false
    @State private var selectedTab: Tab = .discover

    init() {
        // FASTLANE_SNAPSHOT: skip onboarding for automated screenshots
        if ProcessInfo.processInfo.arguments.contains("-FASTLANE_SNAPSHOT") {
            UserDefaults.standard.set(true, forKey: "com.appfactory.sketchly.hasCompletedOnboarding")
        }
    }

    enum Tab: String, CaseIterable {
        case discover = "Discover"
        case learn = "Learn"
        case practice = "Practice"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .discover: return "house.fill"
            case .learn: return "books.vertical.fill"
            case .practice: return "pencil.tip.crop.circle.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView {
                    showOnboarding = false
                }
            } else {
                mainTabView
            }
        }
        .onAppear {
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
            // Seed data if needed
            LessonService.shared.seedLessonsIfNeeded(context: modelContext)
            LessonService.shared.seedUserProgressIfNeeded(context: modelContext)
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: Tab.discover.icon)
                }
                .tag(Tab.discover)

            LessonBrowserView()
                .tabItem {
                    Label("Learn", systemImage: Tab.learn.icon)
                }
                .tag(Tab.learn)

            PracticeView()
                .tabItem {
                    Label("Practice", systemImage: Tab.practice.icon)
                }
                .tag(Tab.practice)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .tint(.orange)
        .reviewPrompt()
    }
}
