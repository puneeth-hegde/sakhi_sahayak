// lib/platform/whisper_ffi.dart

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart'; // provides Utf8 extensions, malloc, calloc

// Native typedefs
typedef wb_load_whisper_fn = Int32 Function(Pointer<Utf8>);
typedef wb_load_whisper = int Function(Pointer<Utf8>);

typedef wb_init_model_fn = Int32 Function(Pointer<Utf8>);
typedef wb_init_model = int Function(Pointer<Utf8>);

typedef wb_transcribe_fn = Pointer<Utf8> Function(Pointer<Utf8>);
typedef wb_transcribe = Pointer<Utf8> Function(Pointer<Utf8>);

typedef wb_free_text_fn = Void Function(Pointer<Utf8>);
typedef wb_free_text = void Function(Pointer<Utf8>);

class WhisperFFI {
  late DynamicLibrary _lib;

  late wb_load_whisper _loadWhisper;
  late wb_init_model _initModel;
  late wb_transcribe _transcribe;
  late wb_free_text _freeText;

  bool initialized = false;

  WhisperFFI([String? dllPath]) {
    final computedPath =
        dllPath ??
        '${Directory.current.path}\\windows\\sakhi_native\\whisper_bridge.dll';

    try {
      _lib = DynamicLibrary.open(computedPath);
    } catch (e) {
      throw Exception(
        'Failed to open Whisper bridge DLL at "$computedPath": $e',
      );
    }

    try {
      _loadWhisper = _lib
          .lookup<NativeFunction<wb_load_whisper_fn>>('wb_load_whisper')
          .asFunction();

      _initModel = _lib
          .lookup<NativeFunction<wb_init_model_fn>>('wb_init_model')
          .asFunction();

      _transcribe = _lib
          .lookup<NativeFunction<wb_transcribe_fn>>('wb_transcribe')
          .asFunction();

      _freeText = _lib
          .lookup<NativeFunction<wb_free_text_fn>>('wb_free_text')
          .asFunction();
    } catch (e) {
      throw Exception(
        'Failed to lookup required symbols in whisper_bridge.dll: $e',
      );
    }
  }

  /// Initialize the bridge and model.
  /// whisperDll = path to whisper native dll (if your bridge needs it)
  /// modelPath = path to the model file (eg whisper_tiny_q8.bin)
  Future<bool> initialize(String whisperDll, String modelPath) async {
    final dllC = whisperDll.toNativeUtf8();
    final modelC = modelPath.toNativeUtf8();

    try {
      final r1 = _loadWhisper(dllC);
      final r2 = _initModel(modelC);

      initialized = (r1 == 1) && (r2 == 1);
      return initialized;
    } finally {
      // free native strings
      malloc.free(dllC);
      malloc.free(modelC);
    }
  }

  /// Transcribe a wav file path and return text (or null on failure)
  Future<String?> transcribe(String wavPath) async {
    if (!initialized) {
      throw Exception('WhisperFFI not initialized. Call initialize() first.');
    }

    final wavC = wavPath.toNativeUtf8();
    try {
      final resPtr = _transcribe(wavC);
      if (resPtr.address == 0) return null;

      final text = resPtr.toDartString();
      _freeText(resPtr);
      return text;
    } finally {
      malloc.free(wavC);
    }
  }
}
