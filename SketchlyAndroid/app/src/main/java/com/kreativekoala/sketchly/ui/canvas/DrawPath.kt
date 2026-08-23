package com.kreativekoala.sketchly.ui.canvas

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color

/** One freehand stroke: the points the user dragged through, plus the tool state at the time. */
data class DrawPath(
    val points: List<Offset>,
    val color: Color,
    val strokeWidthPx: Float
)
