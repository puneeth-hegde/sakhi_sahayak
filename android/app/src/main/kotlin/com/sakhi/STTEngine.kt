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

    // 🔥 FIXED MODEL LOADING - Synchronous load for SakhiPlugin Thread
    fun loadWhisperModel(assetName: String = "flutter_assets/assets/models/whisper_tiny.bin") {
        try {
            val outDir = File(ctx.filesDir, "models")
            if (!outDir.exists()) outDir.mkdirs()

            val fileName = assetName.split('/').last()
            val outFile = File(outDir, fileName)

            val expectedSize = 77691713L
            // Copy from assets if missing or corrupted
            if (!outFile.exists() || outFile.length() != expectedSize) {
                Log.i(TAG, "Copying Whisper model to: ${outFile.absolutePath}")
                try {
                    val tmpFile = File(outDir, fileName + ".tmp")
                    ctx.assets.open(assetName).use { input ->
                        FileOutputStream(tmpFile).use { output ->
                            input.copyTo(output)
                        }
                    }
                    if (tmpFile.length() == expectedSize) {
                        tmpFile.renameTo(outFile)
                    } else {
                        tmpFile.delete()
                        throw Exception("Size mismatch: expected $expectedSize, got ${tmpFile.length()}")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Asset not found or copy failed for $assetName", e)
                    throw e
                }
            } else {
                Log.i(TAG, "Whisper model exists: size=${outFile.length()}")
            }

            // 🔥 CALL THE NATIVE MODEL LOAD
            val ok = nativeLoadModel(outFile.absolutePath)
            nativeLoaded = ok
            Log.i(TAG, "nativeLoadModel() returned = $ok")

        } catch (e: Exception) {
            Log.e(TAG, "Model loading failed: ${e.message}", e)
            nativeLoaded = false
            throw e
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
