#!/usr/bin/env python3
"""Generate offline semantic vectors for the Sakhi Sahayak KB.

This script uses the same deterministic encoder as the Flutter runtime, so the
vector index and runtime query vectors are guaranteed to share the same space.
"""

from __future__ import annotations

import json
from pathlib import Path

from offline_semantic_encoder import DIMENSION, encode_text


def _load_json(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _chunk_text(chunk: dict) -> str:
    title = chunk.get("title") or chunk.get("name") or ""
    content = chunk.get("content") or chunk.get("text") or ""
    return f"{title}. {content}".strip()


def generate_vectors() -> bool:
    print("=" * 70)
    print("Sakhi Sahayak: Offline Vector Generator")
    print("=" * 70)

    base_dir = Path("/home/puneeth/projects/sakhi_sahayak")
    kb_dir = base_dir / "assets" / "knowledge" / "documents"
    index_file = kb_dir / "index.json"
    output_file = base_dir / "assets" / "knowledge" / "vectors.json"

    print(f"\n[Step 1/4] Loading index: {index_file}")
    if not index_file.exists():
        print("ERROR: index.json not found")
        return False

    index_data = _load_json(index_file)
    doc_paths = index_data.get("documents", []) if isinstance(index_data, dict) else []
    print(f"  Found {len(doc_paths)} documents")

    print("\n[Step 2/4] Loading KB chunks...")
    all_entries = []
    for doc_rel_path in doc_paths:
        doc_path = kb_dir / doc_rel_path
        if not doc_path.exists():
            print(f"  - missing: {doc_rel_path}")
            continue

        try:
            doc_data = _load_json(doc_path)
            chunks = doc_data.get("chunks", []) if isinstance(doc_data, dict) else []
            loaded = 0
            for chunk in chunks:
                chunk_id = chunk.get("chunk_id") or chunk.get("id")
                title = chunk.get("title") or ""
                keywords = chunk.get("keywords") or []
                text = _chunk_text(chunk)
                if not chunk_id or not text:
                    continue
                all_entries.append(
                    {
                        "chunk_id": chunk_id,
                        "document": doc_rel_path,
                        "title": title,
                        "text": text,
                        "keywords": keywords,
                    }
                )
                loaded += 1
            print(f"  + {doc_rel_path}: {loaded} chunks")
        except Exception as exc:
            print(f"  x {doc_rel_path}: {exc}")

    if not all_entries:
        print("ERROR: no chunks found")
        return False

    print(f"\n[Step 3/4] Encoding {len(all_entries)} chunks with offline semantic encoder...")
    vectors = []
    for entry in all_entries:
        vector = encode_text(entry["text"], title=entry["title"], keywords=entry["keywords"])
        vectors.append(vector)

    print("\n[Step 4/4] Writing vectors.json...")
    vectors_data = {
        "model": "hashed-semantic-encoder-v1",
        "embedding_dim": DIMENSION,
        "num_chunks": len(all_entries),
        "chunks": [],
    }

    for entry, vector in zip(all_entries, vectors):
        vectors_data["chunks"].append(
            {
                "chunk_id": entry["chunk_id"],
                "document": entry["document"],
                "title": entry["title"],
                "vector": vector,
            }
        )

    with output_file.open("w", encoding="utf-8") as handle:
        json.dump(vectors_data, handle, indent=2)

    size_kb = output_file.stat().st_size / 1024.0
    print(f"  Wrote {output_file} ({size_kb:.1f} KB)")
    print("=" * 70)
    print(f"Generated vectors for {len(all_entries)} chunks")
    print("Next: run `uv run python test.py` and `flutter build apk --release`")
    print("=" * 70)
    return True


if __name__ == "__main__":
    raise SystemExit(0 if generate_vectors() else 1)
