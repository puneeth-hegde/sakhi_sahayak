import 'package:permission_handler/permission_handler.dart';

class Permissions {
  /// Ensures microphone permission exists before recording.
  static Future<bool> ensureMicPermission() async {
    final status = await Permission.microphone.status;

    if (status.isGranted) {
      return true;
    }

    // Request permission if not granted yet
    final result = await Permission.microphone.request();
    return result.isGranted;
  }
}
