# Offgrid Minds iPhone — Product Readiness Audit (v2.9)

Audit date: July 2026  
Scope: `/Users/andrewcoghill/Desktop/InsightIOS` — shipping iPhone app through v2.8 (Visual Workspace, Prompt Builder)

Classification key:

| Label | Meaning |
|-------|---------|
| **Real and connected** | End-to-end wired; works in code/simulator with real adapters |
| **Real but needs physical-iPhone validation** | Implemented on-device path exists; not verified on hardware in this session |
| **Partial** | Works with gaps, degraded mode, or missing polish |
| **Mock or test-only** | Mock adapters, previews, or tests — not production UI |
| **Broken or missing** | Dead UI, incorrect behavior, or not reachable |

---

## 1. Current user journey

```
Launch (SplashView)
  └─ AppRootView
       ├─ FirstRunSetupView (if setup not completed)
       │    1. Welcome
       │    2. Download Offline Brain (Phi-4 / Qwen by RAM tier) — required
       │    3. Download Voice (Whisper) — optional, skippable
       │    4. Download Visual Reasoning (SmolVLM) — optional, skippable
       │    5. Location permission preference
       │    6. Demo Mind note (Florida Coastal bundled)
       │    7. Finish → optional Demo Guide
       └─ MainChatView
            ├─ Status bar: personality, Minds, Memory, Setup (gear), Map
            ├─ Chat transcript (text, photo, assistant + Sources)
            ├─ Photo context chips / OCR editor (when photo attached)
            ├─ Location chip (when location active)
            ├─ Composer: photos, text, Prompt Builder wand, voice, send
            └─ Sheets / covers: Minds, Memory, Personality, Setup, Demo,
               Visual Workspace (photo / map / PDF), camera, photo picker

Typical happy path after setup:
  Ask question → retrieval + Phi-4 → streamed answer + Sources used
  Attach photo → OCR (+ SmolVLM if installed) → photo question → answer
  Tap photo or manual source → Visual Workspace → continue conversation
  Enable Prompt Builder → Send → editable improved question → Send normally
```

**Reduced-feature path (voice/vision skipped):** Chat, Minds, manuals, maps, memory, workspace, and Prompt Builder still work. Voice requires Whisper download from Setup → Storage. Photos use Apple OCR only without SmolVLM.

---

## 2. Feature reality table

| Area | Classification | Notes |
|------|----------------|-------|
| **First-run setup & model downloads** | Real and connected | `FirstRunSetupView` → HuggingFace downloads for LLM, Whisper, SmolVLM. Only LLM required to finish. `ProductSetupStore` persists completion and skip flags. |
| **Phi-4 runtime & fallbacks** | Real but needs physical-iPhone validation | `LlamaCppLlmAdapter` + RAM-tier bundle (Phi-4 Q4_K_M/S, Qwen compact). Silent Phi-3.5 fallback if old file on disk. Metal vs CPU selection untested on device here. |
| **Voice recording, Whisper, TTS** | Real but needs physical-iPhone validation | `MicrophoneRecorder` + `WhisperSttAdapter` when installed; `SystemSpeechTtsAdapter` for replies. Mic disabled + error when Whisper missing (v2.9 fix). Post-setup Whisper download reinitializes engine (v2.9 fix). |
| **Photo capture, OCR, SmolVLM** | Real and connected | `CompositeVisionAnalyzer`: Apple OCR always; SmolVLM when models present. Graceful OCR-only when vision skipped or coordinator busy. |
| **Model runtime coordination** | Real and connected | `ModelRuntimeCoordinator` serializes LLM/STT/vision per `ModelResidencyPolicy` tier. Used on chat, voice, photo, Prompt Builder turns. |
| **Minds, manuals, user-data imports** | Real and connected | PDF manuals, `.ogpack`, CSV/JSON/text/Markdown via `MindsLibraryView`. Bundled demo Mind seeds at engine init. Enable/disable only — no delete UI. |
| **Retrieval & Sources used** | Real and connected | Keyword/geo retrieval → persisted per assistant message → expandable Sources in chat. Manual sources open PDF workspace; Mind sources show excerpt only (v2.9 fix: non-manual rows no longer look tappable). |
| **Personal memory & personality** | Real and connected | Memory screen, remember/recall/forget in engine, personality presets + custom prompt. Default preset name “Offgrid Guide” vs header “Offgrid Minds” is intentional but slightly confusing. |
| **GPS, geographic records, maps** | Partial | Location attach/clear/confirm works; geo Mind records feed map pins. **Map entry:** header opens Visual Workspace map only. Legacy `GeoMapView` sheet removed (was unreachable duplicate). Workspace map lacks offline banner/refresh strip from old map screen. |
| **Visual Workspace** | Real but needs physical-iPhone validation | Photo zoom, interactive map, PDF pages, answer panel, Prompt Builder, composer. Camera/picker wired on workspace cover (v2.9 fix). Pinch-zoom and landscape layout need device check. |
| **Prompt Builder** | Real and connected | One-shot improve via Phi-4; restore original; auto toggle-off; no auto-send. Uses photo, workspace, Minds titles, retrieval excerpts, memory, profile, location. |
| **Persistence across relaunch** | Real and connected | SQLite session, messages, sources, memory, personality, profile. Sent photos persist paths + OCR/observations. **Gap:** unsent composer photo attachment is in-memory only — lost on relaunch. |
| **Skipped optional models** | Partial | Skip voice/vision at setup works. OCR-only photos without SmolVLM. TTS still speaks voice replies. `ModelSetupOverlay` may still offer Whisper download regardless of skip flag. Vision download now clears `skippedVision` flag (v2.9 fix). |

