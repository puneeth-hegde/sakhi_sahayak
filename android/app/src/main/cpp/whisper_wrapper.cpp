#include <jni.h>
#include <android/log.h>
#include <string>
#include <sys/stat.h>
#include <thread>
#include "whisper.h"

#define LOG_TAG "WhisperJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static whisper_context* g_ctx = nullptr;

static bool file_exists(const char* path) {
    struct stat st;
    return (stat(path, &st) == 0 && st.st_size > 0);
}

extern "C"
JNIEXPORT jboolean JNICALL
Java_com_sakhi_STTEngine_nativeLoadModel(JNIEnv* env, jobject thiz, jstring model_path) {
    const char* path = env->GetStringUTFChars(model_path, nullptr);
    LOGI("Loading model: %s", path);

    if (!file_exists(path)) {
        LOGE("Model file missing or empty: %s", path);
        env->ReleaseStringUTFChars(model_path, path);
        return JNI_FALSE;
    }

    if (g_ctx != nullptr) {
        whisper_free(g_ctx);
        g_ctx = nullptr;
    }

    g_ctx = whisper_init_from_file(path);
    env->ReleaseStringUTFChars(model_path, path);

    if (g_ctx == nullptr) {
        LOGE("whisper_init_from_file FAILED");
        return JNI_FALSE;
    }

    LOGI("Whisper model loaded successfully!");
    return JNI_TRUE;
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_sakhi_STTEngine_nativeTranscribe(JNIEnv* env, jobject thiz, jfloatArray audio, jint length) {
    if (!g_ctx) {
        LOGE("Model not loaded");
        return env->NewStringUTF("");
    }

    if (!audio || length <= 0) {
        LOGE("Invalid audio buffer");
        return env->NewStringUTF("");
    }

    jfloat* audioData = env->GetFloatArrayElements(audio, nullptr);

    whisper_full_params p = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    p.print_progress = false;
    p.language = "hi";
    p.suppress_blank = true;

    p.n_threads = std::min(2u, std::thread::hardware_concurrency());

    LOGI("Starting transcription n_threads=%d len=%d", p.n_threads, length);

    int rc = whisper_full(g_ctx, p, audioData, length);

    env->ReleaseFloatArrayElements(audio, audioData, JNI_ABORT);

    if (rc != 0) {
        LOGE("whisper_full FAILED rc=%d", rc);
        return env->NewStringUTF("");
    }

    std::string out;
    int n = whisper_full_n_segments(g_ctx);

    for (int i = 0; i < n; i++) {
        const char* seg = whisper_full_get_segment_text(g_ctx, i);
        if (seg) out += seg;
        if (i < n - 1) out += " ";
    }

    LOGI("Transcription complete: %s", out.c_str());
    return env->NewStringUTF(out.c_str());
}

extern "C"
JNIEXPORT void JNICALL
Java_com_sakhi_STTEngine_nativeUnloadModel(JNIEnv* env, jobject thiz) {
    if (g_ctx) {
        whisper_free(g_ctx);
        g_ctx = nullptr;
        LOGI("Model unloaded");
    }
}
