import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import 'services/audio_service.dart';
import 'services/model_manager.dart'; // <--- ADDED THIS IMPORT
import 'utils/permissions.dart';
import 'platform/sakhi_platform.dart';

class WhisperTestPage extends StatefulWidget {
  @override
  _WhisperTestPageState createState() => _WhisperTestPageState();
}

class _WhisperTestPageState extends State<WhisperTestPage> {
  final AudioService _audio = AudioService();

  String logText = "";
  bool _recording = false;
  bool _isLoading = false; // Added to disable button while loading

  void appendLog(String msg) {
    setState(() {
      logText += "${DateTime.now().toIso8601String()} - $msg\n";
    });
  }

  // FIXED: Now handles both file copying AND native loading
  Future<void> loadModel() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    appendLog("STEP 1: Copying model files from assets...");

    try {
      // 1. Copy large files (was causing the startup crash)
      await ModelManager.prepareModels();
      appendLog("✅ Models copied to internal storage.");

      appendLog("STEP 2: Initializing Native Whisper Engine...");

      // 2. Load the model into C++ memory (via background thread in Kotlin)
      final platform = Provider.of<SakhiPlatform>(context, listen: false);
      final res = await platform.initialize();

      appendLog("✅ Whisper Loaded Successfully => $res");
    } catch (e) {
      appendLog("❌ Error loading models: $e");
    } finally {
      setState(() => _isLoading = false);
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
      // Uses the new 'startNativeRecording' method
      await _audio.startRecording();
      setState(() => _recording = true);
      appendLog("🎙️ Recording started (Native)...");
    } catch (e) {
      appendLog("❌ Error starting recording: $e");
    }
  }

  Future<void> _onPointerUp() async {
    if (!_recording) return;

    try {
      final platform = Provider.of<SakhiPlatform>(context, listen: false);

      // Uses the new 'stopNativeRecording' method
      final Uint8List bytes = await _audio.stopRecording();
      setState(() => _recording = false);

      appendLog("⏹️ Stopped. Captured bytes: ${bytes.length}");

      // --- Debug Checks ---
      if (bytes.isEmpty) {
        appendLog("⚠️ WARNING: Audio is 0 bytes. Native recorder failed.");
        return;
      }
      // --------------------

      appendLog("📝 Sending ${bytes.length} bytes to Whisper...");

      // Calls 'transcribeAudio' (which now runs in a background thread)
      final result = await platform.transcribeAudio(bytes);

      appendLog("📝 TRANSCRIPTION RESULT:");
      appendLog(">> ${result ?? "<empty>"}");
    } catch (e, st) {
      appendLog("❌ Error during transcription: $e");
      appendLog("$st");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Whisper Test Page")),
      body: Column(
        children: [
          const SizedBox(height: 12),

          // FIXED BUTTON: Triggers the safe background loading
          ElevatedButton(
            onPressed: _isLoading ? null : loadModel,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isLoading ? Colors.grey : Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text(
              _isLoading ? "Loading..." : "Initialize Models (Run First)",
            ),
          ),

          const SizedBox(height: 12),

          Center(
            child: Listener(
              onPointerDown: (_) => _onPointerDown(),
              onPointerUp: (_) => _onPointerUp(),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: _recording ? Colors.redAccent : Colors.blue,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _recording ? "RELEASE TO STOP" : "HOLD TO RECORD",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.black,
              child: SingleChildScrollView(
                reverse: true, // Auto-scroll to bottom
                child: Text(
                  logText,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: "monospace",
                    fontSize: 13,
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
