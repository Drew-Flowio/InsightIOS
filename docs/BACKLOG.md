# Offgrid Minds iPhone — Backlog

Near-term roadmap for `/Users/andrewcoghill/Desktop/InsightIOS`.  
Architecture requirements live in [VISION_LAYER.md](./VISION_LAYER.md).

---

## Shipped (reference)

| Version | Summary |
|---------|---------|
| v1.1 | Phi-4 candidate integration |
| v1.2 | Phi-4 production default, streaming, personality |
| v1.3 | Knowledge volumes, `.ogpack`, retrieval, source attribution |
| v1.4 | Mind library, import, enable/disable |
| v1.5 | Real voice loop (Whisper STT, TTS, hold-to-talk) |
| v1.6 | Photo questions with Apple Vision OCR bridge, persistence, editable OCR |
| v1.7 | User-owned PDF manuals as private local knowledge volumes |
| v1.8 | Personal memory — profile, remember/recall/forget commands, Memory screen |
| v1.9 | Personality presets, custom prompt editing, active identity display |
| v2.0 | SmolVLM visual-reasoning prototype merged with OCR before Phi-4 |
| v2.1 | One-tap Vision Reasoning setup — download, validate, remove, photo source badge |

---

## P0 — Core product (vision)

| ID | Item | Notes |
|----|------|-------|
| **VIS-REQ** | **True visual reasoning is required** | Documented in [VISION_LAYER.md](./VISION_LAYER.md). Not optional long-term. |
| **VIS-EVAL-0** | **SmolVLM-500M device evaluation** | Smallest next milestone: fixture photos, baseline vs VLM, latency/RAM on 8 GB iPhone + 16 GB profile. No product UI. |
| **VIS-1** | Structured `visualObservations` on `PhotoAnalysisResult` | JSON field for VLM output; merge with OCR before `runTurn`. |
| **VIS-2** | VLM adapter shell (`VlmVisionAnalyzer`) | llama.cpp + mmproj; reuse `ModelCatalog` SmolVLM assets; mock for tests. |
| **VIS-3** | RAM-tiered vision residency | Coordinate unload with Phi-4 / Whisper; 8 GB vs 16 GB bundles. |
| **VIS-4** | Uncertainty → “another angle” UX | When VLM/OCR confidence low, assistant asks for a clearer photo in chat + voice. |

---

## P1 — Photo / Mind polish

| ID | Item | Notes |
|----|------|-------|
| PHOTO-1 | Restore `VisualContext` after cold start | Reload last photo message `image_path` + OCR into active context. |
| PHOTO-2 | Upload directory cleanup | TTL or session-scoped delete for orphaned `uploads/photo-*`. |
| PHOTO-3 | OCR tuning | Language hints, document mode, rotation from EXIF. |
| MIND-1 | Retrieval uses VLM entity tokens | Extend query beyond OCR once VIS-1 lands. |

---

## P2 — Platform / cohesion

| ID | Item | Notes |
|----|------|-------|
| SYNC-1 | Pi5 / iPhone pack sync | mDNS, local HTTP — separate track. |
| PACK-1 | Pack store / Foundry | Out of scope for iPhone standalone. |

---

## Explicitly out of scope (iPhone standalone)

- Cloud vision or transcription
- Wake word / always-on listening
- Image embeddings index
- Full SmolVLM production UX without VIS-EVAL-0 gate
- Fish ID production models before eval fixtures exist
- GPS / map tile reasoning

---

## Recommended sequence

1. **VIS-EVAL-0** — prove or disprove SmolVLM-500M on target hardware  
2. **VIS-1 + VIS-2** — prototype merged observations behind feature flag  
3. **VIS-3 + VIS-4** — residency + uncertainty UX  
4. **PHOTO-1** — persistence polish in parallel where low risk  
