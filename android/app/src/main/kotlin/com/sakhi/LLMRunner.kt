package com.sakhi

import android.content.Context
import android.util.Log

class LLMRunner(private val context: Context) {

    init {
        try {
            System.loadLibrary("llama_jni")   // load wrapper library
   // Load native llama library
            Log.i("LLMRunner", "llama native library loaded")
        } catch (e: UnsatisfiedLinkError) {
            Log.e("LLMRunner", "Failed to load llama library: ${e.message}")
        }
    }

    private var isLoaded = false

    // --------------------------
    // JNI METHODS (from C++)
    // --------------------------
    private external fun initModel(modelPath: String): Boolean
    private external fun infer(prompt: String): String

    // --------------------------
    // PUBLIC API
    // --------------------------
    fun loadModel(modelPath: String): Boolean {
        Log.i("LLMRunner", "Loading model at: $modelPath")
        val ok = initModel(modelPath)
        isLoaded = ok
        return ok
    }

    fun simplify(text: String?, prefs: Map<String, Any>?): Map<String, Any> {
        if (!isLoaded) {
            Log.e("LLMRunner", "simplify() called before model loaded!")
            return mapOf("steps" to emptyList<Map<String, Any>>())
        }

        val input = text ?: ""
        val prompt = "Simplify this medical text:\n$input\n"

        val raw = infer(prompt)

        // Wrap output in your existing “steps” format
        val result = mapOf(
            "steps" to listOf(
                mapOf("id" to 1, "text" to raw)
            )
        )

        return result
    }
}
