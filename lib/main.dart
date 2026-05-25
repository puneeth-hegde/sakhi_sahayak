import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'platform/sakhi_platform.dart';
import 'platform/sakhi_platform_channel.dart';
import 'screens/home_screen.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('Global Flutter Error: ${details.exceptionAsString()}');
    };

    final SakhiPlatform platform = SakhiMethodChannel();

    runApp(
      MultiProvider(
        providers: [Provider<SakhiPlatform>.value(value: platform)],
        child: MaterialApp(
          title: 'Sakhi Sahayak',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(primarySwatch: Colors.purple, fontFamily: 'Roboto'),
          home: HomeScreen(),
        ),
      ),
    );
  }, (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
  });
}
