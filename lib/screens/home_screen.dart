import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../platform/sakhi_platform.dart';
import '../services/audio_service.dart';
import '../services/model_manager.dart';
import '../utils/permissions.dart';
import 'assist_processing_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioService _audio = AudioService();
  bool _isReady = false;
  bool _isRecording = false;
  String _statusText = "Initializing Sakhi...";

  @override
  void initState() {
    super.initState();
    _initializeSakhi();
  }

  Future<void> _initializeSakhi() async {
    await Permissions.ensureMicPermission();
    if (mounted) setState(() => _statusText = "Loading Knowledge...");

    await ModelManager.prepareModels();
    final platform = Provider.of<SakhiPlatform>(context, listen: false);
    await platform.initialize();

    if (mounted) {
      setState(() {
        _isReady = true;
        _statusText = "Tap & Hold to Speak";
      });
    }
  }

  Future<void> _startRecording() async {
    if (!_isReady) return;
    try {
      await _audio.startRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      print(e);
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    try {
      final bytes = await _audio.stopRecording();
      setState(() => _isRecording = false);
      if (bytes.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AssistProcessingScreen(audioData: bytes)),
        );
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Sakhi Sahayak",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      // FIXED: SizedBox.expand forces full width centering
      body: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Spacer(),

            // 1. APP LOGO (Your Custom Image, Centered)
            Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, 10))
              ]),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (c, o, s) =>
                      Icon(Icons.woman, size: 100, color: Colors.purple),
                ),
              ),
            ),

            SizedBox(height: 30),

            Text(
              _isRecording ? "Listening..." : _statusText,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _isRecording ? Colors.red : Colors.black87),
            ),

            Spacer(),

            // 2. MIC BUTTON (Standard Default Icon, Centered)
            GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopRecording(),
              child: Container(
                height: 90,
                width: 90,
                decoration: BoxDecoration(
                    color: _isRecording ? Colors.red : Colors.purple,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: (_isRecording ? Colors.red : Colors.purple)
                              .withOpacity(0.4),
                          blurRadius: 15,
                          offset: Offset(0, 5))
                    ]),
                child: Icon(Icons.mic, size: 45, color: Colors.white),
              ),
            ),

            SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Hold to Speak",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ),

            SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
