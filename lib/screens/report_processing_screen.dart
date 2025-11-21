import 'package:flutter/material.dart';

class ReportProcessingScreen extends StatelessWidget {
  final String text;

  const ReportProcessingScreen({required this.text, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[50],
      appBar: AppBar(title: Text("Report Mode"), backgroundColor: Colors.red),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Incident Report (Placeholder)",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.red[900],
              ),
            ),
            SizedBox(height: 20),
            Text(
              "Detected Text:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Text(text, style: TextStyle(fontSize: 16)),
            ),
            SizedBox(height: 30),
            Center(
              child: Text(
                "⚠️ Full report submission will be added in Phase 4.\n"
                "For now, routing and detection are being tested.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.red[800]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
