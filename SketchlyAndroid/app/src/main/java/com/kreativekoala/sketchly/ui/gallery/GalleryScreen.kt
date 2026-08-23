package com.kreativekoala.sketchly.ui.gallery

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Brush
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import com.kreativekoala.sketchly.data.local.DrawingSessionEntity

/**
 * Root/home screen — a grid of past practice drawings, mirroring the iOS
 * app's Gallery tab (Views/Gallery/GalleryView.swift), scoped down to the
 * user's own local drawings (the iOS community-feed aspect is out of scope
 * for this scaffold).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GalleryScreen(
    onNewDrawing: () -> Unit,
    onDrawingClick: (Long) -> Unit,
    viewModel: GalleryViewModel = hiltViewModel()
) {
    val sessions by viewModel.sessions.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Sketchly") })
        },
        floatingActionButton = {
            FloatingActionButton(onClick = onNewDrawing) {
                Icon(Icons.Filled.Add, contentDescription = "New drawing")
            }
        }
    ) { padding ->
        if (sessions.isEmpty()) {
            EmptyGallery(modifier = Modifier.padding(padding).fillMaxSize(), onNewDrawing = onNewDrawing)
        } else {
            LazyVerticalGrid(
                columns = GridCells.Fixed(2),
                modifier = Modifier.padding(padding).fillMaxSize(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(12.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(sessions, key = { it.id }) { session ->
                    DrawingThumbnail(session = session, onClick = { onDrawingClick(session.id) })
                }
            }
        }
    }
}

@Composable
private fun EmptyGallery(modifier: Modifier = Modifier, onNewDrawing: () -> Unit) {
    Column(
        modifier = modifier.clickable(onClick = onNewDrawing),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            Icons.Filled.Brush,
            contentDescription = null,
            modifier = Modifier.padding(bottom = 16.dp)
        )
        Text("No drawings yet", style = MaterialTheme.typography.titleMedium)
        Text(
            "Tap + to start your first practice drawing",
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 4.dp, start = 32.dp, end = 32.dp)
        )
    }
}

@Composable
private fun DrawingThumbnail(session: DrawingSessionEntity, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(1f)
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .clickable(onClick = onClick)
    ) {
        AsyncImage(
            model = session.canvasImagePath,
            contentDescription = "Drawing",
            modifier = Modifier.fillMaxSize()
        )
    }
}
