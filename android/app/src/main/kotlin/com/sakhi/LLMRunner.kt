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
        
        // STRATEGY: Standard Q&A Prompt
        val prompt = """
Question: $input
Answer (Short & Direct):
""".trim()

        Log.i("LLMRunner", "START Inference with prompt: $prompt")
        val startTime = System.currentTimeMillis()
        
        var rawResponse = infer(prompt)
        
        val duration = System.currentTimeMillis() - startTime
        Log.i("LLMRunner", "END Inference. Took ${duration}ms")

        // ---------------------------------------------------------
        // NUCLEAR CLEANUP: Forcefully cut off hallucinations
        // ---------------------------------------------------------
        var cleanText = rawResponse
            .replace(prompt, "")
            .replace("Question:", "")
            .replace("Answer:", "")
            .replace("Sakhi:", "")
            .replace("User:", "")
            .replace("(smiling)", "")
            .replace("(thinking)", "")
            .trim()

        // Stop at the first new line if it tries to start a new paragraph/role
        if (cleanText.contains("\n")) {
            cleanText = cleanText.substringBefore("\n").trim()
        }
        
        // Stop if it tries to ask a question back (hallucination)
        if (cleanText.contains("?")) {
             // Usually implies it's starting a new turn like "Did that help?"
             // For 1B model, often safer to just take the statement before the question.
             // But let's leave it if it's short.
        }

        if (cleanText.isEmpty()) {
            cleanText = "I heard you, but I am not sure how to answer. Please ask again."
        }

        return mapOf(
            "steps" to listOf(
                mapOf("id" to 1, "text" to cleanText)
            )
        )
    }
}