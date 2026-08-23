package com.kreativekoala.sketchly.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Mirrors the iOS SwiftData `DrawingSessionModel` (see
 * Sketchly/Sketchly/Sketchly/Models/Models.swift) — a saved practice drawing
 * plus whatever AI feedback notes were generated for it.
 */
@Entity(tableName = "drawing_sessions")
data class DrawingSessionEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0L,
    val lessonId: String? = null,
    /** PNG bytes of the exported canvas, written by the drawing screen on save. */
    val canvasImagePath: String,
    val feedbackNotes: String = "",
    val durationSeconds: Int = 0,
    val createdAt: Long = System.currentTimeMillis()
)
