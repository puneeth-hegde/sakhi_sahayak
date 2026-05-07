package com.sakhi

import android.content.Context
import android.util.Log
import kotlinx.coroutines.*
import java.io.File
import java.io.FileOutputStream

class STTEngine(private val ctx: Context) {

    companion object {
        init {
            System.loadLibrary("whisper_jni")
        }
        private const val TAG = "STTEngine"
    }

    private var nativeLoaded = false
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    external fun nativeLoadModel(path: String?): Boolean
    external fun nativeTranscribe(buf: FloatArray?, length: Int): String?
    external fun nativeUnloadModel()

    // 🔥 FIXED MODEL LOADING - Asset path corrected for Flutter APK structure
    fun loadWhisperModel(assetName: String = "models/whisper_tiny_q8.bin") {
        scope.launch(Dispatchers.IO) {
            try {
                val outDir = File(ctx.filesDir, "models")
                if (!outDir.exists()) outDir.mkdirs()

                val fileName = assetName.split('/').last()
                val outFile = File(outDir, fileName)

                // Copy from assets if missing
                if (!outFile.exists() || outFile.length() == 0L) {
                    Log.i(TAG, "Copying Whisper model to: ${outFile.absolutePath}")
                    try {
                        ctx.assets.open(assetName).use { input ->
                            FileOutputStream(outFile).use { output ->
                                input.copyTo(output)
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Asset not found at $assetName, checking alternate path", e)
                        throw e
                    }
                } else {
                    Log.i(TAG, "Whisper model exists: size=${outFile.length()}")
                }

                // 🔥 CALL THE NATIVE MODEL LOAD
                val ok = nativeLoadModel(outFile.absolutePath)

                withContext(Dispatchers.Main) {
                    nativeLoaded = ok
                    Log.i(TAG, "nativeLoadModel() returned = $ok")
                }

            } catch (e: Exception) {
                Log.e(TAG, "Model loading failed: ${e.message}", e)
                nativeLoaded = false
            }
        }
    }

    fun transcribe(floatBuffer: FloatArray): String {
        if (!nativeLoaded) {
            Log.e(TAG, "transcribe() called but model NOT loaded!")
            return ""
        }

        return try {
            nativeTranscribe(floatBuffer, floatBuffer.size) ?: ""
        } catch (e: Exception) {
            Log.e(TAG, "nativeTranscribe crashed: ${e.message}", e)
            ""
        }
    }

    fun unload() {
        scope.launch(Dispatchers.IO) {
            try {
                nativeUnloadModel()
                Log.i(TAG, "Model unloaded")
            } catch (e: Exception) {
                Log.e(TAG, "Unload error: ${e.message}", e)
            }
        }
    }
}
