package com.kreativekoala.sketchly.ui.aifeedback

import android.graphics.BitmapFactory
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.kreativekoala.sketchly.data.AiFeedbackRepository
import com.kreativekoala.sketchly.data.local.DrawingSessionDao
import com.kreativekoala.sketchly.data.remote.AIDrawingFeedbackDto
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

sealed interface AiFeedbackUiState {
    data object Loading : AiFeedbackUiState
    data class Loaded(val feedback: AIDrawingFeedbackDto) : AiFeedbackUiState
    data class Error(val message: String) : AiFeedbackUiState
}

/**
 * Loads the saved drawing for [drawingId] and requests AI critique,
 * mirroring iOS's Practice -> AIFeedbackView.swift flow — except this
 * runs entirely on-device via pixel analysis (see
 * AiFeedbackRepository.kt), not a cloud call and not a VLM model
 * download. No download/model-loading state needed anymore — see
 * OnDeviceFeedbackEngine.kt for why the model dependency was cut.
 */
@HiltViewModel
class AiFeedbackViewModel @Inject constructor(
    private val dao: DrawingSessionDao,
    private val repository: AiFeedbackRepository,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val drawingId: Long = checkNotNull(savedStateHandle["drawingId"])

    private val _uiState = MutableStateFlow<AiFeedbackUiState>(AiFeedbackUiState.Loading)
    val uiState: StateFlow<AiFeedbackUiState> = _uiState.asStateFlow()

    init {
        requestFeedback()
    }

    fun requestFeedback() {
        viewModelScope.launch {
            _uiState.value = AiFeedbackUiState.Loading
            val session = dao.getById(drawingId)
            if (session == null) {
                _uiState.value = AiFeedbackUiState.Error("Drawing not found.")
                return@launch
            }
            val bitmap = BitmapFactory.decodeFile(session.canvasImagePath)
            if (bitmap == null) {
                _uiState.value = AiFeedbackUiState.Error("Could not load the drawing image.")
                return@launch
            }
            try {
                val feedback = repository.analyzeDrawing(bitmap)
                _uiState.value = AiFeedbackUiState.Loaded(feedback)
            } catch (e: Exception) {
                _uiState.value = AiFeedbackUiState.Error(e.message ?: "AI feedback failed.")
            }
        }
    }
}
