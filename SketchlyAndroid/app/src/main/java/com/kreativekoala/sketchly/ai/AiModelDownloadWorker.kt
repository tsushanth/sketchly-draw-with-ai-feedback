package com.kreativekoala.sketchly.ai

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.pm.ServiceInfo
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.work.CoroutineWorker
import androidx.work.Data
import androidx.work.ForegroundInfo
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.RandomAccessFile
import java.util.concurrent.TimeUnit

/**
 * WorkManager Worker for the two-file GGUF download, adapted from
 * ReadAloudDescribe's GgufDownloadWorker.kt. Same resumable-download +
 * SHA-256 verification + foreground-notification pattern; simplified
 * to Sketchly's single [AiModelSpec] instead of a per-ModelKind input.
 */
class AiModelDownloadWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    private data class FileTarget(
        val url: String,
        val fileName: String,
        val expectedMinBytes: Long,
        val expectedSha256: String,
        val label: String,
    )

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            setForeground(createForegroundInfo("Preparing AI Feedback model…", 0))

            val targets = listOf(
                FileTarget(
                    AiModelSpec.MMPROJ_URL, AiModelSpec.MMPROJ_FILE_NAME,
                    AiModelSpec.EXPECTED_MMPROJ_MIN_BYTES, AiModelSpec.MMPROJ_SHA256,
                    "AI Feedback vision model",
                ),
                FileTarget(
                    AiModelSpec.TEXT_URL, AiModelSpec.TEXT_FILE_NAME,
                    AiModelSpec.EXPECTED_TEXT_MIN_BYTES, AiModelSpec.TEXT_SHA256,
                    "AI Feedback language model",
                ),
            )

            val client = newClient()
            var grandTotal = 0L
            val sizes = mutableMapOf<String, Long>()
            for (t in targets) {
                val size = headSize(client, t.url)
                sizes[t.fileName] = size
                grandTotal += size
            }

            var grandDownloaded = 0L
            for ((index, t) in targets.withIndex()) {
                val dest = File(applicationContext.filesDir, t.fileName)
                val expectedSize = sizes[t.fileName] ?: t.expectedMinBytes

                if (dest.exists() && dest.length() == expectedSize) {
                    grandDownloaded += dest.length()
                    continue
                }
                if (dest.exists() && dest.length() > expectedSize) {
                    dest.delete()
                }

                downloadOne(client, t, dest, expectedSize, index + 1, targets.size, grandDownloaded, grandTotal)
                grandDownloaded += dest.length()
            }

            Log.i(TAG, "all downloads complete (${grandDownloaded / 1024 / 1024} MB total)")
            Result.success()
        } catch (t: Throwable) {
            Log.e(TAG, "download failed: ${t.message}", t)
            Result.failure(Data.Builder().putString(KEY_ERROR, t.message ?: "unknown").build())
        }
    }

    private suspend fun downloadOne(
        client: OkHttpClient,
        target: FileTarget,
        dest: File,
        expectedSize: Long,
        fileIndex: Int,
        fileCount: Int,
        grandTotalBefore: Long,
        grandTotal: Long,
    ) {
        val partial = dest.exists()
        val startByte = if (partial) dest.length() else 0L

        val reqBuilder = Request.Builder().url(target.url)
        if (partial && startByte < expectedSize) {
            reqBuilder.addHeader("Range", "bytes=$startByte-")
        }

        val response = client.newCall(reqBuilder.build()).execute()
        if (!response.isSuccessful) {
            response.close()
            throw RuntimeException("HTTP ${response.code} for ${target.fileName}")
        }
        val body = response.body ?: throw RuntimeException("empty body for ${target.fileName}")

        val raf = RandomAccessFile(dest, "rw")
        try {
            raf.seek(startByte)
            val source = body.byteStream()
            val buf = ByteArray(256 * 1024)
            var written = startByte
            var lastReport = System.currentTimeMillis()
            while (true) {
                val n = source.read(buf)
                if (n <= 0) break
                raf.write(buf, 0, n)
                written += n

                val now = System.currentTimeMillis()
                if (now - lastReport > 250) {
                    val pct = ((grandTotalBefore + (written - startByte)) * 100 / grandTotal).toInt().coerceIn(0, 100)
                    val mb = written / 1024 / 1024
                    val totalMb = expectedSize / 1024 / 1024
                    setProgress(
                        Data.Builder()
                            .putInt(KEY_PERCENT, pct)
                            .putLong(KEY_DOWNLOADED_BYTES, grandTotalBefore + (written - startByte))
                            .putLong(KEY_TOTAL_BYTES, grandTotal)
                            .putInt(KEY_FILE_INDEX, fileIndex)
                            .putInt(KEY_FILE_COUNT, fileCount)
                            .putString(KEY_FILE_LABEL, target.label)
                            .build()
                    )
                    setForeground(createForegroundInfo("${target.label} ($fileIndex of $fileCount): $mb / $totalMb MB", pct))
                    lastReport = now
                }
            }
        } finally {
            raf.close()
            response.close()
        }

        if (target.expectedSha256.isNotBlank()) {
            setForeground(createForegroundInfo("Verifying ${target.label}…", 100))
            val actual = sha256OfFile(dest)
            if (!actual.equals(target.expectedSha256, ignoreCase = true)) {
                dest.delete()
                throw RuntimeException("Downloaded ${target.label} is corrupted (SHA mismatch). It will be re-downloaded next time.")
            }
        }
    }

    private fun sha256OfFile(f: File): String {
        val md = java.security.MessageDigest.getInstance("SHA-256")
        f.inputStream().use { stream ->
            val buf = ByteArray(256 * 1024)
            while (true) {
                val n = stream.read(buf)
                if (n <= 0) break
                md.update(buf, 0, n)
            }
        }
        val bytes = md.digest()
        val sb = StringBuilder(bytes.size * 2)
        for (b in bytes) sb.append("%02x".format(b))
        return sb.toString()
    }

    private fun newClient(): OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .callTimeout(0, TimeUnit.MILLISECONDS)
        .followRedirects(true)
        .build()

    private fun headSize(client: OkHttpClient, url: String): Long {
        val response = client.newCall(Request.Builder().url(url).head().build()).execute()
        response.use {
            return it.header("Content-Length")?.toLongOrNull() ?: 0L
        }
    }

    private fun createForegroundInfo(caption: String, percent: Int): ForegroundInfo {
        val mgr = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && mgr.getNotificationChannel(CHANNEL_ID) == null) {
            mgr.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "AI Feedback model download", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Shown while Sketchly downloads its on-device AI Feedback model."
                    setShowBadge(false)
                }
            )
        }

        val openIntent = applicationContext.packageManager
            .getLaunchIntentForPackage(applicationContext.packageName)
            ?.let {
                PendingIntent.getActivity(applicationContext, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            }

        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Sketchly")
            .setContentText(caption)
            .setProgress(100, percent, percent == 0)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openIntent)
            .build()

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ForegroundInfo(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            ForegroundInfo(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        private const val TAG = "AiModelDownloadWorker"
        const val CHANNEL_ID = "sketchly_ai_model_download"
        const val NOTIFICATION_ID = 0x5A11 // "SketchlyAI"

        const val KEY_PERCENT = "percent"
        const val KEY_DOWNLOADED_BYTES = "downloaded_bytes"
        const val KEY_TOTAL_BYTES = "total_bytes"
        const val KEY_FILE_INDEX = "file_index"
        const val KEY_FILE_COUNT = "file_count"
        const val KEY_FILE_LABEL = "file_label"
        const val KEY_ERROR = "error"
    }
}
