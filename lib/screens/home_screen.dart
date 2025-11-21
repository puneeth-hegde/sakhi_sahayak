// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../whisper_test_page.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => WhisperTestPage()),
            );
          },
          child: const Text('Open Whisper Test'),
        ),
      ),
    );
  }
}
