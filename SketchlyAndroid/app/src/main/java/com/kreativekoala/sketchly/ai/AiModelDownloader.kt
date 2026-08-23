package com.kreativekoala.sketchly.ai

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkInfo
import androidx.work.WorkManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.io.File

/**
 * Orchestrator around [AiModelDownloadWorker], adapted from
 * ReadAloudDescribe's GgufModelDownloader.kt. Sketchly has one model
 * (see [AiModelSpec]) so this is a plain singleton rather than a
 * per-ModelKind cache.
 */
class AiModelDownloader private constructor(private val context: Context) {

    sealed class State {
        object Idle : State()
        data class Waiting(val reason: String) : State()
        data class Downloading(
            val percent: Int,
            val downloadedMb: Int,
            val totalMb: Int,
            val fileIndex: Int,
            val fileCount: Int,
            val fileLabel: String,
        ) : State()
        object Ready : State()
        data class Failed(val message: String) : State()
    }

    private val _state = MutableStateFlow<State>(if (isOnDisk()) State.Ready else State.Idle)
    val state: StateFlow<State> = _state.asStateFlow()

    val mmprojFile: File get() = File(context.filesDir, AiModelSpec.MMPROJ_FILE_NAME)
    val textModelFile: File get() = File(context.filesDir, AiModelSpec.TEXT_FILE_NAME)

    fun isOnDisk(): Boolean {
        val mmproj = mmprojFile
        val text = textModelFile
        return mmproj.exists() && mmproj.length() >= AiModelSpec.EXPECTED_MMPROJ_MIN_BYTES &&
            text.exists() && text.length() >= AiModelSpec.EXPECTED_TEXT_MIN_BYTES
    }

    fun startIfPossible() {
        if (isOnDisk()) {
            _state.value = State.Ready
            return
        }
        Log.i(TAG, "startIfPossible: enqueuing AiModelDownloadWorker (unmetered)")
        // Wi-Fi only — ~640MB shouldn't come out of someone's data plan
        // without asking.
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.UNMETERED)
            .build()

        val request = OneTimeWorkRequestBuilder<AiModelDownloadWorker>()
            .setConstraints(constraints)
            .build()

        WorkManager.getInstance(context).enqueueUniqueWork(
            WORK_NAME,
            ExistingWorkPolicy.KEEP,
            request,
        )
        startObservingWorkState()
    }

    fun cancel() {
        WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        _state.value = if (isOnDisk()) State.Ready else State.Idle
    }

    private var observing = false

    private fun startObservingWorkState() {
        if (observing) return
        observing = true
        val liveData = WorkManager.getInstance(context).getWorkInfosForUniqueWorkLiveData(WORK_NAME)
        liveData.observeForever { infos ->
            val info = infos?.firstOrNull() ?: return@observeForever
            when (info.state) {
                WorkInfo.State.RUNNING -> {
                    val p = info.progress
                    val pct = p.getInt(AiModelDownloadWorker.KEY_PERCENT, -1)
                    if (pct >= 0) {
                        _state.value = State.Downloading(
                            percent = pct,
                            downloadedMb = (p.getLong(AiModelDownloadWorker.KEY_DOWNLOADED_BYTES, 0) / 1024 / 1024).toInt(),
                            totalMb = (p.getLong(AiModelDownloadWorker.KEY_TOTAL_BYTES, 0) / 1024 / 1024).toInt(),
                            fileIndex = p.getInt(AiModelDownloadWorker.KEY_FILE_INDEX, 1),
                            fileCount = p.getInt(AiModelDownloadWorker.KEY_FILE_COUNT, 2),
                            fileLabel = p.getString(AiModelDownloadWorker.KEY_FILE_LABEL) ?: "AI model",
                        )
                    }
                }
                WorkInfo.State.ENQUEUED, WorkInfo.State.BLOCKED -> {
                    _state.value = State.Waiting(currentWaitReason(context))
                }
                WorkInfo.State.SUCCEEDED -> _state.value = State.Ready
                WorkInfo.State.FAILED -> {
                    val msg = info.outputData.getString(AiModelDownloadWorker.KEY_ERROR) ?: "Download failed"
                    _state.value = State.Failed(msg)
                }
                WorkInfo.State.CANCELLED -> _state.value = if (isOnDisk()) State.Ready else State.Idle
            }
        }
    }

    companion object {
        private const val TAG = "AiModelDownloader"
        const val WORK_NAME = "sketchly_ai_model_download"

        @Volatile private var instance: AiModelDownloader? = null

        fun getInstance(context: Context): AiModelDownloader =
            instance ?: synchronized(this) {
                instance ?: AiModelDownloader(context.applicationContext).also { instance = it }
            }

        private fun currentWaitReason(context: Context): String {
            if (!isOnUnmeteredNetwork(context)) {
                return "Waiting for Wi-Fi — the ${AiModelSpec.SIZE_LABEL} model will download as soon as you connect."
            }
            val bm = context.getSystemService(Context.BATTERY_SERVICE) as? android.os.BatteryManager
            val pct = bm?.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1
            if (pct in 0..15) {
                return "Battery low ($pct%) — connect to a charger to start the download."
            }
            return "System is queueing the download — should start in a few seconds."
        }

        private fun isOnUnmeteredNetwork(context: Context): Boolean {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val net = cm.activeNetwork ?: return false
            val caps = cm.getNetworkCapabilities(net) ?: return false
            return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) &&
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        }
    }
}
