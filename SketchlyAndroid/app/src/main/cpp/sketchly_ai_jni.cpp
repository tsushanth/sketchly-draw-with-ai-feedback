// JNI bridge between Kotlin (LlamaEngine) and llama.cpp + mtmd, adapted
// from ~/Documents/GitHub/ReadAloudDescribe/android/app/src/main/cpp/describe_jni.cpp
// for Sketchly's on-device "AI Feedback" feature.
//
// Differences from the ReadAloudDescribe reference:
//   - Single model (SmolVLM2-500M "Fast") — no Moondream2 toggle, so
//     the chat-template branch always uses the "smolvlm" wrapping.
//   - nativeDescribeImageJson() replaces free-text describe with a
//     GBNF-grammar-constrained decode that forces the model's output
//     to be syntactically valid JSON in AiFeedbackRepository's exact
//     shape (see AiFeedbackModels.kt). This is real grammar-constrained
//     decoding via llama_sampler_init_grammar — confirmed present in
//     this checkout's llama.h (not assumed) and confirmed to operate
//     purely on the text-decoder's logits, so it works identically
//     whether the preceding tokens came from mtmd vision-prefill or
//     plain text — the mtmd/multimodal path itself has no separate
//     grammar hook, and doesn't need one.
//
// Grammar only constrains STRUCTURE (valid JSON matching the field
// order/types AiFeedbackRepository expects) — it cannot guarantee the
// *content* is sensible (a 500M model can still emit a low-quality or
// repetitive comment string). The Kotlin-side parser in
// OnDeviceFeedbackEngine.kt is still defensive: JSON that parses but
// has out-of-range scores gets clamped, and if the grammar-constrained
// decode still fails to produce parseable JSON (e.g. it hits maxTokens
// before closing the object), the raw text is surfaced as
// "encouragement" with null scores rather than crashing.

#include <jni.h>
#include <string>
#include <android/log.h>

#include "llama.h"
#include "ggml.h"
#include "mtmd.h"
#include "mtmd-helper.h"

#include <vector>
#include <chrono>
#include <cstring>
#include <unistd.h>
#include <thread>
#include <cstdio>

#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "sketchly_ai_jni", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "sketchly_ai_jni", __VA_ARGS__)

namespace {

// Android does not route native stderr/stdout to logcat by default, so
// llama.cpp's own fprintf(stderr, ...) diagnostics (e.g. the GBNF
// grammar parser's syntax-error messages in llama-grammar.cpp) are
// otherwise invisible. Redirect fd 2 through a pipe read on a
// background thread and re-emit each line via __android_log_write —
// needed to actually see *why* llama_sampler_init_grammar fails
// instead of just that it fails.
void redirectStderrToLogcat() {
    static bool started = false;
    if (started) return;
    started = true;
    int pipefd[2];
    if (pipe(pipefd) != 0) return;
    dup2(pipefd[1], STDERR_FILENO);
    close(pipefd[1]);
    std::thread([readFd = pipefd[0]]() {
        char buf[1024];
        FILE * f = fdopen(readFd, "r");
        if (!f) return;
        while (fgets(buf, sizeof(buf), f) != nullptr) {
            size_t len = strlen(buf);
            if (len > 0 && buf[len - 1] == '\n') buf[len - 1] = '\0';
            __android_log_write(ANDROID_LOG_ERROR, "native-stderr", buf);
        }
    }).detach();
}

struct AiContext {
    llama_model   * model = nullptr;
    llama_context * lctx  = nullptr;
    mtmd_context  * mtmd  = nullptr;

