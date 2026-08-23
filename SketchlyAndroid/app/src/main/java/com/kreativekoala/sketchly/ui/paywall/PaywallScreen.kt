package com.kreativekoala.sketchly.ui.paywall

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.kreativekoala.paywallkit.models.PaywallFeature
import com.kreativekoala.paywallkit.models.PaywallProduct
import com.kreativekoala.paywallkit.models.PaywallTheme
import com.kreativekoala.paywallkit.view.PaywallView

/**
 * Subscription paywall, reusing the shared PaywallKit-Android module (see
 * ~/Documents/GitHub/PaywallKit-Android/) rather than building new paywall UI
 * — matches the RiddleVerse/ScribeAI/etc. usage pattern.
 *
 * Mirrors the iOS PaywallView.swift gating (AI feedback + gallery share are
 * premium-only — see Views/Practice/PracticeView.swift).
 *
 * TODO(billing): NOT wired to RevenueCat or Play Billing yet, per task scope.
 * [products] below are placeholders standing in for real store products;
 * [onPurchase]/[onRestore] are no-ops. Before shipping:
 *   1. Register a RevenueCat project for Sketchly Android (see MEMORY.md
 *      "RevenueCat Project IDs" for the pattern used by sibling apps) and
 *      wire real product ids matching the iOS SKUs:
 *      com.kreativekoala.sketchly.subscription.{weekly,monthly,yearly,lifetime}
 *      (see SketchlyApp.swift `productIds`).
 *   2. Replace the placeholder `products` list with real Play Billing /
 *      RevenueCat offerings.
 */
@Composable
fun PaywallScreen(
    placement: String,
    onDismiss: () -> Unit
) {
    val products = listOf(
        PaywallProduct(
            id = "com.kreativekoala.sketchly.subscription.weekly",
            localizedPrice = "$4.99",
            price = 4.99,
            currencyCode = "USD",
            trialDays = 3,
            period = PaywallProduct.Period.WEEKLY
        ),
        PaywallProduct(
            id = "com.kreativekoala.sketchly.subscription.yearly",
            localizedPrice = "$39.99",
            price = 39.99,
            currencyCode = "USD",
            trialDays = null,
            period = PaywallProduct.Period.YEARLY
        )
    )

    PaywallView(
        appId = "sketchly",
        placement = placement,
        appName = "Sketchly",
        features = listOf(
            PaywallFeature("🧠", "AI Drawing Feedback", "Get expert critique on every drawing"),
            PaywallFeature("📚", "All Lessons", "Unlock the full lesson library"),
            PaywallFeature("🖼️", "Share to Gallery", "Post your art to the community"),
            PaywallFeature("✨", "No Limits", "Unlimited practice sessions")
        ),
        products = products,
        theme = PaywallTheme(accent = Color(0xFFFF7A00), accent2 = Color(0xFFEC4899)),
        showWinback = false,
        isDismissible = true,
        onPurchase = { /* TODO(billing): wire RevenueCat/Play Billing purchase flow */ },
        onRestore = { /* TODO(billing): wire RevenueCat restore */ },
        onRedeemCode = { /* TODO(billing): wire Play promo code redemption */ },
        onDismiss = onDismiss
    )
}
