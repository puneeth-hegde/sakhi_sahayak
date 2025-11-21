package com.sakhi

import android.content.Context
import android.util.Log

class LLMRunner(private val context: Context) {
    private var loaded = false

    fun loadModel(): Boolean {
        Log.i("com.sakhi.LLMRunner", "Loaded mock LLM model")
        loaded = true
        return true
    }

    fun simplify(text: String?, prefs: Map<String, Any>?): Map<String, Any> {
        return mapOf(
            "steps" to listOf(
                mapOf("id" to 1, "text" to "Stay calm"),
                mapOf("id" to 2, "text" to "Seek help")
            )
        )
    }
}