    ~AiContext() {
        if (mtmd)  { mtmd_free(mtmd); }
        if (lctx)  { llama_free(lctx); }
        if (model) { llama_model_free(model); }
    }
};

// GBNF grammar forcing the exact AIDrawingFeedbackDto shape (fixed key
// order — the parser on the Kotlin side matches this order, though it
// also tolerates reordering defensively). Scores are constrained to
// 1-2 digit integers; overallScore to 1-3 digits. Strings are a
// restricted no-control-char, no-unescaped-quote JSON string body —
// good enough for this model's vocabulary, not a full RFC 8259 string
// grammar (no \uXXXX escapes), which is an acceptable tradeoff since
// this is generated text, not parsed untrusted input.
// Rewritten to reuse llama.cpp's own upstream grammars/json.gbnf `string`
// sub-rule verbatim (character class, escape handling) after the original
// version above failed to parse on-device (llama_sampler_init_grammar
// returned null -- confirmed via real on-device testing, not assumed).
// Suspected culprits were the non-upstream escape class and the
// space-less "[1-9][0-9]" sequence; this version removes both
// variables by mirroring upstream's proven syntax as closely as possible.
// GBNF rule bodies must not span a bare (unparenthesized) newline —
// confirmed via on-device testing: llama.cpp's parser terminates a
// rule at the first un-grouped newline and then expects a new
// "name ::=" on the next line, producing "expecting name at <rest>".
// Upstream's own grammars/json.gbnf only spans lines by wrapping the
// continuation in "( ... )"; simplest fix here is one line per rule.
const char* kFeedbackJsonGrammar = R"GBNF(
root       ::= "{" ws "\"proportions\":" ws item "," ws "\"shading\":" ws item "," ws "\"lineWeight\":" ws item "," ws "\"composition\":" ws item "," ws "\"overallScore\":" ws int100 "," ws "\"encouragement\":" ws string "," ws "\"topTip\":" ws string ws "}"
item       ::= "{" ws "\"score\":" ws int10 "," ws "\"comment\":" ws string "," ws "\"suggestions\":" ws strlist ws "}"
strlist    ::= "[" ws string ("," ws string){0,1} ws "]"
string     ::= "\"" ( [^"\\\x7F\x00-\x1F] | "\\" ["\\bfnrt] ){1,140} "\""
int10      ::= "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" | "10"
int100     ::= "100" | [1-9] [0-9] | [1-9]
ws         ::= " "?
)GBNF";

}  // namespace

