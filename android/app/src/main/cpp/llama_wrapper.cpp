// llama_wrapper.cpp - FIXED VERSION with stop sequences and proper sampling
#include <jni.h>
#include <string>
#include <vector>
#include <android/log.h>
#include <algorithm>
#include <limits>
#include <cstring>
#include <cmath>

#define LOG_TAG "LLamaJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

#include "llama.h"

static llama_context* g_llama = nullptr;
static llama_model*   g_model = nullptr;

// =============================================================================
// STOP SEQUENCE DETECTOR - Key fix for your hallucination problem
// =============================================================================
struct StopSequenceDetector {
    std::vector<std::string> stop_sequences;
    std::string generated_text;
    
    StopSequenceDetector(const std::vector<std::string>& stops) 
        : stop_sequences(stops) {}
    
    bool should_stop(const std::string& new_token) {
        generated_text += new_token;
        
        // Check each stop sequence
        for (const auto& stop : stop_sequences) {
            size_t pos = generated_text.rfind(stop);
            if (pos != std::string::npos) {
                // Found stop sequence - truncate before it
                generated_text = generated_text.substr(0, pos);
                LOGI("Stop sequence detected: '%s'", stop.c_str());
                return true;
            }
        }
        return false;
    }
    
    std::string get_text() const {
        return generated_text;
    }
};

// =============================================================================
// SAMPLING WITH TEMPERATURE AND REPETITION PENALTY
// =============================================================================
struct SamplingParams {
    float temperature = 0.7f;
    float repeat_penalty = 1.15f;
    int repeat_last_n = 64;
    int top_k = 40;
    float top_p = 0.9f;
};

// Apply repetition penalty to logits
static void apply_repetition_penalty(
    float* logits,
    int32_t n_vocab,
    const std::vector<llama_token>& recent_tokens,
    float penalty
) {
    if (penalty == 1.0f || recent_tokens.empty()) return;
    
    for (llama_token tok : recent_tokens) {
        if (tok >= 0 && tok < n_vocab) {
            // If logit is positive, divide; if negative, multiply
            if (logits[tok] > 0) {
                logits[tok] /= penalty;
            } else {
                logits[tok] *= penalty;
            }
        }
    }
}

// Apply temperature scaling
static void apply_temperature(float* logits, int32_t n_vocab, float temp) {
    if (temp <= 0.0f) temp = 1.0f;
    for (int32_t i = 0; i < n_vocab; ++i) {
        logits[i] /= temp;
    }
}

// Softmax for probability calculation
static void softmax(float* logits, int32_t n_vocab) {
    float max_logit = -std::numeric_limits<float>::infinity();
    for (int32_t i = 0; i < n_vocab; ++i) {
        if (logits[i] > max_logit) max_logit = logits[i];
    }
    
    float sum = 0.0f;
    for (int32_t i = 0; i < n_vocab; ++i) {
        logits[i] = std::exp(logits[i] - max_logit);
        sum += logits[i];
    }
    
    for (int32_t i = 0; i < n_vocab; ++i) {
        logits[i] /= sum;
    }
}

// Top-K + Top-P (nucleus) sampling
static llama_token sample_token(
    float* logits,
    int32_t n_vocab,
    const SamplingParams& params
) {
    // Create pairs of (token_id, probability)
    std::vector<std::pair<int32_t, float>> candidates;
    candidates.reserve(n_vocab);
    for (int32_t i = 0; i < n_vocab; ++i) {
        candidates.push_back({i, logits[i]});
    }
    
    // Sort by probability descending
    std::sort(candidates.begin(), candidates.end(),
              [](const auto& a, const auto& b) { return a.second > b.second; });
    
    // Top-K filtering
    if (params.top_k > 0 && params.top_k < (int)candidates.size()) {
        candidates.resize(params.top_k);
    }
    
    // Top-P (nucleus) filtering
    float cumulative_prob = 0.0f;
    size_t top_p_count = 0;
    for (size_t i = 0; i < candidates.size(); ++i) {
        cumulative_prob += candidates[i].second;
        top_p_count = i + 1;
        if (cumulative_prob >= params.top_p) break;
    }
    candidates.resize(top_p_count);
    
    // Normalize probabilities
    float sum = 0.0f;
    for (const auto& c : candidates) sum += c.second;
    for (auto& c : candidates) c.second /= sum;
    
    // Sample from distribution
    float rand_val = (float)rand() / RAND_MAX;
    float accum = 0.0f;
    for (const auto& c : candidates) {
        accum += c.second;
        if (rand_val <= accum) {
            return (llama_token)c.first;
        }
    }
    
    // Fallback to first candidate
    return (llama_token)candidates[0].first;
}

// =============================================================================
// HELPER: Detokenize
// =============================================================================
static std::string detokenize_to_string(const llama_vocab* vocab, const std::vector<llama_token>& toks) {
    if (toks.empty() || vocab == nullptr) return "";

    int32_t buf_size = (int32_t)(toks.size() * 8 + 256);
    std::string out;
    out.resize(buf_size);

    int32_t n = llama_detokenize(vocab, toks.data(), (int32_t)toks.size(),
                                 &out[0], buf_size, true, false);
    if (n < 0) return std::string();
    out.resize(n);
    return out;
}

