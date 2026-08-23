package com.kreativekoala.sketchly.data.remote

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

/**
 * Mirrors the JSON shape the iOS app asks Claude to return (see
 * Sketchly/Sketchly/Sketchly/Services/AIFeedbackService.swift, `parseFeedback`).
 * Kept identical field-for-field so a future shared backend response works
 * unmodified on both platforms.
 */
@JsonClass(generateAdapter = true)
data class AIDrawingFeedbackDto(
    val proportions: FeedbackItemDto,
    val shading: FeedbackItemDto,
    val lineWeight: FeedbackItemDto,
    val composition: FeedbackItemDto,
    val overallScore: Int,
    val encouragement: String,
    val topTip: String
) {
    @JsonClass(generateAdapter = true)
    data class FeedbackItemDto(
        val score: Int,
        val comment: String,
        val suggestions: List<String> = emptyList()
    )
}

@JsonClass(generateAdapter = true)
data class AnalyzeDrawingRequest(
    /** Base64-encoded JPEG of the exported canvas. */
    @Json(name = "image_base64") val imageBase64: String
)
