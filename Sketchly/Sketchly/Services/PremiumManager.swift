//
//  PremiumManager.swift
//  Sketchly
//
//  Manages premium feature access and purchase state persistence
//

import Foundation
import SwiftUI
import StoreKit

// MARK: - Premium Feature Definition
enum PremiumFeature: String, CaseIterable, Identifiable {
    // Free Features (~40%)
    case basicLessons = "basic_lessons"
    case lessonBrowser = "lesson_browser"
    case basicCanvas = "basic_canvas"
    case progressTracker = "progress_tracker"

    // Premium Features (~60%)
    case aiCritique = "ai_critique"
    case fullLessonLibrary = "full_lesson_library"
    case curriculumTracks = "curriculum_tracks"
    case communityGallery = "community_gallery"
    case referenceLibrary = "reference_library"
    case layerBreakdowns = "layer_breakdowns"
    case customBrushes = "custom_brushes"
    case offlineDownloads = "offline_downloads"
    case certificates = "certificates"
    case advancedCanvas = "advanced_canvas"

    var id: String { rawValue }

    var isPremium: Bool {
        switch self {
        case .basicLessons, .lessonBrowser, .basicCanvas, .progressTracker:
            return false
        default:
            return true
        }
    }

    var displayName: String {
        switch self {
        case .basicLessons: return "Basic Lessons"
        case .lessonBrowser: return "Lesson Browser"
        case .basicCanvas: return "Drawing Canvas"
        case .progressTracker: return "Progress Tracker"
        case .aiCritique: return "AI Drawing Critique"
        case .fullLessonLibrary: return "Full Lesson Library"
        case .curriculumTracks: return "Curriculum Tracks"
        case .communityGallery: return "Community Gallery"
        case .referenceLibrary: return "Reference Photo Library"
        case .layerBreakdowns: return "Layer Breakdowns"
        case .customBrushes: return "Custom Brushes"
        case .offlineDownloads: return "Offline Downloads"
        case .certificates: return "Milestone Certificates"
        case .advancedCanvas: return "Advanced Canvas Tools"
        }
    }

    var description: String {
        switch self {
        case .basicLessons: return "Access 5 free drawing lessons"
        case .lessonBrowser: return "Browse lessons by category"
        case .basicCanvas: return "Practice drawing on digital canvas"
        case .progressTracker: return "Track your learning progress"
        case .aiCritique: return "Get AI-powered feedback on your drawings"
        case .fullLessonLibrary: return "Unlock all 50+ drawing lessons"
        case .curriculumTracks: return "Follow structured learning paths"
        case .communityGallery: return "Share and explore community artwork"
        case .referenceLibrary: return "Access 1000+ reference photos"
        case .layerBreakdowns: return "Step-by-step drawing overlays"
        case .customBrushes: return "Premium brush collection"
        case .offlineDownloads: return "Download lessons for offline use"
        case .certificates: return "Earn certificates on track completion"
        case .advancedCanvas: return "Advanced drawing tools and brushes"
        }
    }

    var icon: String {
        switch self {
        case .basicLessons: return "book.fill"
        case .lessonBrowser: return "rectangle.grid.2x2.fill"
        case .basicCanvas: return "pencil.tip"
        case .progressTracker: return "chart.bar.fill"
        case .aiCritique: return "brain.head.profile"
        case .fullLessonLibrary: return "books.vertical.fill"
        case .curriculumTracks: return "map.fill"
        case .communityGallery: return "person.2.fill"
        case .referenceLibrary: return "photo.stack.fill"
        case .layerBreakdowns: return "square.3.layers.3d"
        case .customBrushes: return "paintbrush.pointed.fill"
        case .offlineDownloads: return "arrow.down.circle.fill"
        case .certificates: return "rosette"
        case .advancedCanvas: return "paintbrush.fill"
        }
    }

    static var premiumFeatures: [PremiumFeature] {
        allCases.filter { $0.isPremium }
    }

    static var freeFeatures: [PremiumFeature] {
        allCases.filter { !$0.isPremium }
    }
}

// MARK: - Premium Manager
@MainActor
@Observable
final class PremiumManager {
    // MARK: - Properties

    private let storeKitManager: StoreKitManager
    private let userDefaults: UserDefaults

    private enum Keys {
        static let isPremiumKey = "com.appfactory.sketchly.isPremium"
        static let hasLifetimeKey = "com.appfactory.sketchly.hasLifetime"
        static let purchaseDateKey = "com.appfactory.sketchly.purchaseDate"
        static let hasSeenPaywallKey = "com.appfactory.sketchly.hasSeenPaywall"
        static let paywallDismissCountKey = "com.appfactory.sketchly.paywallDismissCount"
        static let lastPaywallShowDateKey = "com.appfactory.sketchly.lastPaywallShowDate"
    }

    // MARK: - Computed Properties

    var isPremium: Bool {
        storeKitManager.isPremium || hasLifetimePurchase
    }

    var hasActiveSubscription: Bool {
        storeKitManager.hasActiveSubscription
    }

    var hasLifetimePurchase: Bool {
        userDefaults.bool(forKey: Keys.hasLifetimeKey)
    }

    var purchaseDate: Date? {
        userDefaults.object(forKey: Keys.purchaseDateKey) as? Date
    }

    var hasSeenPaywall: Bool {
        get { userDefaults.bool(forKey: Keys.hasSeenPaywallKey) }
        set { userDefaults.set(newValue, forKey: Keys.hasSeenPaywallKey) }
    }

    var paywallDismissCount: Int {
        get { userDefaults.integer(forKey: Keys.paywallDismissCountKey) }
        set { userDefaults.set(newValue, forKey: Keys.paywallDismissCountKey) }
    }