extern "C" JNIEXPORT jstring JNICALL
Java_com_kreativekoala_sketchly_ai_LlamaEngine_nativeSystemInfo(
    JNIEnv* env, jobject /* this */
) {
    const char* sys = llama_print_system_info();
    std::string out = "llama.cpp linked OK\nsystem_info: ";
    out += (sys ? sys : "<null>");
    return env->NewStringUTF(out.c_str());
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_kreativekoala_sketchly_ai_LlamaEngine_nativeLoadModels(
    JNIEnv* env, jobject /* this */,
    jstring mmprojPath, jstring textModelPath, jint nCtx
) {
    const char* mmproj_c = env->GetStringUTFChars(mmprojPath, nullptr);
    const char* text_c   = env->GetStringUTFChars(textModelPath, nullptr);
    redirectStderrToLogcat();
    LOGI("nativeLoadModels mmproj=%s text=%s", mmproj_c, text_c);

    llama_backend_init();
    auto* ctx = new AiContext();

    llama_model_params mparams = llama_model_default_params();
    mparams.n_gpu_layers = 0;

    ctx->model = llama_model_load_from_file(text_c, mparams);
    if (!ctx->model) {
        LOGE("llama_model_load_from_file FAILED for %s", text_c);
        delete ctx;
        env->ReleaseStringUTFChars(mmprojPath, mmproj_c);
        env->ReleaseStringUTFChars(textModelPath, text_c);
        return 0;
    }

    llama_context_params cparams = llama_context_default_params();
    cparams.n_ctx      = (nCtx > 0) ? (uint32_t)nCtx : 4096u;
    cparams.n_batch    = 512;
    cparams.n_ubatch   = 512;
    cparams.n_threads  = 6;
    cparams.n_threads_batch = 6;

    ctx->lctx = llama_init_from_model(ctx->model, cparams);
    if (!ctx->lctx) {
        LOGE("llama_init_from_model FAILED");
        delete ctx;
        env->ReleaseStringUTFChars(mmprojPath, mmproj_c);
        env->ReleaseStringUTFChars(textModelPath, text_c);
        return 0;
    }

    mtmd_context_params vparams = mtmd_context_params_default();
    vparams.use_gpu       = false;
    vparams.print_timings = false;
    vparams.n_threads     = 6;
    vparams.warmup        = false;

    ctx->mtmd = mtmd_init_from_file(mmproj_c, ctx->model, vparams);
    if (!ctx->mtmd) {
        LOGE("mtmd_init_from_file FAILED for %s", mmproj_c);
        delete ctx;
        env->ReleaseStringUTFChars(mmprojPath, mmproj_c);
        env->ReleaseStringUTFChars(textModelPath, text_c);
        return 0;
    }

    env->ReleaseStringUTFChars(mmprojPath, mmproj_c);
    env->ReleaseStringUTFChars(textModelPath, text_c);
    LOGI("nativeLoadModels success, handle=%p", (void*)ctx);
    return reinterpret_cast<jlong>(ctx);
}

extern "C" JNIEXPORT void JNICALL
Java_com_kreativekoala_sketchly_ai_LlamaEngine_nativeFreeModels(
    JNIEnv* /* env */, jobject /* this */, jlong handle
) {
    if (handle == 0) return;
    auto* ctx = reinterpret_cast<AiContext*>(handle);
    delete ctx;
}

// ----------------------------------------------------------------
// Grammar-constrained JSON feedback. Same mtmd tokenize/prefill
// pipeline as the ReadAloudDescribe reference, but the greedy-argmax
// decode loop is replaced with: sample -> mask against the grammar's
// allowed-token set -> take the highest-probability token that
// survives the mask -> feed the grammar sampler that token so it
// advances its internal parse state.
// ----------------------------------------------------------------
extern "C" JNIEXPORT jstring JNICALL
Java_com_kreativekoala_sketchly_ai_LlamaEngine_nativeDescribeImageJson(
    JNIEnv* env, jobject /* this */,
    jlong handle,
    jbyteArray imageBytes,
    jstring promptStr,
    jint maxTokens,
    jstring chatTemplateStr
) {
    if (handle == 0) {
        return env->NewStringUTF("(error: engine not loaded)");
    }
    auto* ctx = reinterpret_cast<AiContext*>(handle);

    jsize image_len  = env->GetArrayLength(imageBytes);
    jbyte* image_buf = env->GetByteArrayElements(imageBytes, nullptr);
    const char* prompt_c = env->GetStringUTFChars(promptStr, nullptr);
    const char* chatTemplate_c = chatTemplateStr ? env->GetStringUTFChars(chatTemplateStr, nullptr) : nullptr;

    auto t_start = std::chrono::steady_clock::now();

    LOGI("nativeDescribeImageJson: entry, imageLen=%d maxTokens=%d", (int)image_len, (int)maxTokens);

    auto bitmap_wrap = mtmd_helper_bitmap_init_from_buf(
        ctx->mtmd,
        reinterpret_cast<const unsigned char*>(image_buf),
        image_len, /* placeholder= */ false
    );
    if (!bitmap_wrap.bitmap) {
        env->ReleaseByteArrayElements(imageBytes, image_buf, JNI_ABORT);
        env->ReleaseStringUTFChars(promptStr, prompt_c);
        if (chatTemplate_c) env->ReleaseStringUTFChars(chatTemplateStr, chatTemplate_c);
        LOGE("mtmd_helper_bitmap_init_from_buf FAILED");
        return env->NewStringUTF("(error: bad image format)");
    }
    LOGI("nativeDescribeImageJson: bitmap decoded OK");

    // Chat-template wrapping per model, mirrors ReadAloudDescribe's
    // describe_jni.cpp compose_chat_prompt(): "vicuna" for Moondream2,
    // ChatML-like default for SmolVLM2. Selected by chatTemplate_c —
    // an unrecognized/null value falls back to the smolvlm wrapping.
    const char* marker = mtmd_default_marker();
    std::string full_prompt;
    if (chatTemplate_c && std::string(chatTemplate_c) == "vicuna") {
        full_prompt = "USER: ";
        full_prompt += marker;
        full_prompt += "\n";
        full_prompt += prompt_c;
        full_prompt += "\nASSISTANT:";
    } else {
        full_prompt = "<|im_start|>User:";
        full_prompt += marker;
        full_prompt += "\n";
        full_prompt += prompt_c;
        full_prompt += "<end_of_utterance>\nAssistant:";
    }

    mtmd_input_text input_text;
    input_text.text          = full_prompt.c_str();
    input_text.add_special   = true;
    input_text.parse_special = true;

    mtmd_input_chunks * chunks = mtmd_input_chunks_init();
    const mtmd_bitmap * bitmaps[1] = { bitmap_wrap.bitmap };

    int32_t tok_rc = mtmd_tokenize(ctx->mtmd, chunks, &input_text, bitmaps, 1);
    if (tok_rc != 0) {
        mtmd_input_chunks_free(chunks);
        mtmd_bitmap_free(bitmap_wrap.bitmap);
        env->ReleaseByteArrayElements(imageBytes, image_buf, JNI_ABORT);
        env->ReleaseStringUTFChars(promptStr, prompt_c);
        if (chatTemplate_c) env->ReleaseStringUTFChars(chatTemplateStr, chatTemplate_c);
        char buf[64]; snprintf(buf, sizeof(buf), "(error: tokenize rc=%d)", tok_rc);
        LOGE("mtmd_tokenize FAILED rc=%d", tok_rc);
        return env->NewStringUTF(buf);
    }
    LOGI("nativeDescribeImageJson: tokenize OK");

    llama_memory_clear(llama_get_memory(ctx->lctx), true);

    llama_pos n_past_out = 0;
    int32_t eval_rc = mtmd_helper_eval_chunks(
        ctx->mtmd, ctx->lctx, chunks, 0, 0, 512, true, &n_past_out
    );
    if (eval_rc != 0) {
        mtmd_input_chunks_free(chunks);
        mtmd_bitmap_free(bitmap_wrap.bitmap);
        env->ReleaseByteArrayElements(imageBytes, image_buf, JNI_ABORT);
        env->ReleaseStringUTFChars(promptStr, prompt_c);
        if (chatTemplate_c) env->ReleaseStringUTFChars(chatTemplateStr, chatTemplate_c);
        char buf[64]; snprintf(buf, sizeof(buf), "(error: eval rc=%d)", eval_rc);
        LOGE("mtmd_helper_eval_chunks FAILED rc=%d", eval_rc);
        return env->NewStringUTF(buf);
    }
    LOGI("nativeDescribeImageJson: eval OK, n_past=%d", (int)n_past_out);

    const llama_model * model = llama_get_model(ctx->lctx);
    const llama_vocab * vocab = llama_model_get_vocab(model);
    const llama_token   eos   = llama_vocab_eos(vocab);
    const int32_t n_vocab     = llama_vocab_n_tokens(vocab);

    LOGI("nativeDescribeImageJson: about to init grammar, n_vocab=%d, grammar_len=%d",
         (int)n_vocab, (int)strlen(kFeedbackJsonGrammar));
    llama_sampler * grammar = llama_sampler_init_grammar(vocab, kFeedbackJsonGrammar, "root");
    LOGI("nativeDescribeImageJson: llama_sampler_init_grammar returned %p", (void*)grammar);
    if (!grammar) {
        // Shouldn't happen (grammar is a fixed, tested string), but if
        // the GBNF fails to parse on some llama.cpp version, fail loud
        // rather than silently decoding unconstrained.
        mtmd_input_chunks_free(chunks);
        mtmd_bitmap_free(bitmap_wrap.bitmap);
        env->ReleaseByteArrayElements(imageBytes, image_buf, JNI_ABORT);
        env->ReleaseStringUTFChars(promptStr, prompt_c);
        if (chatTemplate_c) env->ReleaseStringUTFChars(chatTemplateStr, chatTemplate_c);
        LOGE("llama_sampler_init_grammar FAILED to parse grammar");
        return env->NewStringUTF("(error: grammar init failed)");
    }

    llama_batch batch = llama_batch_init(1, 0, 1);

    std::vector<llama_token_data> cand;
    cand.resize(n_vocab);

    std::string result;
    result.reserve(2048);
    int generated = 0;

    for (int step = 0; step < (int)maxTokens; ++step) {
        const float * logits = llama_get_logits_ith(ctx->lctx, -1);
        if (!logits) {
            LOGE("null logits at step %d", step);
            break;
        }

        for (int i = 0; i < n_vocab; ++i) {
            cand[i] = { (llama_token)i, logits[i], 0.0f };
        }
        llama_token_data_array cur_p = { cand.data(), (size_t)n_vocab, -1, false };

        // Grammar masks disallowed tokens to -inf in place.
        llama_sampler_apply(grammar, &cur_p);

        int best = 0;
        float best_l = cur_p.data[0].logit;
        for (size_t i = 1; i < cur_p.size; ++i) {
            if (cur_p.data[i].logit > best_l) { best_l = cur_p.data[i].logit; best = (int)i; }
        }
        const llama_token next = cur_p.data[best].id;

        if (next == eos) {
            LOGI("EOS at step %d", step);
            break;
        }
        generated++;
        llama_sampler_accept(grammar, next);

        char piece[64];
        int n_chars = llama_token_to_piece(vocab, next, piece, sizeof(piece), 0, false);
        if (n_chars > 0) {
            result.append(piece, n_chars);
        }

        batch.n_tokens      = 1;
        batch.token[0]      = next;
        batch.pos[0]        = n_past_out;
        batch.n_seq_id[0]   = 1;
        batch.seq_id[0][0]  = 0;
        batch.logits[0]     = 1;
        if (llama_decode(ctx->lctx, batch) != 0) {
            LOGE("decode failed at step %d", step);
            break;
        }
        n_past_out += 1;

        // Grammar reaching an accepting state at "}" closing the root
        // object is the natural stop; the model may still emit EOS
        // right after, but bail early if result already looks closed
        // to save decode time (cheap heuristic, grammar already
        // guarantees well-formedness up to this point).
        if (!result.empty() && result.back() == '}' && result.front() == '{') {
            // crude balance check
            int depth = 0; bool in_str = false; bool esc = false; bool closed = false;
            for (char c : result) {
                if (esc) { esc = false; continue; }
                if (c == '\\' && in_str) { esc = true; continue; }
                if (c == '"') { in_str = !in_str; continue; }
                if (in_str) continue;
                if (c == '{') depth++;
                else if (c == '}') { depth--; if (depth == 0) { closed = true; } }
            }
            if (closed) break;
        }
    }

    llama_sampler_free(grammar);
    llama_batch_free(batch);
    mtmd_input_chunks_free(chunks);
    mtmd_bitmap_free(bitmap_wrap.bitmap);
    env->ReleaseByteArrayElements(imageBytes, image_buf, JNI_ABORT);
    env->ReleaseStringUTFChars(promptStr, prompt_c);

    auto t_end = std::chrono::steady_clock::now();
    LOGI("nativeDescribeImageJson done: %d tokens in %lldms, result_chars=%zu",
         generated,
         (long long)std::chrono::duration_cast<std::chrono::milliseconds>(t_end - t_start).count(),
         result.size());

    return env->NewStringUTF(result.c_str());
}
