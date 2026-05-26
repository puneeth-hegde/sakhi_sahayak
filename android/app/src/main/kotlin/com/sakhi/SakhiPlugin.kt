package com.sakhi

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicBoolean

class SakhiPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    
    private lateinit var recorder: NativeRecorder
    private lateinit var sttEngine: STTEngine
    private lateinit var llmRunner: LLMRunner
    private lateinit var ttsEngine: TTSEngine

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.sakhi.whisper")
        channel.setMethodCallHandler(this)

        recorder = NativeRecorder()
        sttEngine = STTEngine(context)
        llmRunner = LLMRunner(context)
        ttsEngine = TTSEngine(context)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadModel" -> {
                Thread {
                    try {
                        sttEngine.loadWhisperModel()
                        ttsEngine.loadModel()
                        
                        val modelDir = File(context.filesDir, "models")
                        if (!modelDir.exists()) modelDir.mkdirs()
                        val llamaFile = File(modelDir, "llama_1b_q4.gguf")
                        
                        val expectedSize = 807690656L
                        if (!llamaFile.exists() || llamaFile.length() != expectedSize) {
                            val tmpFile = File(modelDir, "llama_1b_q4.gguf.tmp")
                            context.assets.open("flutter_assets/assets/models/llama_1b_q4.gguf").use { input ->
                                FileOutputStream(tmpFile).use { output ->
                                    input.copyTo(output)
                                }
                            }
                            if (tmpFile.length() == expectedSize) {
                                tmpFile.renameTo(llamaFile)
                            } else {
                                tmpFile.delete()
                                throw Exception("Size mismatch for LLaMA: expected $expectedSize, got ${tmpFile.length()}")
                            }
                        }
                        
                        if (llamaFile.exists()) {
                            llmRunner.loadModel(llamaFile.absolutePath)
                        }
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

            "startNativeRecording" -> {
                recorder.start()
                result.success(true)
            }

            "stopNativeRecording" -> {
                val bytes = recorder.stop()
                result.success(bytes)
            }

            "transcribeAudio" -> {
                val audioBytes = call.arguments as? ByteArray ?: ByteArray(0)
                Thread {
                    try {
                        val floatData = pcm16ToFloat(audioBytes)
                        val text = sttEngine.transcribe(floatData)
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            result.success(text)
                        }
                    } catch (e: Exception) {
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            result.error("TRANSCRIBE_ERROR", e.message, null)
                        }
                    }
                }.start()
            }

            // Listen for "simplify" AND "simplifyText" to be safe
            "simplify", "simplifyText" -> {
                val text = call.argument<String>("text")
                val prefs = call.argument<Map<String, Any>>("prefs")
                Thread {
                    try {
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

            // Listen for "speak" AND "speakText" to be safe
            "speak", "speakText" -> {
                val text = call.argument<String>("text") ?: ""
                val speed = call.argument<Double>("speed")?.toFloat() ?: 1.0f
                ttsEngine.speak(text, speed)
                result.success(true)
            }

            "stopSpeaking" -> {
                ttsEngine.stop()
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

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
            } catch (e: Exception) { isRecording.set(false) }
        }

        fun stop(): ByteArray {
            if (!isRecording.get()) return ByteArray(0)
            isRecording.set(false)
            try { recordingThread?.join(1000) } catch (e: Exception) {}
            try { audioRecord?.stop(); audioRecord?.release() } catch (e: Exception) {}
            finally { audioRecord = null; recordingThread = null }
            synchronized(audioOutput) { return audioOutput.toByteArray() }
        }
    }

    private fun pcm16ToFloat(bytes: ByteArray): FloatArray {
        val outLen = bytes.size / 2
        val out = FloatArray(outLen)
        var j = 0
        var i = 0
        while (i + 1 < bytes.size) {
            val low = bytes[i].toInt() and 0xFF
            val high = bytes[i + 1].toInt()
            val sample = (high shl 8) or low
            val signed = if (sample > 32767) sample - 65536 else sample
            out[j++] = signed / 32768f
            i += 2
        }
        return out
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        if (recorder.isRecording.get()) recorder.stop()
        if (::llmRunner.isInitialized) {
            llmRunner.unload()
        }
    }
}