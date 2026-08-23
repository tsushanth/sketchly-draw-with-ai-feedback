package com.kreativekoala.sketchly.navigation

sealed class Screen(val route: String) {
    data object Gallery : Screen("gallery")
    data object Canvas : Screen("canvas?drawingId={drawingId}") {
        // -1L sentinel means "new drawing" — NavType.LongType has no
        // nullable variant, so a real id is distinguished by being >= 0.
        fun createRoute(drawingId: Long? = null) = "canvas?drawingId=${drawingId ?: -1L}"
    }
    data object AiFeedback : Screen("ai_feedback/{drawingId}") {
        fun createRoute(drawingId: Long) = "ai_feedback/$drawingId"
    }
    data object Paywall : Screen("paywall/{placement}") {
        fun createRoute(placement: String) = "paywall/$placement"
    }
}
