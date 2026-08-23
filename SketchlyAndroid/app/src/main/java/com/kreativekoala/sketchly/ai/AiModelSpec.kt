package com.kreativekoala.sketchly.ai

/**
 * Single on-device model Sketchly ships: SmolVLM2-500M-Video-Instruct
 * ("Fast"). Moondream2 ("Detailed") was tried and reverted — on-device
 * testing showed it was WORSE, not better: comment text degenerated
 * into near-identical boilerplate across every field, suggestions
 * became literal field-name echoes ("shading", "lineWeight"), and it
 * took ~107s per request vs SmolVLM2's ~20-30s. Scores are grounded
 * via DrawingMetrics regardless of which model is loaded — that part
 * doesn't need a bigger model — so SmolVLM2 wins on speed with no
 * commentary-quality downside. The vicuna chat-template plumbing
 * (LlamaEngine/sketchly_ai_jni) stays in place in case Moondream2 is
 * worth revisiting later with a different prompt strategy.
 */
object AiModelSpec {
    const val DISPLAY_NAME = "AI Feedback model"
    const val SIZE_LABEL = "~640 MB"
    const val ESTIMATED_TOTAL_MB = 640

    const val MMPROJ_URL =
        "https://huggingface.co/ggml-org/SmolVLM2-500M-Video-Instruct-GGUF/resolve/main/mmproj-SmolVLM2-500M-Video-Instruct-f16.gguf?download=true"
    const val MMPROJ_FILE_NAME = "smolvlm2-500m-mmproj-f16.gguf"
    const val EXPECTED_MMPROJ_MIN_BYTES = 150L * 1024 * 1024
    const val EXPECTED_MMPROJ_MAX_BYTES = 300L * 1024 * 1024
    // SHA-256 as published by ggml-org, mirrored from ReadAloudDescribe's
    // ModelKind.SMOLVLM2_500M (same file, same publisher).
    const val MMPROJ_SHA256 = "b5dc8ebe7cbeab66a5369693960a52515d7824f13d4063ceca78431f2a6b59b0"

    const val TEXT_URL =
        "https://huggingface.co/ggml-org/SmolVLM2-500M-Video-Instruct-GGUF/resolve/main/SmolVLM2-500M-Video-Instruct-Q8_0.gguf?download=true"
    const val TEXT_FILE_NAME = "smolvlm2-500m-text-Q8_0.gguf"
    const val EXPECTED_TEXT_MIN_BYTES = 350L * 1024 * 1024
    const val EXPECTED_TEXT_MAX_BYTES = 600L * 1024 * 1024
    const val TEXT_SHA256 = "6f67b8036b2469fcd71728702720c6b51aebd759b78137a8120733b4d66438bc"

    // SmolVLM2's image-splitting can multiply vision tokens; matches
    // ReadAloudDescribe's ModelKind.nCtx for the same model.
    const val N_CTX = 4096

    // null selects the JNI layer's default (ChatML-like SmolVLM2
    // wrapping) — see sketchly_ai_jni.cpp's compose_chat_prompt.
    val CHAT_TEMPLATE: String? = null
}