    var lastPaywallShowDate: Date? {
        get { userDefaults.object(forKey: Keys.lastPaywallShowDateKey) as? Date }
        set { userDefaults.set(newValue, forKey: Keys.lastPaywallShowDateKey) }
    }

    var purchaseState: PurchaseState { storeKitManager.purchaseState }
    var isLoading: Bool { storeKitManager.isLoading }
    var errorMessage: String? { storeKitManager.errorMessage }
    var subscriptions: [Product] { storeKitManager.subscriptions }
    var nonConsumables: [Product] { storeKitManager.nonConsumables }
    var allProducts: [Product] { storeKitManager.allProducts }

    // MARK: - Initialization

    init(storeKitManager: StoreKitManager? = nil, userDefaults: UserDefaults = .standard) {
        self.storeKitManager = storeKitManager ?? StoreKitManager()
        self.userDefaults = userDefaults

        Task {
            await refreshPremiumStatus()
        }
    }

    // MARK: - Feature Access

    func canAccess(_ feature: PremiumFeature) -> Bool {
        if !feature.isPremium { return true }
        return isPremium
    }

    func requiresPremium(_ feature: PremiumFeature) -> Bool {
        feature.isPremium && !canAccess(feature)
    }

    // MARK: - Purchase Methods

    func purchase(_ product: Product) async throws {
        let transaction = try await storeKitManager.purchase(product)

        if let transaction = transaction {
            if transaction.productID == StoreKitProductID.lifetime.rawValue {
                userDefaults.set(true, forKey: Keys.hasLifetimeKey)
            }
            userDefaults.set(Date(), forKey: Keys.purchaseDateKey)
        }
    }

    func restorePurchases() async {
        await storeKitManager.restorePurchases()
        await refreshPremiumStatus()
    }

    func loadProducts() async {
        await storeKitManager.loadProducts()
    }

    // MARK: - Status Refresh

    func refreshPremiumStatus() async {
        await storeKitManager.updatePurchasedProducts()
    }

    // MARK: - Paywall Logic

    func shouldShowPaywall() -> Bool {
        if isPremium { return false }
        if !hasSeenPaywall { return true }

        if let lastShow = lastPaywallShowDate {
            let hoursSinceLastShow = Date().timeIntervalSince(lastShow) / 3600
            if hoursSinceLastShow < 24 { return false }
        }

        return true
    }

    func recordPaywallShown() {
        hasSeenPaywall = true
        lastPaywallShowDate = Date()
    }

    func recordPaywallDismissed() {
        paywallDismissCount += 1
    }

    // MARK: - Post-Lesson Nudge

    private static let completedLessonCountKey = "com.appfactory.sketchly.completedLessonCount"
    private static let lastPostLessonPaywallKey = "com.appfactory.sketchly.lastPostLessonPaywall"

    var completedLessonCount: Int {
        get { userDefaults.integer(forKey: Self.completedLessonCountKey) }
        set { userDefaults.set(newValue, forKey: Self.completedLessonCountKey) }
    }

    func recordLessonCompleted() {
        completedLessonCount += 1
    }

    /// Show paywall after 2nd completed lesson, then every 3 lessons,
    /// but not more than once every 48 hours.
    func shouldShowPostLessonPaywall() -> Bool {
        if isPremium { return false }
        if completedLessonCount < 2 { return false }

        // Every 3 lessons after the 2nd (2, 5, 8, 11...)
        let eligible = completedLessonCount == 2 || (completedLessonCount - 2) % 3 == 0

        if !eligible { return false }

        // 48-hour cooldown
        if let lastShow = userDefaults.object(forKey: Self.lastPostLessonPaywallKey) as? Date {
            let hoursSince = Date().timeIntervalSince(lastShow) / 3600
            if hoursSince < 48 { return false }
        }

        return true
    }

    func recordPostLessonPaywallShown() {
        userDefaults.set(Date(), forKey: Self.lastPostLessonPaywallKey)
    }

    func resetState() {
        storeKitManager.resetState()
    }

    func product(for id: StoreKitProductID) -> Product? {
        storeKitManager.product(for: id)
    }
}

// MARK: - Premium Feature Gate View Modifier
struct PremiumFeatureGate: ViewModifier {
    let feature: PremiumFeature
    @Bindable var premiumManager: PremiumManager
    @Binding var showPaywall: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                if premiumManager.requiresPremium(feature) {
                    LockedFeatureOverlay(feature: feature) {
                        showPaywall = true
                    }
                }
            }
    }
}

struct LockedFeatureOverlay: View {
    let feature: PremiumFeature
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 8) {
                    Text("Premium Feature")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(feature.displayName)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))

                    Text(feature.description)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button(action: onUnlock) {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text("Unlock Premium")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }
            .padding()
        }
    }
}

// MARK: - View Extension
extension View {
    func premiumGate(
        feature: PremiumFeature,
        premiumManager: PremiumManager,
        showPaywall: Binding<Bool>
    ) -> some View {
        modifier(PremiumFeatureGate(feature: feature, premiumManager: premiumManager, showPaywall: showPaywall))
    }
}

// MARK: - PRO Badge View
struct ProBadge: View {
    var size: BadgeSize = .small

    enum BadgeSize {
        case small, medium, large

        var fontSize: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            case .large: return .subheadline
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
            case .medium: return EdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 6)
            case .large: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            }
        }
    }

    var body: some View {
        Text("PRO")
            .font(size.fontSize)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(size.padding)
            .background(
                LinearGradient(
                    colors: [.orange, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .accessibilityLabel("Premium feature")
    }
}
