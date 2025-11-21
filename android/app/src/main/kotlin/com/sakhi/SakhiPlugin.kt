package com.sakhi

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.atomic.AtomicBoolean

class SakhiPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var recorder: NativeRecorder
    private var sttEngine: STTEngine? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.sakhi.whisper")
        channel.setMethodCallHandler(this)

        recorder = NativeRecorder()
        sttEngine = STTEngine(binding.applicationContext)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadModel" -> {
                // Run model loading on a background thread to prevent UI freeze
                Thread {
                    try {
                        sttEngine?.loadWhisperModel()
                        // Post success back to main thread
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
                val audioBytes = call.arguments as ByteArray
                // Run transcription on background thread
                Thread {
                   val floatData = pcm16ToFloat(audioBytes)
                   val text = sttEngine?.transcribe(floatData) ?: ""
                   android.os.Handler(android.os.Looper.getMainLooper()).post {
                       result.success(text)
                   }
                }.start()
            }

            else -> result.notImplemented()
        }
    }

    // FIXED: NativeRecorder now uses a background thread to read continuously.
    class NativeRecorder {
        private val sampleRate = 16000
        private val channelConfig = AudioFormat.CHANNEL_IN_MONO
        private val encoding = AudioFormat.ENCODING_PCM_16BIT

        private var audioRecord: AudioRecord? = null
        private var recordingThread: Thread? = null
        
        // FIXED: Removed 'private' modifier so SakhiPlugin can access it safely
        val isRecording = AtomicBoolean(false)
        
        private val audioOutput = ByteArrayOutputStream()

        fun start() {
            if (isRecording.get()) return

            val bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, encoding)
            
            try {
                audioRecord = AudioRecord(
                    MediaRecorder.AudioSource.MIC,
                    sampleRate,
                    channelConfig,
                    encoding,
                    bufferSize
                )

                if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                    throw RuntimeException("AudioRecord initialization failed")
                }

                audioOutput.reset()
                isRecording.set(true)
                audioRecord?.startRecording()

                // Start a background thread to read data continuously
                recordingThread = Thread {
                    val buffer = ByteArray(bufferSize)
                    while (isRecording.get()) {
                        val readResult = audioRecord?.read(buffer, 0, bufferSize) ?: -1
                        if (readResult > 0) {
                            synchronized(audioOutput) {
                                audioOutput.write(buffer, 0, readResult)
                            }
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
            // If not recording, return empty bytes immediately
            if (!isRecording.get()) return ByteArray(0)

            // Stop the loop
            isRecording.set(false)
            
            try {
                // Wait for thread to finish writing
                recordingThread?.join(1000)
            } catch (e: InterruptedException) {
                e.printStackTrace()
            }

            try {
                audioRecord?.stop()
                audioRecord?.release()
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                audioRecord = null
                recordingThread = null
            }

            synchronized(audioOutput) {
                return audioOutput.toByteArray()
            }
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
            // 16-bit signed integer handling
            val signed = if (sample > 32767) sample - 65536 else sample
            out[j] = signed / 32768f
            i += 2
            j++
        }
        return out
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        // Safety cleanup
        if (recorder.isRecording.get()) {
            recorder.stop()
        }
    }
}