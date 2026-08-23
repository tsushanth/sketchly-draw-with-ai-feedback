package com.kreativekoala.sketchly.ai

import android.graphics.Bitmap
import com.kreativekoala.sketchly.data.remote.AIDrawingFeedbackDto
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Turns a drawing bitmap into [AIDrawingFeedbackDto] using pixel-level
 * analysis ([DrawingAnalyzer]) plus deterministic text templates
 * ([FeedbackTemplates]) — no on-device VLM inference.
 *
 * This used to run a real llama.cpp + mtmd SmolVLM2/Moondream2 model
 * (see git history / sketchly_ai_jni.cpp, still present but unused).
 * That path was cut after on-device testing across two models showed
 * neither the scores nor the comment text it produced were reliable —
 * hallucinated positive qualities ("well-done shading" on a bare
 * outline), repetitive boilerplate, self-contradiction — even after
 * heavy prompt/grammar tuning. Once scores were overridden with
 * measured pixel metrics and comments were templated from those same
 * metrics, the model's output was 100% unused, so running ~25-35s of
 * inference for a discarded result made no sense. This is faster
 * (sub-100ms vs ~25-35s), needs no ~640MB model download, and is
 * fully deterministic — the tradeoff is template text instead of
 * free-generated prose.
 */
@Singleton
class OnDeviceFeedbackEngine @Inject constructor() {
    fun analyzeDrawing(bitmap: Bitmap): AIDrawingFeedbackDto {
        val metrics = DrawingAnalyzer.analyze(bitmap)
        return FeedbackTemplates.build(metrics)
    }
}
