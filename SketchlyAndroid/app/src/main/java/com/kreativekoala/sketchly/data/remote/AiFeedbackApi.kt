package com.kreativekoala.sketchly.data.remote

import retrofit2.http.Body
import retrofit2.http.POST

/**
 * TODO: not wired to a real backend. The iOS app calls a proxy at
 * https://extension-proxy.fly.dev/anthropic/messages with a hardcoded proxy token (see
 * AIFeedbackService.swift) — do NOT replicate that pattern here. Per this portfolio's rule,
 * paid LLM API keys must never live in client-side code (see CLAUDE.md "LLM API keys" /
 * feedback_no_client_side_llm_keys.md). Point BASE_URL at a server-side proxy endpoint that
 * accepts the drawing image and returns [AIDrawingFeedbackDto], and put any auth token behind
 * that proxy, not in this app.
 */
interface AiFeedbackApi {
    @POST("v1/sketchly/analyze") // TODO: replace with real endpoint path once a backend exists
    suspend fun analyzeDrawing(@Body request: AnalyzeDrawingRequest): AIDrawingFeedbackDto
}
