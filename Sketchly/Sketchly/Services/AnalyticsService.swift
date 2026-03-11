//
//  AnalyticsService.swift
//  Sketchly
//
//  Analytics events - behavioral only
//

import Foundation

enum AnalyticsEvent {
    case appOpen
    case signUp(method: String)
    case onboardingStarted
    case onboardingStepCompleted(step: Int)
    case onboardingCompleted(goal: String)
    case onboardingSkipped(atStep: Int)

    case lessonStarted(lessonId: String, category: String)
    case lessonCompleted(lessonId: String, duration: Int)
    case drawingSessionStarted
    case drawingSessionSaved
    case aiFeedbackRequested
    case aiFeedbackReceived

    case paywallViewed(trigger: String)
    case paywallDismissed
    case subscriptionPurchased(productId: String, price: Double)
    case subscriptionStart(productId: String, price: Double)
    case subscriptionRestored
    case trialStarted(productId: String)

    case featureUsed(feature: String)
    case featureAccessAttempted(feature: PremiumFeature, isPremium: Bool)
    case screenView(screenName: String, screenClass: String)
    case galleryPostShared
    case trackEnrolled(track: String)
    case certificateEarned(track: String)
    case streakUpdated(days: Int)

    var name: String {
        switch self {
        case .appOpen: return "app_open"
        case .signUp: return "sign_up"
        case .onboardingStarted: return "onboarding_started"
        case .onboardingStepCompleted: return "onboarding_step_completed"
        case .onboardingCompleted: return "onboarding_completed"
        case .onboardingSkipped: return "onboarding_skipped"
        case .lessonStarted: return "lesson_started"
        case .lessonCompleted: return "lesson_completed"
        case .drawingSessionStarted: return "drawing_session_started"
        case .drawingSessionSaved: return "drawing_session_saved"
        case .aiFeedbackRequested: return "ai_feedback_requested"
        case .aiFeedbackReceived: return "ai_feedback_received"
        case .paywallViewed: return "paywall_viewed"
        case .paywallDismissed: return "paywall_dismissed"
        case .subscriptionPurchased: return "purchase"
        case .subscriptionStart: return "subscription_start"
        case .subscriptionRestored: return "subscription_restored"
        case .trialStarted: return "trial_started"
        case .featureUsed: return "feature_used"
        case .featureAccessAttempted: return "feature_access_attempted"
        case .screenView: return "screen_view"
        case .galleryPostShared: return "gallery_post_shared"
        case .trackEnrolled: return "track_enrolled"
        case .certificateEarned: return "certificate_earned"
        case .streakUpdated: return "streak_updated"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .signUp(let method):
            return ["method": method]
        case .onboardingStepCompleted(let step):
            return ["step": step]
        case .onboardingCompleted(let goal):
            return ["goal": goal]
        case .onboardingSkipped(let atStep):
            return ["at_step": atStep]
        case .lessonStarted(let lessonId, let category):
            return ["lesson_id": lessonId, "category": category]
        case .lessonCompleted(let lessonId, let duration):
            return ["lesson_id": lessonId, "duration_seconds": duration]
        case .paywallViewed(let trigger):
            return ["trigger": trigger]
        case .subscriptionPurchased(let productId, let price):
            return ["item_id": productId, "price": price, "currency": "USD"]
        case .subscriptionStart(let productId, let price):
            return ["product_id": productId, "price": price]
        case .trialStarted(let productId):
            return ["product_id": productId]
        case .featureUsed(let feature):
            return ["feature_name": feature]
        case .featureAccessAttempted(let feature, let isPremium):
            return ["feature": feature.rawValue, "is_premium": isPremium]
        case .screenView(let screenName, let screenClass):
            return ["screen_name": screenName, "screen_class": screenClass]
        case .trackEnrolled(let track):
            return ["track": track]
        case .certificateEarned(let track):
            return ["track": track]
        case .streakUpdated(let days):
            return ["days": days]
        default:
            return [:]
        }
    }
}

@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    private var isInitialized = false

    private init() {}

    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true

        setUserProperty(appVersion, forName: "app_version")

        #if DEBUG
        print("[AnalyticsService] Initialized")
        #endif
    }

    func track(_ event: AnalyticsEvent) {
        guard isInitialized else {
            #if DEBUG
            print("[AnalyticsService] Warning: Attempted to track event before initialization")
            #endif
            return
        }

        #if DEBUG
        print("[Analytics] \(event.name): \(event.parameters)")
        #endif

        // TODO: Integrate Firebase Analytics
        // Analytics.logEvent(event.name, parameters: event.parameters)
    }

    func setUserProperty(_ value: String, forName name: String) {
        guard isInitialized else { return }
        #if DEBUG
        print("[Analytics] User Property - \(name): \(value)")
        #endif
        // TODO: Analytics.setUserProperty(value, forName: name)
    }

    func setUserId(_ userId: String?) {
        guard isInitialized else { return }
        #if DEBUG
        print("[Analytics] User ID: \(userId ?? "nil")")
        #endif
        // TODO: Analytics.setUserID(userId)
    }

    func setSubscriptionStatus(_ status: String) {
        setUserProperty(status, forName: "subscription_status")
    }

    func logScreenView(screenName: String, screenClass: String) {
        track(.screenView(screenName: screenName, screenClass: screenClass))
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
}
