import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'utils/permissions.dart';

import 'platform/sakhi_platform.dart';
import 'platform/sakhi_platform_android.dart';
import 'platform/sakhi_platform_windows.dart';

import 'services/model_manager.dart';
import 'screens/home_screen.dart';
import 'whisper_test_page.dart'; // <-- added

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permissions.ensureMicPermission();

  // Copy models from assets → internal storage
  await ModelManager.prepareModels();

  // Select correct platform (Windows or Android)
  final SakhiPlatform platform = _selectPlatform();

  // Initialize selected platform
  await platform.initialize();

  runApp(
    MultiProvider(
      providers: [Provider<SakhiPlatform>.value(value: platform)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,

        // TEMPORARY: Show Whisper Test UI ONLY on Android
        // After Whisper is verified, switch back to HomeScreen()
        home: Platform.isAndroid ? WhisperTestPage() : HomeScreen(),
      ),
    ),
  );
}

SakhiPlatform _selectPlatform() {
  if (Platform.isWindows) {
    print("Running on Windows → using SakhiPlatformWindows");
    return SakhiPlatformWindows();
  } else if (Platform.isAndroid) {
    print("Running on Android → using SakhiPlatformAndroid");
    return SakhiPlatformAndroid();
  } else {
    throw UnsupportedError("Unsupported platform for SakhiPlatform");
  }
}
