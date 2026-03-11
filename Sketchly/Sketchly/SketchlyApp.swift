//
//  SketchlyApp.swift
//  Sketchly
//
//  Main app entry point with SwiftData, StoreKit 2, and SDK integrations
//

import SwiftUI
import SwiftData

@main
struct SketchlyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let modelContainer: ModelContainer
    @State private var premiumManager = PremiumManager()

    init() {
        do {
            let schema = Schema([
                LessonModel.self,
                DrawingSessionModel.self,
                UserProgressModel.self,
                GalleryPostModel.self,
                CurriculumTrackModel.self,
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        ReviewManager.shared.recordAppLaunch()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(premiumManager)
                .onAppear {
                    Task {
                        await premiumManager.refreshPremiumStatus()
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - App Delegate for SDK Initialization
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if DEBUG
        print("[AppDelegate] Sketchly launched")
        #endif

        // Initialize Firebase
        // FirebaseApp.configure()

        // Initialize Facebook SDK
        // ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)

        // Initialize Analytics Service
        Task { @MainActor in
            AnalyticsService.shared.initialize()
            AnalyticsService.shared.track(.appOpen)
        }

        // Request ATT permission
        Task { @MainActor in
            _ = await ATTService.shared.requestIfNeeded()
            await AttributionManager.shared.requestAttributionIfNeeded()
        }

        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        // Handle Facebook SDK URL
        // return ApplicationDelegate.shared.application(app, open: url, options: options)
        return false
    }
}
