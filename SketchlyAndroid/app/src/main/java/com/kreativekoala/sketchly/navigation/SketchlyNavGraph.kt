package com.kreativekoala.sketchly.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.kreativekoala.sketchly.ui.aifeedback.AiFeedbackScreen
import com.kreativekoala.sketchly.ui.canvas.CanvasScreen
import com.kreativekoala.sketchly.ui.gallery.GalleryScreen

/**
 * Root nav graph. Screen set mirrors the iOS app's core loop (Gallery of past drawings ->
 * Practice/Canvas -> AI Feedback) — see Sketchly/Views/Gallery/GalleryView.swift,
 * Views/Practice/{PracticeView,DrawingCanvasView,AIFeedbackView}.swift.
 *
 * The Paywall screen (ui/paywall/PaywallScreen.kt, Screen.Paywall) is intentionally NOT wired
 * into this graph — billing is skipped for initial launch, so AI feedback and everything else
 * is free. The screen file is left in place, unused, for when billing is reintroduced.
 *
 * The iOS app also has a large lesson/curriculum/pixel-art surface (Views/Lessons,
 * Views/PixelArt, Views/Progress) that is NOT ported here — this scaffold covers the drawing +
 * AI critique core only, per the task scope.
 */
@Composable
fun SketchlyNavGraph(navController: NavHostController = rememberNavController()) {
    NavHost(navController = navController, startDestination = Screen.Gallery.route) {
        composable(Screen.Gallery.route) {
            GalleryScreen(
                onNewDrawing = { navController.navigate(Screen.Canvas.createRoute()) },
                onDrawingClick = { drawingId ->
                    navController.navigate(Screen.Canvas.createRoute(drawingId))
                }
            )
        }
        composable(
            route = Screen.Canvas.route,
            arguments = listOf(navArgument("drawingId") { type = NavType.LongType; defaultValue = -1L })
        ) {
            CanvasScreen(
                onBack = { navController.popBackStack() },
                onRequestAiFeedback = { drawingId ->
                    navController.navigate(Screen.AiFeedback.createRoute(drawingId))
                }
            )
        }
        composable(
            route = Screen.AiFeedback.route,
            arguments = listOf(navArgument("drawingId") { type = NavType.LongType })
        ) { backStackEntry ->
            val drawingId = backStackEntry.arguments?.getLong("drawingId") ?: return@composable
            AiFeedbackScreen(
                drawingId = drawingId,
                onDone = { navController.popBackStack() }
            )
        }
    }
}
