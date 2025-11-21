import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../platform/sakhi_platform.dart';
import '../services/pictogram_mapper.dart';
import '../services/intent_detector.dart';
import 'assist_result_screen.dart';
import 'report_processing_screen.dart'; // required for routing

class AssistProcessingScreen extends StatefulWidget {
  final Uint8List audioData;

  AssistProcessingScreen({required this.audioData});

  @override
  State<AssistProcessingScreen> createState() => _AssistProcessingScreenState();
}

class _AssistProcessingScreenState extends State<AssistProcessingScreen> {
  String status = "Processing...";
  final mapper = PictogramMapper();
  final intentDetector = IntentDetector(reportThreshold: 0.6);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _process);
  }

  Future<void> _process() async {
    final platform = Provider.of<SakhiPlatform>(context, listen: false);

    // 1. SPEECH RECOGNITION
    setState(() => status = "Recognizing speech...");
    final text = await platform.transcribeAudio(widget.audioData);

    if (text == null || text.trim().isEmpty) {
      _error("Couldn't understand your audio.");
      return;
    }

    // 2. INTENT DETECTION
    setState(() => status = "Identifying intent...");
    final intent = await intentDetector.detectIntent(text);

    // -----------------------------------------
    // CASE A: HIGH CONFIDENCE REPORT → DIRECT ROUTE
    // -----------------------------------------
    if (intent.intent == IntentType.report && intent.confidence >= 0.7) {
      _goToReport(text);
      return;
    }

    // -----------------------------------------
    // CASE B: BORDERLINE REPORT → ASK CONFIRMATION
    // -----------------------------------------
    if (intent.intent == IntentType.report &&
        intent.confidence >= 0.4 &&
        intent.confidence < 0.7) {
      final goReport = await _confirmReport();
      if (goReport == true) {
        _goToReport(text);
        return;
      }
      // Else continue with assist
    }

    // -----------------------------------------
    // CASE C: ASSIST MODE → NORMAL FLOW
    // -----------------------------------------
    setState(() => status = "Understanding...");
    final prefs = {
      "preferred_step_count": 3,
      "preferred_sentence_length": "short",
    };

    final result = await platform.simplifyText(text, prefs);

    if (result == null || result['steps'] == null) {
      _error("Couldn't process your request.");
      return;
    }

    // Convert steps into cards
    final cards = mapper.mapStepsToCards(result['steps']);

    // Navigate to result screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AssistResultScreen(cards: cards)),
    );
  }

  // -----------------------------------------
  // ROUTING TO REPORT MODE
  // -----------------------------------------
  void _goToReport(String text) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ReportProcessingScreen(text: text)),
    );
  }

  // -----------------------------------------
  // CONFIRMATION DIALOG FOR BORDERLINE CASES
  // -----------------------------------------
  Future<bool?> _confirmReport() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Possible Incident Report"),
        content: Text(
          "It sounds like you may be trying to report an incident.\n\n"
          "Do you want to switch to Report Mode?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("No"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Yes"),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------
  // ERROR HANDLING POPUP
  // -----------------------------------------
  void _error(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Error"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------
  // UI
  // -----------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purple[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.purple),
            SizedBox(height: 16),
            Text(status, style: TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }
}
