package com.sakhi

import android.content.Context
import android.speech.tts.TextToSpeech
import java.util.*

class TTSEngine(private val context: Context) {
    private var tts: TextToSpeech? = null
    private var loaded = false

    fun loadModel(): Boolean {
        tts = TextToSpeech(context) { status ->
            loaded = (status == TextToSpeech.SUCCESS)
        }
        return true
    }

    fun speak(text: String, speed: Float): Boolean {
        if (!loaded || tts == null) return false
        tts?.setSpeechRate(speed)
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "tts")
        return true
    }
}
