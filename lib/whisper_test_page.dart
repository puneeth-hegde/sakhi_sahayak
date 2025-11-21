import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import 'services/audio_service.dart';
import 'services/model_manager.dart';
import 'utils/permissions.dart';
import 'platform/sakhi_platform.dart';

// INTEGRATION: Import the processing screen to connect the pipeline
import 'screens/assist_processing_screen.dart';

class WhisperTestPage extends StatefulWidget {
  @override
  _WhisperTestPageState createState() => _WhisperTestPageState();
}

class _WhisperTestPageState extends State<WhisperTestPage> {
  final AudioService _audio = AudioService();

  String logText = "";
  bool _recording = false;
  bool _isLoading = false;

  void appendLog(String msg) {
    setState(() {
      logText += "${DateTime.now().toIso8601String()} - $msg\n";
    });
  }

  Future<void> loadModel() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    appendLog("STEP 1: Copying model files...");

    try {
      await ModelManager.prepareModels();
      appendLog("✅ Models copied.");

      appendLog("STEP 2: Initializing Native Whisper...");
      final platform = Provider.of<SakhiPlatform>(context, listen: false);
      final res = await platform.initialize();

      appendLog("✅ Whisper Loaded => $res");
    } catch (e) {
      appendLog("❌ Error loading models: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onPointerDown() async {
    final ok = await Permissions.ensureMicPermission();
    if (!ok) {
      appendLog("❌ Permission denied.");
      return;
    }

    try {
      await _audio.startRecording();
      setState(() => _recording = true);
      appendLog("🎙️ Recording started...");
    } catch (e) {
      appendLog("❌ Error starting: $e");
    }
  }

  Future<void> _onPointerUp() async {
    if (!_recording) return;

    try {
      // 1. Stop Native Recording
      final Uint8List bytes = await _audio.stopRecording();
      setState(() => _recording = false);
      appendLog("⏹️ Stopped. Captured ${bytes.length} bytes.");

      if (bytes.isEmpty) {
        appendLog("⚠️ Audio is 0 bytes.");
        return;
      }

      // 2. PIPELINE INTEGRATION: Navigate to the real processing screen
      // This passes the raw audio bytes to your AssistProcessingScreen
      appendLog("🚀 Launching Full Pipeline...");

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AssistProcessingScreen(audioData: bytes),
          ),
        );
      }
    } catch (e) {
      appendLog("❌ Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sakhi Pipeline Test")),
      body: Column(
        children: [
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : loadModel,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isLoading ? Colors.grey : Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text(_isLoading ? "Loading..." : "1. Initialize Models"),
          ),
          const SizedBox(height: 20),

          // INSTRUCTION CARD
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              "Hold the red button below to record.\n"
              "When you release, it will automatically open the Assist Screen and run the full AI pipeline.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: Listener(
              onPointerDown: (_) => _onPointerDown(),
              onPointerUp: (_) => _onPointerUp(),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(
                  vertical: 30,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: _recording ? Colors.redAccent : Colors.red,
                  borderRadius: BorderRadius.circular(100), // Circle shape
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _recording ? Icons.stop : Icons.mic,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _recording ? "Recording..." : "Hold to Record & Run",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),

          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.black,
              child: SingleChildScrollView(
                reverse: true,
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
