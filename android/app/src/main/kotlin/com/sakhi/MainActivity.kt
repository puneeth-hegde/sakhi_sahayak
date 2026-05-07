package com.sakhi

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.sakhi/native"

    private var sttEngine: STTEngine? = null
    private var llmRunner: LLMRunner? = null
    private var ttsEngine: TTSEngine? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // REGISTER NEW WHISPER PLUGIN (com.sakhi.whisper)
        flutterEngine.plugins.add(SakhiPlugin())

        // REGISTER OLD PLATFORM CHANNEL (com.sakhi/native)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "initialize" -> {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                sttEngine = STTEngine(this@MainActivity)
                                llmRunner = LLMRunner(this@MainActivity)
                                ttsEngine = TTSEngine(this@MainActivity)

                                sttEngine!!.loadWhisperModel()

                                val llamaPath = copyModelFromAssets("llama_1b_q4.gguf")
                                llmRunner!!.loadModel(llamaPath)

                                ttsEngine!!.loadModel()

                                runOnUiThread { result.success(true) }
                            } catch (t: Throwable) {
                                runOnUiThread {
                                    result.error("INIT_ERROR", t.message, null)
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
                                    result.error("TRANSCRIBE_ERR", e.message, null)
                                }
                            }
                        }
                    }

                    "simplify" -> {
                        val text = call.argument<String>("text")
                        val prefs = call.argument<Map<String, Any>>("preferences")

                        if (llmRunner == null) {
                            result.error("NOT_INITIALIZED", "LLM runner not initialized", null)
                            return@setMethodCallHandler
                        }

                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val steps = llmRunner!!.simplify(text, prefs)
                                runOnUiThread { result.success(steps) }
                            } catch (e: Throwable) {
                                runOnUiThread {
                                    result.error("LLM_ERR", e.message, null)
                                }
                            }
                        }
                    }

                    "speak" -> {
                        val text = call.argument<String>("text") ?: ""
                        val speed =
                            (call.argument<Double>("speed") ?: 1.0).toFloat()

                        if (ttsEngine == null) {
                            result.error("NOT_INITIALIZED", "TTS engine not initialized", null)
                            return@setMethodCallHandler
                        }

                        CoroutineScope(Dispatchers.IO).launch {
                            val ok = ttsEngine!!.speak(text, speed)
                            runOnUiThread { result.success(ok) }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun copyModelFromAssets(name: String): String {
        val outFile = File(filesDir, name)
        if (!outFile.exists() || outFile.length() == 0L) {
            // Flutter asset path is under assets/ directory in APK
            val assetPath = "models/$name"
            try {
                assets.open(assetPath).use { input ->
                    FileOutputStream(outFile).use { output ->
                        input.copyTo(output)
                    }
                }
            } catch (e: Exception) {
                Log.e("MainActivity", "Failed to copy model from $assetPath", e)
                throw e
            }
        }
        return outFile.absolutePath
    }

    private fun pcm16ToFloat(bytes: ByteArray?): FloatArray {
        if (bytes == null || bytes.isEmpty()) return FloatArray(0)
        val out = FloatArray(bytes.size / 2)
        var i = 0
        var j = 0
        while (i + 1 < bytes.size) {
            val low = bytes[i].toInt() and 0xFF
            val high = bytes[i + 1].toInt()
            val sample = (high shl 8) or low
            val signed = if (sample > 32767) sample - 65536 else sample
            out[j] = signed / 32768f
            i += 2
            j++
        }
        return out
    }
}
