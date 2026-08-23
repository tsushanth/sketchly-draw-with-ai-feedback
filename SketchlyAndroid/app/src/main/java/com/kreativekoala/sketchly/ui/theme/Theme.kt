package com.kreativekoala.sketchly.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

// Sketchly brand accent: orange -> pink gradient (see PracticeView.swift AI Feedback CTA)
val SketchlyOrange = Color(0xFFFF7A00)
val SketchlyPink = Color(0xFFEC4899)

private val LightColors = lightColorScheme(
    primary = SketchlyOrange,
    secondary = SketchlyPink,
)

private val DarkColors = darkColorScheme(
    primary = SketchlyOrange,
    secondary = SketchlyPink,
)

@Composable
fun SketchlyTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = false, // keep brand colors consistent, matching iOS
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColors
        else -> LightColors
    }

    MaterialTheme(
        colorScheme = colorScheme,
        content = content
    )
}
