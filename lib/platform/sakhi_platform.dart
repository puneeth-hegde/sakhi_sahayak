import 'dart:typed_data';

/// Base interface for platform-specific implementations.
/// Android will use MethodChannel.
/// Windows will use FFI or mock implementation.
abstract class SakhiPlatform {
  Future<bool> initialize();

  Future<String?> transcribeAudio(Uint8List audioBytes);

  Future<Map<String, dynamic>?> simplifyText(
    String text,
    Map<String, dynamic> prefs,
  );

  Future<void> speakText(String text, double speed);
}
