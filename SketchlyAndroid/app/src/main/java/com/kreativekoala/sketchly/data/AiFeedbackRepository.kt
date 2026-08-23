package com.kreativekoala.sketchly.data

import android.graphics.Bitmap
import com.kreativekoala.sketchly.ai.OnDeviceFeedbackEngine
import com.kreativekoala.sketchly.data.remote.AIDrawingFeedbackDto
import javax.inject.Inject

/**
 * AI Feedback runs fully on-device via [OnDeviceFeedbackEngine] — pixel
 * analysis plus deterministic templates, no VLM model, no network
 * call. No shared client-embedded proxy secret either — the iOS app's
 * extension-proxy.fly.dev pattern (a single hardcoded token shared
 * across every install, see CLAUDE.md "LLM API keys") is NOT
 * replicated here; Android's AI Feedback has no cloud dependency and
 * no model-download dependency at all.
 */
class AiFeedbackRepository @Inject constructor(
    private val engine: OnDeviceFeedbackEngine,
) {
    fun analyzeDrawing(bitmap: Bitmap): AIDrawingFeedbackDto = engine.analyzeDrawing(bitmap)
}
