package com.sakhi

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.sakhi/native"

    private var sttEngine: STTEngine? = null
    private var llmRunner: LLMRunner? = null
    private var ttsEngine: TTSEngine? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "initialize" -> {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                sttEngine = STTEngine(this@MainActivity)
                                llmRunner = LLMRunner(this@MainActivity)
                                ttsEngine = TTSEngine(this@MainActivity)

                                // ✅ corrected call name
                                sttEngine!!.loadWhisperModel()

                                runOnUiThread { result.success(true) }
                            } catch (t: Throwable) {
                                runOnUiThread {
                                    result.error("INIT_ERROR", t.message ?: "unknown", null)
                                }
                            }
                        }
                    }

                    "transcribe" -> {
                        val bytes = call.argument<ByteArray>("audioData")
                        if (sttEngine == null) {
                            result.error("NOT_INITIALIZED", "STT engine not initialized", null)
                            return@setMethodCallHandler
                        }

                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val floatData = pcm16ToFloat(bytes)
                                val text = sttEngine!!.transcribe(floatData)
                                runOnUiThread { result.success(text) }
                            } catch (e: Throwable) {
                                runOnUiThread {
                                    result.error("TRANSCRIBE_ERR", e.message ?: "error", null)
                                }
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // PCM16 little-endian ByteArray -> FloatArray (-1.0 .. 1.0)
    private fun pcm16ToFloat(bytes: ByteArray?): FloatArray {
        if (bytes == null || bytes.isEmpty()) return FloatArray(0)
        val out = FloatArray(bytes.size / 2)
        var i = 0
        var j = 0
        while (i + 1 < bytes.size) {
            val low = bytes[i].toInt() and 0xFF
            val high = bytes[i + 1].toInt()
            val sample = (high shl 8) or low
            // convert signed 16-bit to float
            val signed = if (sample > 32767) sample - 65536 else sample
            out[j] = signed / 32768f
            i += 2
            j++
        }
        return out
    }
}
