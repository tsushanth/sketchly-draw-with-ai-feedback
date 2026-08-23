package com.kreativekoala.sketchly.ai

import android.graphics.Bitmap
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Objective, pixel-level signals computed directly from the drawing
 * bitmap — not from the vision-language model. Added after on-device
 * testing showed SmolVLM2-500M reliably hallucinates positive
 * qualities ("well-done shading", "smooth even lines") on a bare
 * black-outline sketch with none of those qualities present: a 500M
 * model's visual grounding isn't reliable enough to trust for scoring,
 * even with a tuned prompt and grammar. These heuristics can't judge
 * artistic quality, but they CAN reliably detect "is there tonal
 * variation at all" and "is the stroke width consistent" — which is
 * enough to catch the specific hallucination pattern seen on-device.
 */
data class DrawingMetrics(
    val shadingScore: Int,
    val compositionScore: Int,
    val proportionsScore: Int,
    val lineWeightScore: Int,
    val promptSummary: String,
)

object DrawingAnalyzer {

    private const val SAMPLE_SIZE = 160
    // A pixel counts as "ink" if it's darker than near-white — the
    // canvas background is white regardless of which of the 5 palette
    // colors was used to draw.
    private const val INK_THRESHOLD = 235
    // Well below INK_THRESHOLD — excludes anti-aliased edge fringe so
    // shading variance reflects the stroke's actual fill color(s), not
    // blending artifacts at its boundary.
    private const val SOLID_INK_THRESHOLD = 120

