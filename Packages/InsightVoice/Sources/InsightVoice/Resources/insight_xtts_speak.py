#!/usr/bin/env python3
"""Synthesize speech with Coqui XTTS v2 for Insight (macOS local runtime)."""

from __future__ import annotations

import argparse
import json
import os
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description="Insight XTTS local speech synthesis")
    parser.add_argument("--json", help="JSON payload with text, speaker_wav, output_wav, language, speed")
    parser.add_argument("--text", default="")
    parser.add_argument("--speaker-wav", default="")
    parser.add_argument("--output-wav", default="")
    parser.add_argument("--language", default="en")
    parser.add_argument("--speed", type=float, default=1.0)
    args = parser.parse_args()

    if args.json:
        payload = json.loads(args.json)
        text = payload["text"]
        speaker_wav = payload["speaker_wav"]
        output_wav = payload["output_wav"]
        language = payload.get("language", "en")
        speed = float(payload.get("speed", 1.0))
    else:
        text = args.text
        speaker_wav = args.speaker_wav
        output_wav = args.output_wav
        language = args.language
        speed = args.speed

    if not text.strip():
        print("error: empty text", file=sys.stderr)
        return 2
    if not os.path.exists(speaker_wav):
        print(f"error: missing speaker wav at {speaker_wav}", file=sys.stderr)
        return 3

    os.environ.setdefault("COQUI_TOS_AGREED", "1")
    os.environ.setdefault("PYTORCH_ENABLE_MPS_FALLBACK", "1")

    try:
        import torch
        from TTS.api import TTS
    except ImportError as exc:
        print(
            "error: coqui-tts is not installed. Run: pip install torch coqui-tts",
            file=sys.stderr,
        )
        print(str(exc), file=sys.stderr)
        return 4

    device = "cpu"
    if torch.backends.mps.is_available():
        device = "mps"

    tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2").to(device)
    tts.tts_to_file(
        text=text,
        speaker_wav=speaker_wav,
        language=language,
        file_path=output_wav,
        speed=speed,
    )
    print(output_wav)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
