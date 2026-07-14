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
| v2.2 | Model runtime coordination — RAM tiers, queued residency, Whisper/VLM/Phi-4 unload order |
| v2.3 | Offline GPS location context — permission, prompt block, retrieval boost, persistence |
| v2.4 | Offline map + geographic Mind records — MapKit screen, nearby sources, prompt enrichment |
| v2.5 | User data import — CSV/JSON/text/Markdown into private local Minds with map-ready coordinates |
| v2.6 | Product setup and demo readiness — first-run wizard, storage view, Offgrid Minds branding |
| v2.7 | Visual workspace — full-screen photos, maps, PDF pages with collapsible answer panel and in-place composer |
| v2.8 | Prompt Builder — optional one-shot question improvement in composer using Phi-4 with restore-original |
| v2.9 | Product readiness audit — `docs/IPHONE_PRODUCT_READINESS.md` and small disconnected-path fixes |
| v2.9.1 | Premium OGM UI identity — moonlight brand palette, logo assets, unified badges, launch/setup branding |
| v3.0 | Product readiness audit (OGM UI + full feature matrix) — `docs/IPHONE_PRODUCT_READINESS.md` and engine/copy/logo polish |

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
- Live weather, network lookups, turn-by-turn navigation, chartplotter UI
- NOAA/FWC/USCG integrations, SOS, LoRa, geofencing, background tracking, location history

---

## Recommended sequence

1. **VIS-EVAL-0** — prove or disprove SmolVLM-500M on target hardware  
2. **VIS-1 + VIS-2** — prototype merged observations behind feature flag  
3. **VIS-3 + VIS-4** — residency + uncertainty UX  
4. **PHOTO-1** — persistence polish in parallel where low risk  
