package com.sakhi

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

class SakhiPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    
    // The 3 Core Engines
    private lateinit var recorder: NativeRecorder
    private lateinit var sttEngine: STTEngine
    private lateinit var llmRunner: LLMRunner
    private lateinit var ttsEngine: TTSEngine

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.sakhi.whisper")
        channel.setMethodCallHandler(this)

        // Initialize Engines using the classes you provided
        recorder = NativeRecorder()
        sttEngine = STTEngine(context)
        llmRunner = LLMRunner(context)
        ttsEngine = TTSEngine(context)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // -------------------------------------------------------
            // 1. INITIALIZATION (Loads Whisper + LLaMA + TTS)
            // -------------------------------------------------------
            "loadModel" -> {
                Thread {
                    try {
                        // A. Load Whisper
                        sttEngine.loadWhisperModel()
                        
                        // B. Load TTS
                        ttsEngine.loadModel()

                        // C. Load LLaMA (LLM)
                        val modelDir = File(context.filesDir, "models")
                        val llamaFile = File(modelDir, "llama_1b_q4.gguf")
                        
                        if (llamaFile.exists()) {
                            val llmLoaded = llmRunner.loadModel(llamaFile.absolutePath)
                            Log.i("SakhiPlugin", "LLaMA Loaded: $llmLoaded")
                        } else {
                            Log.e("SakhiPlugin", "LLaMA model file NOT found at ${llamaFile.absolutePath}")
                        }

                        // Success callback
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            result.error("LOAD_ERROR", e.message, null)
                        }
                    }
                }.start()
            }

            // -------------------------------------------------------
            // 2. AUDIO RECORDING (Native)
            // -------------------------------------------------------
            "startNativeRecording" -> {
                recorder.start()
                result.success(true)
            }

            "stopNativeRecording" -> {
                val bytes = recorder.stop()
                result.success(bytes)
            }

            // -------------------------------------------------------
            // 3. SPEECH-TO-TEXT (Whisper)
            // -------------------------------------------------------
            "transcribeAudio" -> {
                val audioBytes = call.arguments as ByteArray
                Thread {
                   val floatData = pcm16ToFloat(audioBytes)
                   val text = sttEngine.transcribe(floatData)
                   android.os.Handler(android.os.Looper.getMainLooper()).post {
                       result.success(text)
                   }
                }.start()
            }

            // -------------------------------------------------------
            // 4. LLM TEXT SIMPLIFICATION (The Brain)
            // -------------------------------------------------------
            "simplifyText" -> {
                val text = call.argument<String>("text")
                // Handle nested maps from Dart carefully
                val prefs = call.argument<Map<String, Any>>("prefs")
                
                Thread {
                    try {
                        // Call your LLMRunner class
                        val output = llmRunner.simplify(text, prefs)
                        
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            result.success(output)
                        }
                    } catch (e: Exception) {
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            result.error("LLM_ERROR", e.message, null)
                        }
                    }
                }.start()
            }

            // -------------------------------------------------------
            // 5. TTS (The Mouth)
            // -------------------------------------------------------
            "speakText" -> {
                val text = call.argument<String>("text") ?: ""
                val speed = call.argument<Double>("speed")?.toFloat() ?: 1.0f
                
                // Call your TTSEngine class
                ttsEngine.speak(text, speed)
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    // -------------------------------------------------------
    // HELPER: Audio Recorder (Your Fixed Code)
    // -------------------------------------------------------
    class NativeRecorder {
        private val sampleRate = 16000
        private val channelConfig = AudioFormat.CHANNEL_IN_MONO
        private val encoding = AudioFormat.ENCODING_PCM_16BIT

        private var audioRecord: AudioRecord? = null
        private var recordingThread: Thread? = null
        
        val isRecording = AtomicBoolean(false)
        
        private val audioOutput = ByteArrayOutputStream()

        fun start() {
            if (isRecording.get()) return
            val bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, encoding)
            try {
                audioRecord = AudioRecord(MediaRecorder.AudioSource.MIC, sampleRate, channelConfig, encoding, bufferSize)
                if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) throw RuntimeException("AudioRecord init failed")
                
                audioOutput.reset()
                isRecording.set(true)
                audioRecord?.startRecording()

                recordingThread = Thread {
                    val buffer = ByteArray(bufferSize)
                    while (isRecording.get()) {
                        val readResult = audioRecord?.read(buffer, 0, bufferSize) ?: -1
                        if (readResult > 0) {
                            synchronized(audioOutput) { audioOutput.write(buffer, 0, readResult) }
                        }
                    }
                }
                recordingThread?.start()
            } catch (e: Exception) {
                e.printStackTrace()
                isRecording.set(false)
            }
        }

        fun stop(): ByteArray {
            if (!isRecording.get()) return ByteArray(0)
            isRecording.set(false)
            try { recordingThread?.join(1000) } catch (e: Exception) { e.printStackTrace() }
            try { audioRecord?.stop(); audioRecord?.release() } catch (e: Exception) { e.printStackTrace() }
            finally { audioRecord = null; recordingThread = null }
            synchronized(audioOutput) { return audioOutput.toByteArray() }
        }
    }

    private fun pcm16ToFloat(bytes: ByteArray): FloatArray {
        val outLen = bytes.size / 2
        val out = FloatArray(outLen)
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

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        if (recorder.isRecording.get()) recorder.stop()
    }
}