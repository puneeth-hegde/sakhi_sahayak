import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'utils/permissions.dart';
import 'platform/sakhi_platform.dart';
import 'platform/sakhi_platform_channel.dart';

import 'screens/home_screen.dart';
import 'whisper_test_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FIXED: Removed heavy blocking calls (ModelManager.prepareModels & platform.initialize)
  // from here. These caused the "Skipped frames" and ANR crash.
  // You must now trigger these from a button or loading screen in your UI.

  // Request permissions early if needed, but ideally this should also be in the UI
  await Permissions.ensureMicPermission();

  final SakhiPlatform platform = SakhiMethodChannel();

  runApp(
    MultiProvider(
      providers: [Provider<SakhiPlatform>.value(value: platform)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Platform.isAndroid ? WhisperTestPage() : HomeScreen(),
      ),
    ),
  );
}
