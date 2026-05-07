ONNX/TFLite Conversion Notes
=============================

This folder contains a starter script `convert_sbert_to_onnx.py` to export the transformer backbone to ONNX.

Recommended pipeline for on-device encoder (fully offline):

1. Export transformer backbone to ONNX (this repo script).
2. Implement pooling (mean pooling over token embeddings) and normalization (L2) on-device in Dart or as a small native wrapper.
3. Optionally quantize the ONNX model (ONNX quantization) to reduce size and speed up inference.
4. Convert ONNX → TFLite if you prefer `tflite_flutter` plugin (use onnx-tensorflow then tflite converter), or use `onnxruntime-mobile` via platform channels.

Performance tips:
- Use int8 quantization for the encoder where possible.
- Use smaller models (DistilBERT) to reduce size; evaluate quality tradeoff.
- Pre-warm model on app start to avoid first-query latency spikes.

Limitations:
- Exporting full SBERT (which includes pooling) may require implementing pooling logic separately.
- Testing on-device numeric parity is necessary; quantization can alter similarity scores slightly.

If you want, I can:
- Run the conversion steps and provide the exported ONNX and sample Dart integration code (requires running on your machine), or
- Produce a complete integration branch with `tflite_flutter` usage and pooling implemented in Dart.
