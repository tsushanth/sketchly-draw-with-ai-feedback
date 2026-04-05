//
//  PaywallView.swift
//  Sketchly
//
//  Uses PaywallKit for A/B tested paywall templates.
//

import SwiftUI
import StoreKit
import PaywallKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PremiumManager.self) private var premiumManager

    var body: some View {
        Group {
            if premiumManager.isLoading || premiumManager.allProducts.isEmpty {
                loadingView
            } else {
                PaywallKit.PaywallView(
                    appId: "sketchly",
                    appName: "Sketchly",
                    features: PremiumFeature.premiumFeatures.map { feature in
                        PaywallFeature(
                            icon: feature.icon,
                            title: feature.displayName,
                            description: feature.description
                        )
                    },
                    products: premiumManager.allProducts.map { product in
                        mapProduct(product)
                    },
                    theme: PaywallTheme(
                        accent: .orange,
                        accent2: .pink
                    ),
                    showWinback: true,
                    isDismissible: true,
                    onPurchase: { productId in
                        if let product = premiumManager.allProducts.first(where: { $0.id == productId }) {
                            try? await premiumManager.purchase(product)
                            AnalyticsService.shared.track(.subscriptionPurchased(
                                productId: product.id,
                                price: Double(truncating: product.price as NSDecimalNumber)
                            ))
                        }
                    },
                    onRestore: {
                        await premiumManager.restorePurchases()
                        AnalyticsService.shared.track(.subscriptionRestored)
                    },
                    onDismiss: {
                        premiumManager.recordPaywallDismissed()
                        AnalyticsService.shared.track(.paywallDismissed)
                        dismiss()
                    }
                )
            }
        }
        .onAppear {
            premiumManager.recordPaywallShown()
            AnalyticsService.shared.track(.paywallViewed(trigger: "paywall_view"))
            if premiumManager.allProducts.isEmpty {
                Task { await premiumManager.loadProducts() }
            }
        }
        .onChange(of: premiumManager.isPremium) { _, isPremium in
            if isPremium { dismiss() }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func mapProduct(_ product: Product) -> PaywallProduct {
        let period: PaywallProduct.Period
        if product.id.contains("weekly") {
            period = .weekly
        } else if product.id.contains("monthly") {
            period = .monthly
        } else if product.id.contains("yearly") {
            period = .yearly
        } else {
            period = .lifetime
        }

        let trialDays: Int?
        if let intro = product.subscription?.introductoryOffer,
           intro.paymentMode == .freeTrial {
            trialDays = intro.period.value * (intro.period.unit == .day ? 1 : intro.period.unit == .week ? 7 : 30)
        } else {
            trialDays = nil
        }

        return PaywallProduct(
            id: product.id,
            localizedPrice: product.displayPrice,
            price: product.price,
            currencyCode: product.priceFormatStyle.locale.currency?.identifier ?? "USD",
            trialDays: trialDays,
            period: period
        )
    }
}
