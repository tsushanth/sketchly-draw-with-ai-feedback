//
//  PaywallView.swift
//  Sketchly
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PremiumManager.self) private var premiumManager
    @State private var selectedProduct: Product?
    @State private var isPurchasing: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isRestoring: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    headerSection

                    // Features list
                    featuresSection

                    // Products
                    productsSection

                    // CTA
                    ctaSection

                    // Footer
                    footerSection
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                        premiumManager.recordPaywallDismissed()
                        AnalyticsService.shared.track(.paywallDismissed)
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            premiumManager.recordPaywallShown()
            AnalyticsService.shared.track(.paywallViewed(trigger: "paywall_view"))

            // Select best value by default
            if selectedProduct == nil {
                selectedProduct = premiumManager.subscriptions.first { $0.isPopular }
                    ?? premiumManager.subscriptions.first
            }
        }
        .alert("Purchase Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onChange(of: premiumManager.isPremium) { _, isPremium in
            if isPremium { dismiss() }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        ZStack {
            LinearGradient(
                colors: [.orange.opacity(0.15), .pink.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange.opacity(0.3), .pink.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 8) {
                    Text("Sketchly Premium")
                        .font(.largeTitle)
                        .fontWeight(.black)

                    Text("Unlock your full creative potential with AI-powered drawing critique and structured learning")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.vertical, 40)
        }
    }

    // MARK: - Features
    private var featuresSection: some View {
        VStack(spacing: 12) {
            Text("Everything in Premium")
                .font(.headline)
                .padding(.top)

            VStack(spacing: 10) {
                ForEach(PremiumFeature.premiumFeatures) { feature in
                    HStack(spacing: 14) {
                        Image(systemName: feature.icon)
                            .font(.body)
                            .foregroundStyle(
                                LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(feature.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal)
                }
            }

            Divider()
                .padding()
        }
    }

    // MARK: - Products
    private var productsSection: some View {
        VStack(spacing: 12) {
            Text("Choose Your Plan")
                .font(.headline)

            if premiumManager.isLoading {
                ProgressView()
                    .padding()
            } else if premiumManager.allProducts.isEmpty {
                VStack(spacing: 8) {
                    Text("Loading products...")
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        Task { await premiumManager.loadProducts() }
                    }
                }
                .padding()
            } else {
                VStack(spacing: 10) {
                    ForEach(premiumManager.subscriptions) { product in
                        ProductRow(
                            product: product,
                            isSelected: selectedProduct?.id == product.id
                        ) {
                            selectedProduct = product
                            HapticManager.selection()
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - CTA
    private var ctaSection: some View {
        VStack(spacing: 12) {
            Button(action: purchaseSelected) {
                Group {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HStack {
                            Image(systemName: "crown.fill")
                            Text(selectedProduct != nil ? "Continue with \(selectedProduct!.displayPrice)" : "Select a Plan")
                        }
                        .font(.headline)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: selectedProduct != nil ? [.orange, .pink] : [.gray.opacity(0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .disabled(selectedProduct == nil || isPurchasing)
            .padding(.horizontal)

            Button("Restore Purchases") {
                Task { await restorePurchases() }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .disabled(isRestoring)
        }
        .padding(.top, 8)
    }

    // MARK: - Footer
    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("Cancel anytime in App Store settings. Prices may vary by region.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Privacy Policy", destination: URL(string: "https://appfactory.dev/privacy")!)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Link("Terms of Use", destination: URL(string: "https://appfactory.dev/terms")!)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func purchaseSelected() {
        guard let product = selectedProduct else { return }

        isPurchasing = true
        HapticManager.impact(style: .medium)

        Task {
            do {
                try await premiumManager.purchase(product)
                AnalyticsService.shared.track(.subscriptionPurchased(
                    productId: product.id,
                    price: Double(truncating: product.price as NSDecimalNumber)
                ))
                HapticManager.notification(type: .success)
                dismiss()
            } catch StoreKitError.userCancelled {
                // User cancelled, no error shown
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                HapticManager.notification(type: .error)
            }
            isPurchasing = false
        }
    }

    private func restorePurchases() async {
        isRestoring = true
        await premiumManager.restorePurchases()
        isRestoring = false
        AnalyticsService.shared.track(.subscriptionRestored)

        if premiumManager.isPremium {
            dismiss()
        }
    }
}

// MARK: - Product Row
struct ProductRow: View {
    let product: Product
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Selection circle
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.orange : Color(.systemGray4), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: 14, height: 14)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(product.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        if let savingsLabel = product.savingsLabel {
                            Text(savingsLabel)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }

                        if product.isPopular {
                            Text("POPULAR")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(4)
                        }
                    }

                    if let introOffer = product.subscription?.introductoryOffer {
                        Text("Free trial available")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .orange : .primary)

                    if let period = product.periodLabel.isEmpty ? nil : product.periodLabel {
                        Text(period)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange.opacity(0.08) : Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 1.5)
                    )
            )
        }
    }
}
