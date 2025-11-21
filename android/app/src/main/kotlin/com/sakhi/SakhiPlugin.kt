package com.sakhi

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SakhiPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var sttEngine: STTEngine? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.sakhi.whisper")
        channel.setMethodCallHandler(this)
        sttEngine = STTEngine(binding.applicationContext)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadModel" -> {
                // call corrected model loader
                sttEngine?.loadWhisperModel()
                result.success(true)
            }

            "transcribe" -> {
                val audioBytes = recordAudio()
                val floatData = pcm16ToFloat(audioBytes)
                val text = sttEngine?.transcribe(floatData) ?: ""
                result.success(text)
            }

            else -> result.notImplemented()
        }
    }

    private fun recordAudio(): ByteArray {
        val sampleRate = 16000
        val bufferSize = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        val recorder = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )

        val audioData = ByteArray(bufferSize)
        recorder.startRecording()
        Thread.sleep(2000)   // Record 2 seconds; adjust if needed
        recorder.read(audioData, 0, audioData.size)
        recorder.stop()
        recorder.release()

        return audioData
    }

    private fun pcm16ToFloat(bytes: ByteArray): FloatArray {
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

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
