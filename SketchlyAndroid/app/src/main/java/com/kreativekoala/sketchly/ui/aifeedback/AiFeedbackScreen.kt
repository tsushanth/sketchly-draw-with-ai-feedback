package com.kreativekoala.sketchly.ui.aifeedback

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.kreativekoala.sketchly.data.remote.AIDrawingFeedbackDto

/**
 * Displays AI critique for a saved drawing — mirrors the score
 * breakdown in the iOS Views/Practice/AIFeedbackView.swift (proportions,
 * shading, line weight, composition, overall score, encouragement, top tip).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AiFeedbackScreen(
    drawingId: Long,
    onDone: () -> Unit,
    viewModel: AiFeedbackViewModel = hiltViewModel()
) {
    val state by viewModel.uiState.collectAsState()

    Scaffold(
        topBar = { TopAppBar(title = { Text("AI Feedback") }) }
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize()) {
            when (val s = state) {
                is AiFeedbackUiState.Loading -> LoadingState()
                is AiFeedbackUiState.Error -> ErrorState(s.message, onRetry = { viewModel.requestFeedback() })
                is AiFeedbackUiState.Loaded -> FeedbackContent(s.feedback, onDone)
            }
        }
    }
}

@Composable
private fun LoadingState() {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        CircularProgressIndicator()
        Text("Analyzing your drawing...", modifier = Modifier.padding(top = 16.dp))
    }
}

@Composable
private fun ErrorState(message: String, onRetry: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(message, style = MaterialTheme.typography.bodyLarge)
        Button(onClick = onRetry, modifier = Modifier.padding(top = 16.dp)) {
            Text("Retry")
        }
    }
}

@Composable
private fun FeedbackContent(feedback: AIDrawingFeedbackDto, onDone: () -> Unit) {
    val categories = listOf(
        "Proportions" to feedback.proportions,
        "Shading" to feedback.shading,
        "Line Weight" to feedback.lineWeight,
        "Composition" to feedback.composition
    )

    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        item {
            Card(modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("Overall Score", style = MaterialTheme.typography.labelLarge)
                    Text(
                        "${feedback.overallScore} / 100",
                        style = MaterialTheme.typography.headlineMedium
                    )
                    Text(
                        feedback.encouragement,
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                }
            }
        }

        items(categories) { (label, item) ->
            Card(modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(label, style = MaterialTheme.typography.titleMedium)
                    LinearProgressIndicator(
                        progress = { item.score / 10f },
                        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)
                    )
                    Text(item.comment, style = MaterialTheme.typography.bodyMedium)
                    item.suggestions.forEach { suggestion ->
                        Text(
                            "• $suggestion",
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.padding(top = 4.dp)
                        )
                    }
                }
            }
        }

        item {
            Card(modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("Top Tip", style = MaterialTheme.typography.titleMedium)
                    Text(feedback.topTip, style = MaterialTheme.typography.bodyMedium)
                }
            }
        }

        item {
            Button(onClick = onDone, modifier = Modifier.fillMaxWidth()) {
                Text("Done")
            }
        }
    }
}