### Mock / test-only (not production paths)

| Item | Classification |
|------|----------------|
| `mockMode: true` in tests | Mock or test-only |
| `MockSttAdapter` / `MockAudioRecorder` when Whisper file missing at engine init | Partial fallback (guarded in UI after v2.9) |
| `MockAdapters` full stack | Mock or test-only |
| SwiftUI previews (`ChatPreviewData` kettle demo, “Insight” labels) | Mock or test-only |
| `InsightEngine.greetAfterPhoto()`, `sendVoiceUtterance()`, `resetMemory()` | Broken or missing (API exists, no UI) |

### Dead / duplicate code (documented, not removed in v2.9)

- `GeoMapView.swift` — duplicate of `WorkspaceMapContent`; no longer presented (sheet removed).
- Dual personality entry in header (subtitle tap + theater icon).

---

## 3. Physical-iPhone validation checklist

Use this on a **physical iPhone** (8 GB and 6 GB if possible):

### Setup & models
- [ ] Complete first-run wizard on cellular/Wi‑Fi; confirm Phi-4 download size and storage headroom
- [ ] Finish with voice **skipped**, then download Whisper from Setup → Storage; confirm mic transcribes (not mock text)
- [ ] Finish with vision **skipped**; confirm photo questions use OCR-only badge
- [ ] Download SmolVLM from Setup; confirm “OCR + Visual Reasoning” badge on photo

### Core chat
- [ ] Text question against bundled Florida Coastal Mind; confirm Sources used appear
- [ ] Streaming cancel (Stop) mid-reply
- [ ] Hold-to-talk and tap-to-toggle voice; TTS speaks reply

### Photo & workspace
- [ ] Camera capture and library pick
- [ ] Tap photo bubble → Visual Workspace pinch-zoom
- [ ] Tap manual source → PDF page + prev/next
- [ ] Header map → workspace map; pan/zoom; tap geo pin
- [ ] Attach photo from **inside** workspace composer

### Context features
- [ ] Location ask-each-time / always / off
- [ ] Remember/recall/forget memory commands
- [ ] Personality preset change affects tone
- [ ] Import CSV or PDF manual; confirm retrieval

### Prompt Builder
- [ ] Enable wand → rough question → improved draft in composer
- [ ] Restore Original → edit → normal Send
- [ ] Voice transcript → Prompt Builder improve