    fun analyze(source: Bitmap): DrawingMetrics {
        val bmp = Bitmap.createScaledBitmap(source, SAMPLE_SIZE, SAMPLE_SIZE, true)
        val w = bmp.width
        val h = bmp.height
        val pixels = IntArray(w * h)
        bmp.getPixels(pixels, 0, w, 0, 0, w, h)

        val inkMask = BooleanArray(w * h)
        // Shading variance is measured ONLY over "solid" ink pixels well
        // below background — a much stricter cutoff than INK_THRESHOLD.
        // Anti-aliased edge fringe pixels span a wide gray range purely
        // from blending with the white background, which inflated
        // measured variance and made a flat single-color outline read as
        // "high shading" (confirmed on-device: shadingScore=10 for a
        // plain black-line triangle before this fix).
        val solidLuminances = ArrayList<Int>()
        var minX = w; var maxX = -1; var minY = h; var maxY = -1

        for (y in 0 until h) {
            for (x in 0 until w) {
                val p = pixels[y * w + x]
                val r = (p shr 16) and 0xFF
                val g = (p shr 8) and 0xFF
                val b = p and 0xFF
                val minChannel = min(r, min(g, b))
                val isInk = minChannel < INK_THRESHOLD
                if (isInk) {
                    inkMask[y * w + x] = true
                    if (x < minX) minX = x
                    if (x > maxX) maxX = x
                    if (y < minY) minY = y
                    if (y > maxY) maxY = y
                    if (minChannel < SOLID_INK_THRESHOLD) {
                        solidLuminances.add((0.299 * r + 0.587 * g + 0.114 * b).roundToInt())
                    }
                }
            }
        }
        val totalInkPixels = inkMask.count { it }
        if (totalInkPixels < 20 || maxX < 0) {
            // Essentially blank canvas — nothing to measure honestly.
            return DrawingMetrics(
                shadingScore = 1, compositionScore = 1, proportionsScore = 1, lineWeightScore = 1,
                promptSummary = "The canvas is almost empty — barely any strokes were drawn.",
            )
        }

        // --- Shading: population stddev of luminance among SOLID ink
        // pixels only. A flat single-color outline has near-zero
        // variance; real shading/tonal blending has meaningfully more.
        // A thin stroke may have too few solid-core pixels to measure
        // confidently — default to "no shading detected" rather than
        // guessing, since that's the far more common case for a thin line.
        val shadingScore = if (solidLuminances.size < 15) {
            2
        } else {
            val mean = solidLuminances.average()
            val variance = solidLuminances.sumOf { (it - mean) * (it - mean) } / solidLuminances.size
            val stddev = sqrt(variance)
            when {
                stddev < 8 -> 1 + (stddev / 8 * 2).roundToInt()       // 1-3: flat outline, no shading
                stddev < 25 -> 3 + ((stddev - 8) / 17 * 3).roundToInt() // 3-6: some tonal variation
                else -> min(10, 6 + ((stddev - 25) / 20 * 4).roundToInt()) // 6-10: real shading
            }.coerceIn(1, 10)
        }

        // --- Composition: how centered the ink bounding box is, plus
        // whether it uses a reasonable portion of the canvas (not a
        // tiny mark in the corner, not overflowing every edge).
        val bboxW = (maxX - minX + 1).toDouble()
        val bboxH = (maxY - minY + 1).toDouble()
        val bboxCenterX = minX + bboxW / 2
        val bboxCenterY = minY + bboxH / 2
        val canvasCenterX = w / 2.0
        val canvasCenterY = h / 2.0
        val centerOffset = hypot(bboxCenterX - canvasCenterX, bboxCenterY - canvasCenterY)
        val maxOffset = hypot(canvasCenterX, canvasCenterY)
        val centering = 1.0 - (centerOffset / maxOffset).coerceIn(0.0, 1.0)

        val fillFraction = (bboxW * bboxH) / (w.toDouble() * h.toDouble())
        // Ideal is roughly 15%-70% of the canvas used by the bounding
        // box — too little reads as a tiny/timid sketch, too much as
        // cramped/overflowing.
        val fillScore = when {
            fillFraction < 0.05 -> 0.2
            fillFraction < 0.15 -> 0.6
            fillFraction <= 0.70 -> 1.0
            fillFraction <= 0.90 -> 0.6
            else -> 0.3
        }
        val compositionScore = (1 + (centering * 0.6 + fillScore * 0.4) * 9).roundToInt().coerceIn(1, 10)

        // --- Proportions: without a reference shape this can't verify
        // "correctness", only whether the drawing's bounding box is a
        // reasonably balanced shape rather than an extreme sliver —
        // an honest, limited proxy, not a full proportion check.
        val aspect = bboxW / bboxH
        val aspectBalance = 1.0 - (abs(1.0 - min(aspect, 1 / aspect)) ).coerceIn(0.0, 1.0)
        val proportionsScore = (1 + aspectBalance * 9).roundToInt().coerceIn(1, 10)

        // --- Line weight: consistency of stroke thickness, sampled by
        // scanning ink-run lengths across rows and columns of the
        // bounding box. Confident, controlled lines have low run-length
        // variance; shaky/inconsistent lines have high variance. This
        // is a real signal but a rough one — diagonal strokes read
        // thicker than they are under axis-aligned scanning.
        val runLengths = ArrayList<Int>()
        for (y in minY..maxY) {
            var run = 0
            for (x in minX..maxX) {
                if (inkMask[y * w + x]) {
                    run++
                } else if (run > 0) {
                    if (run in 1..20) runLengths.add(run)
                    run = 0
                }
            }
            if (run in 1..20) runLengths.add(run)
        }
        for (x in minX..maxX) {
            var run = 0
            for (y in minY..maxY) {
                if (inkMask[y * w + x]) {
                    run++
                } else if (run > 0) {
                    if (run in 1..20) runLengths.add(run)
                    run = 0
                }
            }
            if (run in 1..20) runLengths.add(run)
        }
        val lineWeightScore = if (runLengths.size < 5) {
            5
        } else {
            val rMean = runLengths.average()
            val rVariance = runLengths.sumOf { (it - rMean) * (it - rMean) } / runLengths.size
            val rStddev = sqrt(rVariance)
            val consistency = (1.0 - (rStddev / max(rMean, 1.0)).coerceIn(0.0, 1.0))
            (1 + consistency * 9).roundToInt().coerceIn(1, 10)
        }

        val summary = "Measured from the actual pixels (not a judgment call): " +
            "tonal variation in the ink is ${describeLevel(shadingScore)} (${shadingScore}/10), " +
            "the drawing uses ${(fillFraction * 100).roundToInt()}% of the canvas and is " +
            "${if (centering > 0.7) "well-centered" else "off-center"}, " +
            "stroke width consistency is ${describeLevel(lineWeightScore)} (${lineWeightScore}/10)."

        return DrawingMetrics(
            shadingScore = shadingScore,
            compositionScore = compositionScore,
            proportionsScore = proportionsScore,
            lineWeightScore = lineWeightScore,
            promptSummary = summary,
        )
    }

    private fun describeLevel(score: Int): String = when {
        score <= 3 -> "low"
        score <= 6 -> "moderate"
        else -> "high"
    }
}
