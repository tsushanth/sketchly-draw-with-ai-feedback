package com.kreativekoala.sketchly.ai

import com.kreativekoala.sketchly.data.remote.AIDrawingFeedbackDto

/**
 * Deterministic, hand-written feedback text keyed off DrawingMetrics'
 * measured score buckets. Added after two on-device model attempts
 * (SmolVLM2, then Moondream2) both produced comment/suggestion text
 * that was repetitive, boilerplate, or self-contradictory even once
 * scores were grounded in real pixel data — the VLM's language output
 * just isn't reliable enough for this. Templates guarantee every
 * field is coherent and specific to its own topic, at the cost of
 * being less "personalized" than free-generated text would ideally be.
 *
 * Each category has one comment + one suggestion per score bucket
 * (low 1-3 / mid 4-6 / high 7-10) — picked deterministically by score
 * so the same drawing always gets the same feedback, not a random
 * variant.
 */
object FeedbackTemplates {

    private fun bucket(score: Int): Int = when {
        score <= 3 -> 0
        score <= 6 -> 1
        else -> 2
    }

    private val shading = arrayOf(
        "This sketch is mostly flat lines with little to no shading." to
            "Try adding a darker layer of strokes where shadows would naturally fall.",
        "There's a bit of tonal variation, but the shading is inconsistent." to
            "Build up shading gradually in light layers rather than one flat pass.",
        "Nice use of tonal variation — the shading gives it real depth." to
            "Push the darkest shadow areas even darker for stronger contrast.",
    )

    private val lineWeight = arrayOf(
        "The stroke width varies a lot across the drawing, which makes the lines feel shaky." to
            "Slow down and draw with steady, deliberate strokes to keep the line width even.",
        "Line weight is mostly steady, with a few inconsistent spots." to
            "Watch your hand speed at the start and end of each stroke — that's often where thickness shifts.",
        "Confident, consistent line weight throughout the sketch." to
            "Try varying line weight on purpose — thicker outlines, thinner details — for more visual interest.",
    )

    private val composition = arrayOf(
        "The drawing is off-center or only uses a small part of the canvas." to
            "Try sketching bigger and centering the subject before adding detail.",
        "Decent use of the canvas, though the sizing or centering could be tightened up." to
            "Step back and check how the empty space is balanced around your subject.",
        "Well-balanced use of the canvas — the subject is nicely sized and centered." to
            "Experiment with an off-center composition using the rule of thirds for variety.",
    )

    private val proportions = arrayOf(
        "The overall shape looks stretched or uneven." to
            "Lightly sketch a bounding box first to keep proportions in check before adding detail.",
        "Proportions are roughly right but could be tightened up." to
            "Compare the width and height of your shape against each other before finalizing the lines.",
        "Proportions look well-balanced." to
            "Try sketching the same subject from a different angle to put your proportion skills to the test.",
    )

    private val encouragementByAvg = arrayOf(
        "Every artist starts with rough sketches — the important part is that you're practicing!",
        "Solid practice sketch — you're building real skills here.",
        "Great work — this sketch shows real control and care.",
    )

    fun build(metrics: DrawingMetrics): AIDrawingFeedbackDto {
        fun item(score: Int, table: Array<Pair<String, String>>): AIDrawingFeedbackDto.FeedbackItemDto {
            val (comment, suggestion) = table[bucket(score)]
            return AIDrawingFeedbackDto.FeedbackItemDto(
                score = score,
                comment = comment,
                suggestions = listOf(suggestion),
            )
        }

        val proportionsItem = item(metrics.proportionsScore, proportions)
        val shadingItem = item(metrics.shadingScore, shading)
        val lineWeightItem = item(metrics.lineWeightScore, lineWeight)
        val compositionItem = item(metrics.compositionScore, composition)

        val overall = ((metrics.proportionsScore + metrics.shadingScore + metrics.lineWeightScore + metrics.compositionScore) * 10 / 4)
            .coerceIn(1, 100)

        // Top tip ties to whichever category scored lowest — the most
        // useful single thing to work on next, not a generic aside.
        val lowest = listOf(
            metrics.proportionsScore to proportionsItem,
            metrics.shadingScore to shadingItem,
            metrics.lineWeightScore to lineWeightItem,
            metrics.compositionScore to compositionItem,
        ).minByOrNull { it.first }!!.second

        return AIDrawingFeedbackDto(
            proportions = proportionsItem,
            shading = shadingItem,
            lineWeight = lineWeightItem,
            composition = compositionItem,
            overallScore = overall,
            encouragement = encouragementByAvg[bucket(overall / 10)],
            topTip = lowest.suggestions.first(),
        )
    }
}
