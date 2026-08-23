package com.kreativekoala.sketchly.ui.canvas

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas as AndroidCanvas
import android.graphics.Paint
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kreativekoala.sketchly.data.local.DrawingSessionDao
import com.kreativekoala.sketchly.data.local.DrawingSessionEntity
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileOutputStream
import javax.inject.Inject

/**
 * Drives the freehand drawing canvas. Mirrors the toolbar actions in the iOS
 * PracticeView (undo/redo/erase/clear/save) — see
 * Sketchly/Sketchly/Sketchly/Views/Practice/PracticeView.swift — but instead
 * of wrapping PencilKit, this draws directly with Compose's Canvas +
 * pointerInput gesture detection (see CanvasScreen.kt), which is the
 * standard, dependency-free approach for a Compose freehand canvas.
 *
 * Reopening an existing drawing (see [loadExistingDrawing]) does NOT
 * restore individual undo-able strokes — only the flattened PNG is
 * ever persisted, not vector path data. It loads that PNG as a fixed
 * background layer; new strokes draw on top of it and get composited
 * in on save. This is a deliberate, scoped tradeoff (not a bug) — full
 * stroke-level persistence would need a DB schema change.
 */
@HiltViewModel
class CanvasViewModel @Inject constructor(
    @ApplicationContext private val appContext: Context,
    private val dao: DrawingSessionDao,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    val paths = mutableStateOf<List<DrawPath>>(emptyList())
    val currentColor = mutableStateOf(Color.Black)
    val currentStrokeWidth = mutableStateOf(8f)
    private val redoStack = mutableListOf<DrawPath>()

    /** Existing drawing being continued, or null for a brand-new one. */
    private var editingDrawingId: Long? = null
    val backgroundBitmap = mutableStateOf<Bitmap?>(null)

    init {
        val id: Long = savedStateHandle["drawingId"] ?: -1L
        if (id >= 0L) loadExistingDrawing(id)
    }

    private fun loadExistingDrawing(id: Long) {
        viewModelScope.launch {
            val session = dao.getById(id) ?: return@launch
            editingDrawingId = id
            backgroundBitmap.value = BitmapFactory.decodeFile(session.canvasImagePath)
        }
    }

    fun startPath(point: Offset) {
        val newPath = DrawPath(listOf(point), currentColor.value, currentStrokeWidth.value)
        paths.value = paths.value + newPath
        redoStack.clear()
    }

    fun appendToCurrentPath(point: Offset) {
        val current = paths.value
        if (current.isEmpty()) return
        val last = current.last()
        val updated = last.copy(points = last.points + point)
        paths.value = current.dropLast(1) + updated
    }

    fun undo() {
        val current = paths.value
        if (current.isEmpty()) return
        redoStack.add(current.last())
        paths.value = current.dropLast(1)
    }

    fun redo() {
        val last = redoStack.removeLastOrNull() ?: return
        paths.value = paths.value + last
    }

    fun clear() {
        paths.value = emptyList()
        redoStack.clear()
    }

    /**
     * Rasterizes the current strokes (composited over [backgroundBitmap] if
     * continuing an existing drawing) to a PNG on disk. Reuses the same
     * [DrawingSessionEntity] row (same id, same file path) when continuing
     * an existing drawing — Room's REPLACE conflict strategy makes
     * dao.insert() with a matching id act as an update — or inserts a new
     * row for a brand-new drawing. Returns the row's id so the caller can
     * navigate straight to the AI feedback screen.
     */
    fun saveDrawing(widthPx: Int, heightPx: Int, onSaved: (Long) -> Unit) {
        viewModelScope.launch {
            val bitmap = renderBitmap(widthPx, heightPx)
            val existingId = editingDrawingId
            val file = if (existingId != null) {
                File(dao.getById(existingId)?.canvasImagePath ?: newDrawingFilePath())
            } else {
                File(newDrawingFilePath())
            }
            FileOutputStream(file).use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }
            val id = dao.insert(
                DrawingSessionEntity(
                    id = existingId ?: 0L,
                    canvasImagePath = file.absolutePath,
                    durationSeconds = 0
                )
            )
            onSaved(if (existingId != null) existingId else id)
        }
    }

    private fun newDrawingFilePath(): String =
        File(appContext.filesDir, "drawing_${System.currentTimeMillis()}.png").absolutePath

    private fun renderBitmap(widthPx: Int, heightPx: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(
            widthPx.coerceAtLeast(1),
            heightPx.coerceAtLeast(1),
            Bitmap.Config.ARGB_8888
        )
        val canvas = AndroidCanvas(bitmap)
        canvas.drawColor(android.graphics.Color.WHITE)
        backgroundBitmap.value?.let { bg ->
            val srcRect = android.graphics.Rect(0, 0, bg.width, bg.height)
            val dstRect = android.graphics.Rect(0, 0, bitmap.width, bitmap.height)
            canvas.drawBitmap(bg, srcRect, dstRect, null)
        }
        val paint = Paint().apply {
            isAntiAlias = true
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        paths.value.forEach { path ->
            paint.color = path.color.toArgb()
            paint.strokeWidth = path.strokeWidthPx
            for (i in 0 until path.points.size - 1) {
                val a = path.points[i]
                val b = path.points[i + 1]
                canvas.drawLine(a.x, a.y, b.x, b.y, paint)
            }
        }
        return bitmap
    }
}
