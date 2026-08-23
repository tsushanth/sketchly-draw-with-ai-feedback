package com.kreativekoala.sketchly.ui.canvas

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Redo
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.Image
import androidx.hilt.navigation.compose.hiltViewModel

private val SwatchColors = listOf(
    Color.Black, Color.Red, Color(0xFFFF7A00), Color(0xFF2196F3), Color(0xFF4CAF50)
)

/**
 * Real freehand drawing canvas: touch-to-draw via Foundation's Canvas +
 * pointerInput/detectDragGestures — the standard, dependency-free approach
 * for a Compose drawing surface (no third-party drawing library needed).
 * Functionally replaces the iOS PencilKit canvas (DrawingCanvasView.swift).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CanvasScreen(
    onBack: () -> Unit,
    onRequestAiFeedback: (Long) -> Unit,
    viewModel: CanvasViewModel = hiltViewModel()
) {
    // Paywall gate intentionally removed for initial launch — AI feedback is free for all
    // users. PaywallScreen.kt is left in place, unused, for when billing is reintroduced.
    var canvasSize by remember { mutableStateOf(Offset.Zero) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Practice Canvas") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Close")
                    }
                },
                actions = {
                    IconButton(onClick = { viewModel.undo() }) {
                        Icon(Icons.AutoMirrored.Filled.Undo, contentDescription = "Undo")
                    }
                    IconButton(onClick = { viewModel.redo() }) {
                        Icon(Icons.AutoMirrored.Filled.Redo, contentDescription = "Redo")
                    }
                    IconButton(onClick = { viewModel.clear() }) {
                        Icon(Icons.Filled.Delete, contentDescription = "Clear")
                    }
                }
            )
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize()) {
            viewModel.backgroundBitmap.value?.let { bg ->
                Image(
                    bitmap = bg.asImageBitmap(),
                    contentDescription = null,
                    contentScale = ContentScale.FillBounds,
                    modifier = Modifier.fillMaxSize().align(Alignment.TopStart),
                )
            }
            Canvas(
                modifier = Modifier
                    .fillMaxSize()
                    .let { if (viewModel.backgroundBitmap.value == null) it.background(Color.White) else it }
                    .pointerInput(Unit) {
                        detectDragGestures(
                            onDragStart = { offset -> viewModel.startPath(offset) },
                            onDrag = { change, _ ->
                                change.consume()
                                viewModel.appendToCurrentPath(change.position)
                            }
                        )
                    }
                    .align(Alignment.TopStart)
                    .onGloballyPositioned { coords ->
                        canvasSize = Offset(coords.size.width.toFloat(), coords.size.height.toFloat())
                    }
            ) {
                viewModel.paths.value.forEach { path ->
                    if (path.points.size < 2) return@forEach
                    for (i in 0 until path.points.size - 1) {
                        drawLine(
                            color = path.color,
                            start = path.points[i],
                            end = path.points[i + 1],
                            strokeWidth = path.strokeWidthPx,
                            cap = androidx.compose.ui.graphics.StrokeCap.Round
                        )
                    }
                }
            }

            BottomToolbar(
                modifier = Modifier.align(Alignment.BottomCenter),
                onColorSelected = { viewModel.currentColor.value = it },
                onAiFeedback = {
                    viewModel.saveDrawing(
                        canvasSize.x.toInt(),
                        canvasSize.y.toInt()
                    ) { id -> onRequestAiFeedback(id) }
                }
            )
        }
    }
}

@Composable
private fun BottomToolbar(
    modifier: Modifier = Modifier,
    onColorSelected: (Color) -> Unit,
    onAiFeedback: () -> Unit
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SwatchColors.forEach { color ->
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .clip(CircleShape)
                        .background(color)
                        .clickable { onColorSelected(color) }
                )
            }
        }

        IconButton(onClick = onAiFeedback) {
            Icon(Icons.Filled.AutoAwesome, contentDescription = "AI Feedback")
        }
    }
}
