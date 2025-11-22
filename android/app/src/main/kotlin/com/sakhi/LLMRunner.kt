package com.sakhi

import android.content.Context
import android.util.Log

class LLMRunner(private val context: Context) {

    init {
        try {
            System.loadLibrary("llama_jni")
            Log.i("LLMRunner", "llama native library loaded")
        } catch (e: UnsatisfiedLinkError) {
            Log.e("LLMRunner", "Failed to load llama library: ${e.message}")
        }
    }

    private var isLoaded = false

    private external fun initModel(modelPath: String): Boolean
    private external fun infer(prompt: String): String

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
        
        // =========================================================================
        // IMPROVED PROMPT STRUCTURE
        // Works with stop sequences defined in C++
        // =========================================================================
        val prompt = """Question: $input
Answer:""".trimIndent()  // Note: No space after "Answer:" helps with stopping

        Log.i("LLMRunner", "START Inference with prompt: $prompt")
        val startTime = System.currentTimeMillis()
        
        // Call C++ inference - now returns ONLY the generated answer
        var cleanText = infer(prompt)
        
        val duration = System.currentTimeMillis() - startTime
        Log.i("LLMRunner", "END Inference. Took ${duration}ms")

        // =========================================================================
        // MINIMAL CLEANUP - C++ already handles stop sequences!
        // =========================================================================
        cleanText = cleanText
            .trim()
            .removePrefix("Answer:")  // Just in case
            .removePrefix(":")
            .trim()

        // Safety fallback for empty responses
        if (cleanText.isEmpty() || cleanText.length < 3) {
            cleanText = "I'm not sure how to answer that. Could you rephrase your question?"
        }

        // Optional: Remove any remaining role markers (paranoid check)
        val forbiddenPhrases = listOf("Question:", "User:", "Sakhi:", "(smiling)", "(thinking)")
        for (phrase in forbiddenPhrases) {
            if (cleanText.contains(phrase, ignoreCase = true)) {
                cleanText = cleanText.substringBefore(phrase).trim()
                Log.w("LLMRunner", "Found forbidden phrase '$phrase', truncated response")
            }
        }

        return mapOf(
            "steps" to listOf(
                mapOf("id" to 1, "text" to cleanText)
            )
        )
    }

    // =========================================================================
    // OPTIONAL: Advanced inference with custom parameters
    // =========================================================================
    fun inferWithParams(
        prompt: String,
        temperature: Float = 0.7f,
        maxTokens: Int = 200
    ): String {
        if (!isLoaded) {
            Log.e("LLMRunner", "Model not loaded")
            return ""
        }
        
        // For now, we use the default C++ parameters
        // You can extend this by creating a new JNI method that accepts parameters
        return infer(prompt)
    }
}