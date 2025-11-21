// llama_wrapper.cpp  (drop into android/app/src/main/cpp/)
#include <jni.h>
#include <string>
#include <vector>
#include <android/log.h>
#include <algorithm>
#include <limits>
#include <cstring> // for strlen

#define LOG_TAG "LLamaJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

#include "llama.h"  // CMake should add llama.cpp/include to the include path

static llama_context* g_llama = nullptr;
static llama_model*   g_model = nullptr;

extern "C" JNIEXPORT jboolean JNICALL
Java_com_sakhi_LLMRunner_initModel(JNIEnv* env, jobject thiz, jstring modelPath) {
    if (modelPath == nullptr) {
        LOGE("initModel: modelPath is null");
        return JNI_FALSE;
    }

    const char* path = env->GetStringUTFChars(modelPath, nullptr);
    if (path == nullptr) {
        LOGE("initModel: failed to get UTF chars");
        return JNI_FALSE;
    }

    LOGI("Initializing llama backend, loading model from: %s", path);

    // Initialize backend (current llama API uses no args)
    llama_backend_init();

    // Prepare params with defaults
    llama_model_params mparams = llama_model_default_params();
    llama_context_params cparams = llama_context_default_params();

    // Load model (use modern API name)
    g_model = llama_model_load_from_file(path, mparams);
    if (!g_model) {
        LOGE("initModel: failed to load model from %s", path);
        env->ReleaseStringUTFChars(modelPath, path);
        return JNI_FALSE;
    }

    // Create context from model (modern API)
    g_llama = llama_init_from_model(g_model, cparams);
    if (!g_llama) {
        LOGE("initModel: failed to create llama context from model");
        // free model if available
        llama_model_free(g_model);
        g_model = nullptr;
        env->ReleaseStringUTFChars(modelPath, path);
        return JNI_FALSE;
    }

    LOGI("initModel: model loaded and context created successfully");
    env->ReleaseStringUTFChars(modelPath, path);
    return JNI_TRUE;
}

// Helper: detokenize vector<llama_token> -> string using llama_detokenize/vocab API
static std::string detokenize_to_string(const llama_vocab * vocab, const std::vector<llama_token>& toks) {
    if (toks.empty() || vocab == nullptr) return "";

    // conservative buffer estimate
    int32_t buf_size = (int32_t)(toks.size() * 8 + 256);
    std::string out;
    out.resize(buf_size);

    // llama_detokenize returns number of bytes written, or < 0 on error
    int32_t n = llama_detokenize(vocab, toks.data(), (int32_t)toks.size(),
                                 &out[0], buf_size, /*remove_special=*/true, /*unparse_special=*/false);
    if (n < 0) return std::string();
    out.resize(n);
    return out;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_sakhi_LLMRunner_infer(JNIEnv* env, jobject thiz, jstring prompt) {
    if (prompt == nullptr) {
        LOGE("infer: prompt is null");
        return env->NewStringUTF("");
    }
    if (g_llama == nullptr) {
        LOGE("infer: llama context not initialized");
        return env->NewStringUTF("");
    }

    const char* input = env->GetStringUTFChars(prompt, nullptr);
    if (input == nullptr) {
        LOGE("infer: failed to get prompt UTF chars");
        return env->NewStringUTF("");
    }

    LOGI("infer: received prompt: %s", input);

    const llama_model * model = llama_get_model(g_llama);
    if (!model) {
        LOGE("infer: no model attached to context");
        env->ReleaseStringUTFChars(prompt, input);
        return env->NewStringUTF("");
    }

    const llama_vocab * vocab = llama_model_get_vocab(model);
    if (!vocab) {
        LOGE("infer: failed to get vocab");
        env->ReleaseStringUTFChars(prompt, input);
        return env->NewStringUTF("");
    }

    // Tokenize prompt
    int32_t max_tokens = (int32_t)(strlen(input) * 4 + 32); // conservative upper bound
    std::vector<llama_token> tokens;
    tokens.resize(max_tokens);

    int32_t ntok = llama_tokenize(vocab, input, (int32_t)strlen(input),
                                  tokens.data(), max_tokens,
                                  /*add_special=*/true, /*parse_special=*/false);
    if (ntok < 0) {
        LOGE("infer: tokenization failed (return %d)", ntok);
        env->ReleaseStringUTFChars(prompt, input);
        return env->NewStringUTF("");
    }
    tokens.resize(ntok);

    // Feed prompt tokens to context using batch helper if available
    // (llama_batch & llama_decode used in newer APIs)
    llama_batch batch = llama_batch_get_one(tokens.data(), ntok);
    int rc = llama_decode(g_llama, batch);
    if (rc != 0) {
        LOGE("infer: llama_decode failed for prompt tokens (code %d)", rc);
        env->ReleaseStringUTFChars(prompt, input);
        return env->NewStringUTF("");
    }

    // Generation: greedy argmax sampling (simple, deterministic)
    const int max_generate = 80;
    std::vector<llama_token> gen_tokens;

    int32_t n_vocab = llama_vocab_n_tokens(vocab);

    for (int i = 0; i < max_generate; ++i) {
        // logits for last token (-1 index)
        float * logits = llama_get_logits_ith(g_llama, -1);
        if (!logits) {
            LOGE("infer: logits pointer is null at step %d", i);
            break;
        }

        // greedy argmax
        int32_t best_id = -1;
        float best_val = -std::numeric_limits<float>::infinity();
        for (int32_t v = 0; v < n_vocab; ++v) {
            if (logits[v] > best_val) {
                best_val = logits[v];
                best_id = v;
            }
        }

        if (best_id < 0) {
            LOGE("infer: failed to pick a token at step %d", i);
            break;
        }

        llama_token t = (llama_token)best_id;

        // check EOS via vocab helper
        llama_token eos_tok = llama_vocab_eos(vocab);
        if (t == eos_tok) {
            LOGI("infer: reached EOS at step %d", i);
            break;
        }

        // append token and decode (feed to model)
        gen_tokens.push_back(t);
        llama_batch b2 = llama_batch_get_one(&t, 1);
        int r2 = llama_decode(g_llama, b2);
        if (r2 != 0) {
            LOGE("infer: llama_decode failed while generating at step %d (code %d)", i, r2);
            break;
        }
    }

    // Concatenate prompt + generated tokens for detokenization
    std::vector<llama_token> all_tokens;
    all_tokens.reserve(tokens.size() + gen_tokens.size());
    all_tokens.insert(all_tokens.end(), tokens.begin(), tokens.end());
    all_tokens.insert(all_tokens.end(), gen_tokens.begin(), gen_tokens.end());

    std::string out = detokenize_to_string(vocab, all_tokens);

    env->ReleaseStringUTFChars(prompt, input);

    LOGI("infer: output length=%zu", out.size());
    return env->NewStringUTF(out.c_str());
}
