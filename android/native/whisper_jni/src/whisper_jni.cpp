#include <jni.h>
#include <android/log.h>
#include "whisper.h"
#include <string>
#include <vector>

#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  "whisper_jni", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "whisper_jni", __VA_ARGS__)

static whisper_context *ctx = nullptr;

extern "C" {

// =======================================================
// 1) LOAD MODEL — your version only supports whisper_init_from_file()
// =======================================================
JNIEXPORT jboolean JNICALL
Java_com_sakhi_STTEngine_nativeInit(
        JNIEnv *env,
        jobject thiz,
        jstring model_path) {

    const char *path = env->GetStringUTFChars(model_path, nullptr);
    LOGI("Loading Whisper model: %s", path);

    // your whisper.h DOES NOT support whisper_context_default_params()
    // or whisper_init_from_file_with_params()
    ctx = whisper_init_from_file(path);

    env->ReleaseStringUTFChars(model_path, path);

    if (ctx == nullptr) {
        LOGE("Failed to load Whisper model");
        return JNI_FALSE;
    }

    LOGI("Whisper model loaded OK");
    return JNI_TRUE;
}

// =======================================================
// 2) TRANSCRIBE — your version supports whisper_full()
// =======================================================
JNIEXPORT jstring JNICALL
Java_com_sakhi_STTEngine_nativeTranscribe(
        JNIEnv *env,
        jobject thiz,
        jbyteArray audioData,
        jint sampleRate) {

    if (ctx == nullptr) {
        LOGE("Transcribe called but model not initialized");
        return env->NewStringUTF("");
    }

    // -------------- PCM16 → float --------------
    jsize len = env->GetArrayLength(audioData);
    jbyte *bytes = env->GetByteArrayElements(audioData, nullptr);

    int nsamples = len / 2;
    const int16_t *pcm16 = reinterpret_cast<int16_t *>(bytes);

    std::vector<float> pcmf32(nsamples);
    for (int i = 0; i < nsamples; i++) {
        pcmf32[i] = pcm16[i] / 32768.0f;
    }

    env->ReleaseByteArrayElements(audioData, bytes, 0);

    // -------------- Set decoding params --------------
    whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);

    params.print_realtime   = false;
    params.print_progress   = false;
    params.print_timestamps = false;
    params.print_special    = false;
    params.n_threads        = 4;
    params.language         = "hi";  // Hindi default

    LOGI("Running whisper_full()...");

    if (whisper_full(ctx, params, pcmf32.data(), pcmf32.size()) != 0) {
        LOGE("whisper_full() failed");
        return env->NewStringUTF("");
    }

    // -------------- Extract text --------------
    int n_segments = whisper_full_n_segments(ctx);
    std::string text = "";

    for (int i = 0; i < n_segments; i++) {
        text += whisper_full_get_segment_text(ctx, i);
    }

    LOGI("Whisper output: %s", text.c_str());

    return env->NewStringUTF(text.c_str());
}

} // extern "C"
