"""
Export a sentence-transformers model to ONNX for on-device inference.

Usage (run inside your project venv):
  pip install transformers sentence-transformers torch onnx onnxruntime

Then run:
  python assets/scripts/convert_sbert_to_onnx.py --model distilbert-base-uncased --output assets/models/encoder.onnx

Notes:
- This script exports the transformer encoder portion to ONNX. For full SBERT pooling (mean pooling), the exported model may need a small wrapper or implement pooling in Dart/native.
- After ONNX export you can further convert to TFLite via ONNX->TFLite conversion tools or use onnxruntime mobile. TFLite conversion may require float32 and quantization steps.

This is a starter script — test and adjust for your specific model and pooling strategy.
"""
import argparse
from pathlib import Path
import torch
from sentence_transformers import SentenceTransformer


def export_to_onnx(model_name: str, output_path: str):
    model = SentenceTransformer(model_name)
    model.eval()

    # Create a dummy input (token ids) using the tokenizer
    tokenizer = model.tokenizer
    sample_text = "This is a sample input for ONNX export."
    inputs = tokenizer(sample_text, return_tensors='pt')

    # The sentence-transformers model wraps a transformer; find its transformer module
    transformer = model._first_module()

    output_dir = Path(output_path).parent
    output_dir.mkdir(parents=True, exist_ok=True)

    onnx_path = Path(output_path)
    # Export using torch.onnx
    torch.onnx.export(
        transformer,
        (inputs['input_ids'], inputs.get('attention_mask', None)),
        str(onnx_path),
        input_names=['input_ids', 'attention_mask'],
        output_names=['last_hidden_state'],
        opset_version=13,
        do_constant_folding=True,
        dynamic_axes={
            'input_ids': {0: 'batch_size', 1: 'sequence'},
            'attention_mask': {0: 'batch_size', 1: 'sequence'},
            'last_hidden_state': {0: 'batch_size', 1: 'sequence'},
        },
    )

    print(f'Exported ONNX model to {onnx_path}')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--model', default='distilbert-base-uncased')
    parser.add_argument('--output', default='assets/models/encoder.onnx')
    args = parser.parse_args()
    export_to_onnx(args.model, args.output)


if __name__ == '__main__':
    main()
