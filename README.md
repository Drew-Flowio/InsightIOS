# InsightIOS

Offline-first iPhone assistant built in SwiftUI. On-device LLM (llama.cpp), whisper.cpp speech-to-text, local Expert Packs (Minds), and a photo-question workflow. Local voice synthesis on macOS (Coqui XTTS).

This repo is **standalone** — it is not part of Task Torch.

## Product docs

- **[Vision layer requirement](./docs/VISION_LAYER.md)** — true visual reasoning is core product; v1.6 OCR bridge vs future VLM path; target pipeline; evaluation milestone
- **[Backlog](./docs/BACKLOG.md)** — near-term roadmap (vision eval, Mind polish, out-of-scope)

## Open in Xcode

```bash
open InsightIOS.xcodeproj
```

## First-run model download

Launch the app on a device or simulator. The setup overlay downloads:

- Offgrid Minds offline assistant (Phi-4 on supported iPhones, compact fallback on low-memory devices)
- whisper.cpp `ggml-base.en.bin` for voice input

## macOS XTTS setup (local TTS for development)

From this repo root:

```bash
bash setup_xtts.sh
```

Then:

```bash
export INSIGHT_XTTS_PYTHON="$HOME/Desktop/InsightIOS/.venv-xtts/bin/python3"
```

On iPhone, spoken replies use Apple’s system voice. Full XTTS quality is available when running on macOS after setup.

## Project layout

```
InsightIOS/
├── InsightIOS.xcodeproj
├── InsightApp/          SwiftUI shell
├── docs/                Architecture and backlog (vision layer, roadmap)
├── Packages/            Swift packages (Engine, Llama, Whisper, Voice, …)
├── tools/xtts/          Coqui XTTS setup script
└── setup_xtts.sh        Shortcut to tools/xtts/setup_mac.sh
```

## Requirements

- Xcode 16+ (accept license: `sudo xcodebuild -license`)
- iOS 17+
- ~3.5 GB free storage for on-device models (Phi-4 candidate + whisper)
