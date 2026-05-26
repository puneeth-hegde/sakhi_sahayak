# Sakhi Sahayak

Offline AI Village Assistant built by Team Git It Done for a hackathon prototype that reached the semifinals. The project was designed for rural and low-connectivity settings, where users need practical voice-driven help without depending on cloud services. The core idea remains the same: keep the entire experience on-device, private, and usable on low-end Android phones.

## What the app does

Sakhi Sahayak is an offline assistant that can:
- record speech on demand,
- transcribe audio locally,
- detect whether a request is general help or an emergency/report,
- retrieve grounded knowledge from local JSON documents,
- simplify answers into clear steps,
- speak the response back to the user,
- save incident reports securely on the device.

The app is intended for everyday village use cases such as government schemes, health guidance, agriculture basics, and incident reporting.

## Current capabilities

### Assist mode
The app listens to a spoken request, converts it to text, searches the local knowledge base, and passes the retrieved context into the on-device language model for a short, practical response.

### Report mode
If the request looks like a safety or incident report, the app routes to the report flow, stores the report locally with secure device storage, and keeps the data offline.

### Retrieval stack
The retrieval pipeline uses two layers:
- keyword matching for fast exact or near-exact lookup,
- offline vector fallback for semantic matching when the keyword path is weak.

### Offline embeddings
The query embedding and the stored chunk vectors use the same fully offline deterministic encoder. This keeps the app self-contained and avoids any server dependency.

## Hackathon history

This project started as a hackathon team effort by Team Git It Done. The prototype made it to the second round and reached the semifinals. It did not advance to the finals, but it proved that a practical offline assistant for rural users was feasible.

That context still matters here: the app is still being shaped as a field-ready prototype, but it is now substantially more grounded and useful than the early version.

## How the app works

1. The user presses and holds the microphone button.
2. Native audio capture records speech.
3. Whisper converts speech to text locally.
4. Intent detection decides whether the request is assist or report.
5. Assist requests are routed through the local knowledge retrieval stack.
6. Retrieved chunks are passed to the on-device LLM for grounded output.
7. The result is shown as step cards and spoken back to the user.
8. Report requests are saved securely on-device for later review.

## Knowledge base

The knowledge base is stored as JSON documents under `assets/knowledge/documents/` and indexed through `assets/knowledge/documents/index.json`.

The vector index is stored in:
- `assets/knowledge/vectors.json`

The current KB focuses on practical rural topics such as:
- health and first-response guidance,
- government schemes and welfare support,
- agriculture and seasonal crop information,
- basic sanitation and nutrition topics.

## Security and privacy

- No cloud inference.
- No external API calls.
- No user audio sent to a server.
- Reports are stored locally using secure device storage.
- Large model files are handled separately from normal source files.

## Limitations & Known Issues

- **Generative Hallucination on Edge Models**: The app runs a highly quantized LLaMA model natively on-device to ensure it works entirely offline. While semantic retrieval (RAG) accurately identifies the correct knowledge base chunk, the tiny generative model (<3B parameters) may occasionally hallucinate statistics or fail to strictly follow formatting instructions in its response. For critical medical or emergency information, the app relies heavily on a hardcoded keyword cache (`verifiedResponses` in `LLMRunner.kt`) rather than pure generation to guarantee safety.

## Models bundled with the app

The app includes offline model assets for speech recognition and answer generation. These files are large, so the repository uses Git LFS rules for the binary model formats.

## Build and run

### Prerequisites
- Flutter SDK installed
- Android SDK installed
- Android device or emulator
- Sufficient free storage for the model assets

### Platform notes

**Windows build caveat:** This repository uses symlinks for native C++ sources (e.g., `whisper.cpp` linking to the vendored source in `android/native/third_party/whisper_cpp/`). Symlinks are portable in Git on Linux and macOS, but may not resolve correctly on Windows without additional configuration. If building on Windows, ensure your Git is configured to support symlinks (`git config core.symlinks true`), or consider using WSL2.

### Build release APK

```bash
flutter pub get
flutter build apk --release
```

### Install on a device

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

## Repository layout

- `lib/` - Flutter app code
- `android/` - Android native code and JNI bindings
- `assets/knowledge/` - local knowledge base and vector index
- `assets/models/` - offline model assets
- `assets/scripts/` - local generation and validation scripts

## Release notes

The current release emphasizes:
- fully offline operation,
- grounded retrieval from a curated local KB,
- emergency report handling,
- secure local report storage,
- production release packaging.

## Team

Team Git It Done

## Contact

This repository is maintained as part of the Sakhi Sahayak hackathon project.
