package com.kreativekoala.sketchly.ai

/**
 * Thin Kotlin wrapper around libsketchly_ai_jni.so, adapted from
 * ReadAloudDescribe's LlamaEngine.kt. Sketchly only ships one model
 * (SmolVLM2-500M "Fast" — see [AiModelSpec]), so this surface is
 * narrower than the reference: no chat-template parameter (the native
 * side hardcodes SmolVLM2's wrapping) and describe returns
 * grammar-constrained JSON text instead of free-form prose.
 */
object LlamaEngine {

    init {
        System.loadLibrary("sketchly_ai_jni")
    }

    /** "Is the engine alive" probe — proves the native lib loaded. */
    external fun nativeSystemInfo(): String

    /**
     * Loads the mmproj + text-model GGUFs. Returns an opaque handle,
     * or 0L on failure. Heavy, blocking call — invoke off the main
     * thread. ~3-10s on modern hardware for the ~640MB SmolVLM2 pair.
     */
    external fun nativeLoadModels(mmprojPath: String, textModelPath: String, nCtx: Int): Long

    /** Releases native resources for [handle]. Safe to call with 0L. */
    external fun nativeFreeModels(handle: Long)

    /**
     * Describes [imageBytes] and returns grammar-constrained JSON text
     * matching AIDrawingFeedbackDto's shape (see the GBNF grammar in
     * sketchly_ai_jni.cpp). Blocking — MUST be called off the main
     * thread. Returns an error string starting with "(error:" on
     * failure; otherwise the raw JSON text is returned as-is for
     * OnDeviceFeedbackEngine to parse defensively (the grammar
     * guarantees syntax, not that content is sensible).
     */
    external fun nativeDescribeImageJson(
        handle: Long,
        imageBytes: ByteArray,
        prompt: String,
        maxTokens: Int,
        chatTemplate: String?,
    ): String
}
