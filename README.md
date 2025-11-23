# **Sakhi Sahayak — Offline AI Village Assistant**

**Team:** Git It Done
**Version:** 1.0

Sakhi Sahayak is an offline, privacy-first AI assistant designed for rural and low-connectivity regions. It performs speech-to-text, intent detection, task simplification, and text-to-speech entirely on the device using on-device inference (Whisper, LLaMA, and offline TTS).

This README provides complete setup instructions, architecture explanation, project flow, and developer notes.

---

# 1. Overview

Sakhi Sahayak solves a key challenge in rural India:
Providing accurate, accessible, low-literacy-friendly digital assistance **without requiring internet access**.

Features include:

* Offline speech recognition using Whisper
* Intent detection for Assist vs Report mode
* Local LLaMA inference for step-by-step task simplification
* Pictogram-based visual guidance
* Offline text-to-speech
* No cloud services or external APIs

The full AI pipeline runs entirely on-device.

---

# 2. Project Structure

```
lib/
  main.dart
  whisper_test_page.dart
  platform/
    sakhi_platform.dart
    sakhi_platform_android.dart
    sakhi_platform_windows.dart
  services/
    audio_service.dart
    model_manager.dart
    pictogram_mapper.dart
    intent_detector.dart
  screens/
    assist_processing_screen.dart
    assist_result_screen.dart
    report_processing_screen.dart

android/
  app/src/main/kotlin/com/sakhi/
      MainActivity.kt
      SakhiPlugin.kt
      STTEngine.kt
      LLMRunner.kt
      TTSEngine.kt
```

---

# 3. Technology Stack

### Flutter

* Flutter 3.38.1
* Provider for state management

### Native Android (Kotlin)

* Custom MethodChannel plugin
* AudioRecord for reliable PCM capture
* JNI bindings for:

  * Whisper STT
  * LLaMA 1B Q4
  * Offline TTS

### ML Models

* Whisper Tiny Q8 (quantized STT model)
* LLaMA 1B Q4 (quantized text simplification model)
* Offline TTS

All models run fully on-device.

---

# 4. Installing & Running the Project

## 4.1 Prerequisites

1. Flutter 3.38.x installed
2. Android SDK (API 33+)
3. 4GB RAM device recommended
4. Model files placed in:

```
assets/models/
    whisper_tiny_q8.bin
    llama_1b_q4.gguf
```

Ensure `pubspec.yaml` contains:

```
flutter:
  assets:
    - assets/models/
```

---

## 4.2 Setup Instructions

### Step 1 — Install dependencies

```
flutter pub get
```

### Step 2 — Clean build artifacts

```
flutter clean
```

### Step 3 — Build APK

```
flutter build apk --release
```

### Step 4 — Install on device

```
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Step 5 — Run app from device

The models will be copied into internal storage at first launch.

---

# 5. Main Components Explained

## 5.1 Audio Recorder (Native)

Implemented using Android AudioRecord for reliability.

* PCM16
* 16000 Hz
* Mono
* Low-latency
* Works across Samsung, Xiaomi, Motorola, etc.

Data is sent to Flutter as raw bytes for STT.

---

## 5.2 Whisper STT Engine

Located in:

```
android/app/src/main/kotlin/com/sakhi/STTEngine.kt
```

Pipeline:

1. Load Whisper model (nativeLoadModel)
2. Convert PCM16 → Float32
3. Run inference through JNI
4. Return transcribed text to Flutter

Whisper runs entirely offline.

---

## 5.3 Intent Detection

Located in:

```
lib/services/intent_detector.dart
```

Detects:

* Assist Query
* Report Intent
* Noise / Gibberish

Uses lightweight semantic similarity and thresholds.

---

## 5.4 LLaMA 1B Q4 Simplifier

Located in:

```
android/app/src/main/kotlin/com/sakhi/LLMRunner.kt
```

Runs on-device using quantized model.

Responsibilities:

* Convert complex task queries into short actionable steps
* Avoid hallucination
* Enforce strict output format (3–4 steps)
* Improve readability

---

## 5.5 TTS Engine

Located in:

```
android/app/src/main/kotlin/com/sakhi/TTSEngine.kt
```

Converts simplified steps into speech offline.

---

## 5.6 ModelManager

Handles copying large model files on background thread to avoid UI blocking.

---

# 6. Application Flow (End-to-End)

```
Press & Hold Record Button
        ↓
Native AudioRecord captures PCM16 audio
        ↓
Whisper STT (JNI) converts speech → text
        ↓
Intent Detector (Dart)
        ↓
├─ Assist → LLaMA Simplifier → Pictogram UI → TTS Output
└─ Report → Incident Report Screen
```

The entire pipeline runs offline.

---

# 7. Screens Overview

## 7.1 Assist Processing Screen

* Receives STT output
* Runs intent detection
* Runs LLaMA simplifier
* Maps steps to pictograms

## 7.2 Assist Result Screen

Displays simplified steps and icons.

## 7.3 Report Processing Screen

Triggered when intent confidence indicates a safety or incident report.

---

# 8. Storage & Data Model

### Model Storage

```
/data/data/com.sakhi/files/models/
```

### Cached Data Structure

```
{
  query: string,
  response: string,
  lastUpdated: timestamp
}
```

No data leaves the device.

---

# 9. Security & Privacy

* Zero cloud usage
* Zero external API calls
* Audio only recorded on user action (press & hold)
* All processing stored locally
* No user data transmitted
* Complies with privacy-first architecture principles

---

# 10. Scalability

### Works offline at scale because:

* No servers
* No backend infrastructure
* No network requirements
* No cloud inference

### Device Requirements

* 4GB RAM recommended
* ARM64 preferred

---

# 11. Troubleshooting

### Issue: App crashes at startup

Cause: Heavy model copying on main thread
Fix: Move model copy to background thread (ModelManager)

### Issue: Audio returns 0 bytes

Fix: Use Native AudioRecord instead of Flutter plugin.
Ensure microphone permissions are granted.

### Issue: Whisper model not loading

Check that `whisper_tiny_q8.bin` exists in:

```
assets/models/
```

---

# 12. Future Enhancements

1. Multi-language support (Hindi, Kannada, Telugu, Tamil)
2. Mini-RAG (keyword-based document retrieval)
3. Advanced reporting workflow
4. Model compression & optimizations
5. Optional cloud sync for NGO deployments

---

# 13. Build Commands Summary

```
flutter clean
flutter pub get
flutter build apk --release
adb install app-release.apk
```

---

# 14. Contact

For support or collaboration:
Team Git It Done