// =============================================================================
// JNI: INIT MODEL
// =============================================================================
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

    llama_backend_init();

    llama_model_params mparams = llama_model_default_params();
    llama_context_params cparams = llama_context_default_params();
    
    // Increase context size if needed (default is usually 512)
    cparams.n_ctx = 2048;  // Allow longer conversations

    g_model = llama_model_load_from_file(path, mparams);
    if (!g_model) {
        LOGE("initModel: failed to load model from %s", path);
        env->ReleaseStringUTFChars(modelPath, path);
        return JNI_FALSE;
    }

    g_llama = llama_init_from_model(g_model, cparams);
    if (!g_llama) {
        LOGE("initModel: failed to create llama context from model");
        llama_model_free(g_model);
        g_model = nullptr;
        env->ReleaseStringUTFChars(modelPath, path);
        return JNI_FALSE;
    }

    LOGI("initModel: SUCCESS - model loaded, context created");
    env->ReleaseStringUTFChars(modelPath, path);
    return JNI_TRUE;
}

// =============================================================================
// JNI: INFER WITH STOP SEQUENCES (FIXED VERSION)
// =============================================================================
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

    const llama_model* model = llama_get_model(g_llama);
    const llama_vocab* vocab = llama_model_get_vocab(model);
    if (!vocab) {
        LOGE("infer: failed to get vocab");
        env->ReleaseStringUTFChars(prompt, input);
        return env->NewStringUTF("");
    }

    // Tokenize prompt
    int32_t max_tokens = (int32_t)(strlen(input) * 4 + 32);
    std::vector<llama_token> tokens;
    tokens.resize(max_tokens);

    int32_t ntok = llama_tokenize(vocab, input, (int32_t)strlen(input),
                                  tokens.data(), max_tokens, true, false);
    if (ntok < 0) {
        LOGE("infer: tokenization failed");
        env->ReleaseStringUTFChars(prompt, input);
        return env->NewStringUTF("");
    }
    tokens.resize(ntok);

    // Feed prompt
    llama_batch batch = llama_batch_get_one(tokens.data(), ntok);
    if (llama_decode(g_llama, batch) != 0) {
        LOGE("infer: llama_decode failed for prompt");
        env->ReleaseStringUTFChars(prompt, input);
        return env->NewStringUTF("");
    }

    // =============================================================================
    // STOP SEQUENCES - This prevents hallucination!
    // =============================================================================
    std::vector<std::string> stop_sequences = {
        "\nQuestion:",
        "\nUser:",
        "\nHuman:",
        "Question:",
        "User:",
        "Human:",
        "\n\n",  // Double newline often indicates end of response
    };
    StopSequenceDetector detector(stop_sequences);

    // =============================================================================
    // SAMPLING PARAMETERS - Tuned for 1B models
    // =============================================================================
    SamplingParams sparams;
    sparams.temperature = 0.7f;      // Balanced creativity
    sparams.repeat_penalty = 1.15f;  // Prevent loops (critical!)
    sparams.repeat_last_n = 64;      // Look back window
    sparams.top_k = 40;              // Vocabulary limit
    sparams.top_p = 0.9f;            // Nucleus sampling

    // Generation loop
    const int max_generate = 200;  // Increased from 80
    std::vector<llama_token> gen_tokens;
    std::vector<llama_token> all_generated;  // For repetition penalty
    
    int32_t n_vocab = llama_vocab_n_tokens(vocab);
    llama_token eos_tok = llama_vocab_eos(vocab);
    
    LOGI("Starting generation (max=%d tokens, eos_token=%d)", max_generate, eos_tok);

    for (int i = 0; i < max_generate; ++i) {
        float* logits = llama_get_logits_ith(g_llama, -1);
        if (!logits) {
            LOGE("infer: logits pointer is null at step %d", i);
            break;
        }

        // Copy logits (we'll modify them)
        std::vector<float> logits_copy(logits, logits + n_vocab);

        // Apply repetition penalty
        std::vector<llama_token> recent_tokens;
        int lookback = std::min((int)all_generated.size(), sparams.repeat_last_n);
        if (lookback > 0) {
            recent_tokens.insert(recent_tokens.end(),
                               all_generated.end() - lookback,
                               all_generated.end());
        }
        apply_repetition_penalty(logits_copy.data(), n_vocab, recent_tokens, sparams.repeat_penalty);

        // Apply temperature
        apply_temperature(logits_copy.data(), n_vocab, sparams.temperature);

        // Softmax to get probabilities
        softmax(logits_copy.data(), n_vocab);

        // Sample token
        llama_token t = sample_token(logits_copy.data(), n_vocab, sparams);

        // Check EOS
        if (t == eos_tok) {
            LOGI("infer: reached EOS at step %d", i);
            break;
        }

        // Convert token to string for stop sequence detection
        char buf[256];
        int n = llama_token_to_piece(vocab, t, buf, sizeof(buf), 0, false);  // lstrip=0, special=false
        if (n < 0) {
            LOGE("infer: token_to_piece failed at step %d", i);
            break;
        }
        std::string token_str(buf, n);

        // Check stop sequences BEFORE adding to generation
        if (detector.should_stop(token_str)) {
            LOGI("infer: stop sequence detected at step %d", i);
            break;
        }

        // Token is valid - add it
        gen_tokens.push_back(t);
        all_generated.push_back(t);

        // Feed token back to model
        llama_batch b2 = llama_batch_get_one(&t, 1);
        if (llama_decode(g_llama, b2) != 0) {
            LOGE("infer: llama_decode failed at step %d", i);
            break;
        }
    }

    // =============================================================================
    // RETURN ONLY GENERATED TEXT (not prompt + generation)
    // =============================================================================
    std::string generated_text = detector.get_text();
    
    // Fallback if detector is empty
    if (generated_text.empty() && !gen_tokens.empty()) {
        generated_text = detokenize_to_string(vocab, gen_tokens);
    }

    env->ReleaseStringUTFChars(prompt, input);

    LOGI("infer: generated %zu tokens, output length=%zu chars", gen_tokens.size(), generated_text.size());
    return env->NewStringUTF(generated_text.c_str());
}