"""Deterministic offline semantic encoder shared by the vector generator and test script.

This encoder is intentionally simple and fully offline:
- Normalize text
- Tokenize words
- Add stems, synonyms, title/keyword boosts, bigrams, and character trigrams
- Hash features into a fixed 768-dim vector using FNV-1a
- L2 normalize and quantize to int8

The same feature rules are mirrored in Dart so runtime query vectors live in the same space
as the precomputed vectors.json file.
"""

from __future__ import annotations

import math
import re
import unicodedata
from collections import defaultdict
from typing import Iterable, List, Sequence

DIMENSION = 768

TOKEN_RE = re.compile(r"[a-z0-9]+")

STOPWORDS = {
    "a", "an", "and", "are", "as", "at", "be", "by", "for", "from", "have",
    "has", "in", "is", "it", "of", "on", "or", "that", "the", "their", "this",
    "to", "was", "were", "will", "with", "you", "your", "i", "we", "they", "them",
    "me", "my", "our", "us", "can", "could", "should", "would", "do", "does", "did",
    "not", "no", "yes", "if", "then", "than", "there", "here", "what", "when",
    "where", "how", "why", "which",
}

SYNONYMS = {
    "scheme": ["yojana", "yojna", "program", "plan"],
    "apply": ["register", "registration", "application"],
    "register": ["apply", "registration", "enroll"],
    "free": ["zero", "no-cost", "without-payment"],
    "health": ["medical", "hospital", "clinic"],
    "hospital": ["clinic", "medical", "health"],
    "insurance": ["coverage", "protection", "benefit"],
    "treatment": ["care", "medicine", "therapy"],
    "medicine": ["drug", "treatment", "care"],
    "fever": ["bukhar", "jvar"],
    "cough": ["khansi"],
    "pain": ["dard"],
    "help": ["support", "assistance", "madad"],
    "police": ["thana", "law"],
    "woman": ["women", "female"],
    "child": ["children", "kid", "baby"],
    "pregnant": ["pregnancy", "mother"],
    "government": ["sarkar", "govt"],
    "benefit": ["subsidy", "support", "aid"],
    "income": ["money", "earnings"],
    "job": ["work", "employment"],
    "water": ["drinking-water", "safe-water"],
    "sanitation": ["toilet", "hygiene"],
}


def _normalize_text(text: str) -> str:
    text = unicodedata.normalize("NFKD", text)
    text = text.encode("ascii", "ignore").decode("ascii")
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def _stem(token: str) -> str:
    if len(token) <= 4:
        return token
    for suffix in ("ing", "ed", "es", "s"):
        if token.endswith(suffix) and len(token) - len(suffix) >= 3:
            return token[: -len(suffix)]
    return token


def _tokenize(text: str) -> List[str]:
    normalized = _normalize_text(text)
    if not normalized:
        return []
    return [token for token in TOKEN_RE.findall(normalized) if token and token not in STOPWORDS]


def _fnv1a32(data: str) -> int:
    value = 0x811C9DC5
    for byte in data.encode("utf-8"):
        value ^= byte
        value = (value * 0x01000193) & 0xFFFFFFFF
    return value


def _add_feature(vector: List[float], feature: str, weight: float) -> None:
    hash_value = _fnv1a32(feature)
    index = hash_value % DIMENSION
    sign = 1.0 if (hash_value & 1) == 0 else -1.0
    vector[index] += weight * sign


def _char_ngrams(token: str, n: int = 3) -> Sequence[str]:
    if len(token) < n:
        return ()
    return tuple(token[i : i + n] for i in range(len(token) - n + 1))


def build_features(
    text: str,
    title: str | None = None,
    keywords: Iterable[str] | None = None,
) -> List[float]:
    vector = [0.0] * DIMENSION

    def add_token_features(tokens: Sequence[str], base_weight: float) -> None:
        for index, token in enumerate(tokens):
            if not token:
                continue
            base = _stem(token)
            _add_feature(vector, f"tok:{base}", base_weight)
            if base != token:
                _add_feature(vector, f"stem:{base}", base_weight * 0.85)

            for synonym in SYNONYMS.get(base, ()):
                _add_feature(vector, f"syn:{synonym}", base_weight * 0.7)

            for gram in _char_ngrams(base):
                _add_feature(vector, f"tri:{gram}", base_weight * 0.22)

            if index + 1 < len(tokens):
                bigram = f"{base}_{_stem(tokens[index + 1])}"
                _add_feature(vector, f"bi:{bigram}", base_weight * 1.15)

    content_tokens = _tokenize(text)
    title_tokens = _tokenize(title or "")
    keyword_tokens = [_stem(token) for token in (keywords or ()) if token]

    add_token_features(content_tokens, 1.0)
    add_token_features(title_tokens, 1.35)
    add_token_features(keyword_tokens, 1.75)

    combined = content_tokens + title_tokens + keyword_tokens
    for index, token in enumerate(combined[:32]):
        _add_feature(vector, f"pos:{index}:{token}", 0.18)

    # Normalize and quantize later.
    return vector


def encode_text(text: str, title: str | None = None, keywords: Iterable[str] | None = None) -> List[int]:
    vector = build_features(text, title=title, keywords=keywords)
    norm = math.sqrt(sum(value * value for value in vector))
    if norm == 0:
        return [0] * DIMENSION
    quantized = []
    for value in vector:
        scaled = int(round((value / norm) * 127.0))
        if scaled < -128:
            scaled = -128
        elif scaled > 127:
            scaled = 127
        quantized.append(scaled)
    return quantized


def encode_text_float(text: str, title: str | None = None, keywords: Iterable[str] | None = None) -> List[float]:
    vector = build_features(text, title=title, keywords=keywords)
    norm = math.sqrt(sum(value * value for value in vector))
    if norm == 0:
        return [0.0] * DIMENSION
    return [value / norm for value in vector]
