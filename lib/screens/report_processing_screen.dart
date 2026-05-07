import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/report_storage_service.dart';

class ReportProcessingScreen extends StatefulWidget {
  final String text;

  const ReportProcessingScreen({required this.text, Key? key})
      : super(key: key);

  @override
  _ReportProcessingScreenState createState() => _ReportProcessingScreenState();
}

class _ReportProcessingScreenState extends State<ReportProcessingScreen> {
  bool _saved = false;
  String _locationInfo = "Fetching location...";

  @override
  void initState() {
    super.initState();
    _saveReportWithLocation();
  }

  Future<void> _saveReportWithLocation() async {
    Position? position;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
      }
    } catch (e) {
      print("Location error: $e");
    }

    final locString = position != null
        ? "${position.latitude}, ${position.longitude}"
        : "Unknown Location";

    if (mounted) {
      setState(() => _locationInfo = locString);
    }

    final report = {
      "timestamp": DateTime.now().toIso8601String(),
      "content": widget.text,
      "location": locString,
      "status": "pending_upload"
    };

    await ReportStorageService.saveReport(report);

    if (mounted) {
      setState(() => _saved = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[50],
      appBar: AppBar(
        title: Text("Incident Report"),
        backgroundColor: Colors.red[800],
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_clock, size: 80, color: Colors.red[800]),
            SizedBox(height: 24),
            Text(
              _saved ? "Report Secured" : "Saving...",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              "Your report and location have been saved securely on this device. They can be reviewed later when needed.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
            ),
            SizedBox(height: 30),
            Container(
              padding: EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("DETAILS:",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey)),
                  Text(widget.text, style: TextStyle(fontSize: 16)),
                  SizedBox(height: 10),
                  Text("LOCATION:",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey)),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.red),
                      SizedBox(width: 4),
                      Text(_locationInfo,
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[800],
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
              child: Text("Return Home", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}