### Persistence
- [ ] Force-quit and relaunch; chat history and sources intact
- [ ] Photo messages show thumbnails from saved paths

### Stress / RAM
- [ ] Voice → photo → chat sequence on 6 GB device without crash
- [ ] SmolVLM + Phi-4 residency handoff latency acceptable

---

## 4. Known blockers

| Blocker | Severity | Status |
|---------|----------|--------|
| No iOS simulator / device run in audit environment | Process | Xcode iOS 26.5 simulator not available here |
| RAM pressure on 6 GB with Phi-4 + SmolVLM + Whisper | Product | Needs device profiling |
| Unsent photo attachment lost on relaunch | UX | Open — in-memory `visualContext` only |
| Photo context remains in composer after send until cleared | UX | Open — engine keeps `visualContext` |
| `ModelSetupOverlay` downloads Whisper even if user skipped voice | UX | Open |
| No “new chat” / session reset UI (`resetMemory` unreachable) | UX | Open |
| Non-manual sources cannot open in workspace (by design; excerpt only) | UX | Acceptable for v2.9 |

---

## 5. Minor polish items

- Align remaining “Insight” strings in previews and internal docs with `ProductBranding.assistantName` (“Offgrid Minds”)
- Remove or merge duplicate `GeoMapView` / `WorkspaceMapContent`
- Add offline banner + coordinate strip to workspace map (parity with old map)
- Clear `visualContext` after photo turn completes (or explicit “detach photo” after send)
- Demo Mind checklist shows “missing” during first-run until engine starts — copy tweak
- `downloadVision` should reinitialize engine if SmolVLM installed after skip (same pattern as voice)
- Mind library: delete/remove installed Minds
- Workspace PDF page state vs context sync when paging

---

## 6. What is ready for a first device build

**Ready to install on a physical iPhone for alpha testing:**

- First-run setup with reduced-feature path (LLM-only minimum)
- Offline text chat with Minds retrieval and source attribution
- PDF manual import and manual page workspace
- Photo questions with OCR (and SmolVLM when downloaded)
- Visual Workspace (photo, map, PDF)
- Prompt Builder
- Personal memory and personality
- Location-enriched questions
- User data import (CSV/JSON/text/Markdown)
- Session persistence across relaunch

**Treat as alpha — validate on device before external demo:**

- Voice / Whisper / hold-to-talk
- SmolVLM visual reasoning quality and latency
- Phi-4 Metal performance and memory on 6–8 GB phones
- Map tiles offline behavior and GPS accuracy

---

## 7. Smallest recommended next build step

**Build v2.9.1 for one physical iPhone** and run the checklist in §3 top-to-bottom in a single 30-minute session. Log only failures. Highest priority validation:

1. Skip voice → download Whisper later → real transcription  
2. Photo → workspace → follow-up question  
3. Prompt Builder voice → improve → send  

Fix only what fails on hardware; do not start new features until those three paths pass.

---

## v2.9 audit fixes applied (same commit)

Small fixes made during this audit (see commit message):

- Removed unreachable `GeoMapView` sheet
- Disabled voice mic when Whisper not installed; surface error if tapped
- Reinitialize engine after post-setup Whisper download
- Clear `skippedVision` when vision models downloaded
- Wire camera/photo picker on Visual Workspace cover
- Non-manual source rows no longer styled as buttons
- Demo “Try voice” starts recording when Whisper ready
- Branding copy in Memory/Personality/composer stop bar uses `assistantName`

---

## Architecture spine (verified connected)

```
MainChatView / VisualWorkspaceView
        ↓
   ChatViewModel
        ↓
   InsightEngine ──→ ModelRuntimeCoordinator
        ├─ SessionManager + Repository (SQLite)
        ├─ KnowledgeRetriever + Minds / manuals
        ├─ CompositeVisionAnalyzer (OCR + SmolVLM)
        ├─ LlamaCpp LLM (Phi-4)
        ├─ Whisper STT
        └─ System TTS
```

The product core is **one engine, one session, one composer** with workspace and Prompt Builder as alternate surfaces — not parallel data flows.
