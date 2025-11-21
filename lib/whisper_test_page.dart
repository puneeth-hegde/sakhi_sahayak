// lib/whisper_test_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/audio_service.dart';
import 'utils/permissions.dart';

class WhisperTestPage extends StatefulWidget {
  @override
  _WhisperTestPageState createState() => _WhisperTestPageState();
}

class _WhisperTestPageState extends State<WhisperTestPage> {
  static const MethodChannel _channel = MethodChannel("com.sakhi/native");
  final AudioService _audio = AudioService();

  String logText = "";
  bool _recording = false;

  void appendLog(String msg) {
    setState(() {
      logText += msg + "\n";
    });
  }

  Future<void> loadModel() async {
    appendLog("Initializing native models...");
    try {
      final res = await _channel.invokeMethod('initialize');
      appendLog("initialize => $res");
    } catch (e) {
      appendLog("Error initialize: $e");
    }
  }

  Future<void> _onPointerDown() async {
    appendLog("Checking microphone permission...");
    final ok = await Permissions.ensureMicPermission();
    if (!ok) {
      appendLog("❌ Microphone permission denied.");
      return;
    }

    try {
      await _audio.startRecording();
      setState(() => _recording = true);
      appendLog("Recording... (release to stop)");
    } catch (e) {
      appendLog("Error starting recording: $e");
    }
  }

  Future<void> _onPointerUp() async {
    if (!_recording) return;

    try {
      final Uint8List bytes = await _audio.stopRecording();
      setState(() => _recording = false);

      appendLog("Captured bytes: ${bytes.length}");
      appendLog("Sending to native transcribe...");

      final result = await _channel.invokeMethod('transcribe', {
        'audioData': bytes,
        'sampleRate': 16000,
      });

      appendLog("Transcription: $result");
    } catch (e) {
      appendLog("Error stopping/transcribing: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Whisper Test Page")),
      body: Column(
        children: [
          const SizedBox(height: 12),
          ElevatedButton(onPressed: loadModel, child: const Text("Load Model")),
          const SizedBox(height: 12),

          Center(
            child: Listener(
              onPointerDown: (_) => _onPointerDown(),
              onPointerUp: (_) => _onPointerUp(),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: _recording ? Colors.redAccent : Colors.blue,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  _recording
                      ? "Recording... release to stop"
                      : "Press & Hold to Record",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              color: Colors.black,
              child: SingleChildScrollView(
                child: Text(
                  logText,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: "monospace",
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
