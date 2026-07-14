# Offgrid Minds iPhone — Product Readiness Audit (v3.0)

Audit date: July 2026  
Scope: `/Users/andrewcoghill/Desktop/InsightIOS` — shipping iPhone app through v2.9.1 (Premium OGM UI identity), Visual Workspace (v2.7), Prompt Builder (v2.8)

Classification key:

| Label | Meaning |
|-------|---------|
| **Real and connected** | End-to-end wired; works in code with real adapters |
| **Real but needs physical-iPhone validation** | On-device path exists; not verified on hardware in this session |
| **Partial** | Works with gaps, degraded mode, or missing polish |
| **Mock or test-only** | Mock adapters, previews, or tests — not production UI |
| **Broken or missing** | Dead UI, incorrect behavior, or not reachable |

---

## 1. Current customer journey

```
Launch (SplashView — moonlight backdrop + OGM mark)
  └─ AppRootView
       ├─ FirstRunSetupView (if setup not completed)
       │    1. Welcome (OGM branding)
       │    2. Download Offline Brain (Phi-4 / Qwen by RAM tier) — required
       │    3. Download Voice — optional, skippable
       │    4. Download Visual Reasoning (SmolVLM) — optional, skippable
       │    5. Location permission preference
       │    6. Demo Mind note (Florida Coastal bundled)
       │    7. Finish → optional Demo Guide
       ├─ ModelSetupOverlay (if LLM missing after skip path)
       └─ MainChatView
            ├─ Status bar: OGM mark when active, personality, Minds, Memory, Setup, Map
            ├─ Chat transcript (text, photo, assistant + Sources used)
            ├─ Photo context chips / text editor (when photo attached)
            ├─ Location chip (when location active)
            ├─ Composer: photos, text, Prompt Builder wand, voice, send
            └─ Sheets / covers: Minds, Memory, Personality, Setup, Demo,
               Visual Workspace (photo / map / PDF), camera, photo picker

Typical happy path after setup:
  Ask question → retrieval + Phi-4 → streamed answer + Sources used
  Attach photo → text from photo (+ visual reasoning if SmolVLM installed) → answer
  Tap photo or manual source → Visual Workspace → continue conversation
  Enable Prompt Builder → Send → editable improved question → Send normally
```

**Reduced-feature path (voice/vision skipped):** Chat, Minds, manuals, maps, memory, workspace, and Prompt Builder still work. Voice requires download from Setup → Storage. Photos use Apple text extraction only without SmolVLM.

---

## 2. Feature reality table

| Area | Classification | Notes |
|------|----------------|-------|
| **First-run setup & model downloads** | Real and connected | `FirstRunSetupView` → HuggingFace downloads for LLM, voice, vision. Only LLM required. `ProductSetupStore` persists completion and skip flags. |
| **Phi-4 runtime & fallbacks** | Real but needs physical-iPhone validation | `LlamaCppLlmAdapter` + RAM-tier bundle (Phi-4 Q4_K_M/S, Qwen compact). Silent Phi-3.5 fallback if old file on disk. Metal vs CPU untested on device here. |
| **Whisper voice input & Apple TTS** | Real but needs physical-iPhone validation | `MicrophoneRecorder` + `WhisperSttAdapter` when installed; `SystemSpeechTtsAdapter` for replies. Mic disabled + plain error when voice missing. Post-setup voice download reinitializes engine. Remove voice now reinitializes engine (v3.0 fix). |
| **Photo capture, OCR, SmolVLM** | Real and connected | `CompositeVisionAnalyzer`: Apple OCR always; SmolVLM when models present. Customer labels: “Text from photo” / “Photo + visual reasoning” (v3.0). |
| **Model runtime coordination** | Real and connected | `ModelRuntimeCoordinator` serializes LLM/STT/vision per `ModelResidencyPolicy` tier. Used on chat, voice, photo, Prompt Builder turns. |
| **Minds, manuals, user-data imports** | Real and connected | PDF manuals, `.ogpack`, CSV/JSON/text/Markdown via `MindsLibraryView`. Bundled demo Mind seeds at engine init. Enable/disable only — no delete UI. |
| **Retrieval & Sources used** | Real and connected | Keyword/geo retrieval → persisted per assistant message → expandable Sources in chat. Manual sources open PDF workspace; Mind sources show excerpt only. |
| **Personal memory & personality** | Real and connected | Memory screen, remember/recall/forget in engine, personality presets + custom prompt. Default preset “Offgrid Guide” vs header “Offgrid Minds” is slightly confusing but intentional. |
| **GPS, geographic records, maps** | Partial | Location attach/clear/confirm works; geo Mind records feed map pins. Header opens Visual Workspace map only. `GeoMapView.swift` is dead code (duplicate of `WorkspaceMapContent`; never presented). Workspace map lacks offline banner from old map screen. |
| **Visual Workspace** | Real but needs physical-iPhone validation | Photo zoom, interactive map, PDF pages, answer panel, Prompt Builder, composer. Camera/picker wired on workspace cover. Pinch-zoom and landscape need device check. |
| **Prompt Builder** | Real and connected | One-shot improve via Phi-4; restore original; auto toggle-off; no auto-send. Uses photo, workspace, Minds, retrieval, memory, profile, location. |
| **Premium OGM UI & branding** | Real and connected | Moonlight palette, `OGMBrandMark`, unified badges, launch/setup branding via `ProductBranding`. Fixed typography — no Dynamic Type scaling yet. |
| **Persistence across relaunch** | Real and connected | SQLite session, messages, sources, memory, personality, profile. Sent photos persist paths + observations. **Gap:** unsent composer photo attachment is in-memory only. |
| **Skipped optional models** | Partial | Skip voice/vision at setup works. OCR-only photos without SmolVLM. TTS still speaks voice replies. `ModelSetupOverlay` now respects `skippedVoice` (v3.0 fix). Vision download clears skip flag and reinitializes engine (v3.0 fix). |

### Mock / test-only (not production paths)

| Item | Classification |
|------|----------------|
| `mockMode: true` in tests | Mock or test-only |
| `MockSttAdapter` / `MockAudioRecorder` when Whisper file missing at engine init | Partial fallback (UI-guarded) |
| `MockAdapters` full stack | Mock or test-only |
| SwiftUI previews (`ChatPreviewData` kettle demo) | Mock or test-only |
| `InsightEngine.greetAfterPhoto()`, `sendVoiceUtterance()`, `resetMemory()` | Broken or missing (API exists, no UI) |
| `GeoMapView.swift` | Broken or missing (compiled dead code; only `#Preview`) |
| `offgrid_splash.imageset` | Broken or missing (orphan asset; splash uses `OGMLogoMoonlight`) |

### Duplicate / conflicting flows

- **Maps:** Header → `openMapWorkspace()` only. Old `GeoMapView` sheet removed in v2.9; file still in target.
- **Personality:** Subtitle tap + theater icon both open personality sheet.
- **Thinking indicator:** Header `OGMBrandMark` during active states; transcript uses shimmer bar only (duplicate mark removed v3.0).

---

## 3. UI and branding reality table

| Surface | Classification | Asset / implementation | Notes |
|---------|----------------|------------------------|-------|
| **App icon** | Real and connected | `AppIcon.appiconset/OGM_logo_moonlight.png` (1024×1024) | Correct moonlight asset. Single scale in catalog — verify on device home screen. |
| **Splash / launch branding** | Real but needs physical-iPhone validation | `OGMLogoMoonlight` backdrop + `OGMBrandMark` overlay in `Splash View.swift` | v3.0: backdrop changed from `.fill` to `.fit` to avoid crop on portrait. Letterboxing acceptable. |
| **Setup / model overlay branding** | Real and connected | `FirstRunSetupView`, `ModelSetupOverlay` use `OGMBrandMark` + moonlight theme | Consistent with splash. |
| **In-app loading / thinking mark** | Real and connected | `OGMBrandMark` in `StatusIndicatorView` when active; `EmptyStateView` static mark | `.fit` sizing — no stretch. `.accessibilityHidden(true)` — no VoiceOver label for mark. No reduce-motion guard on pulse animation. |
| **Color / theme system** | Real and connected | `InsightColors`, `InsightTheme`, `InsightBackground` | Moonlight navy + glow blue palette applied app-wide. |
| **Typography** | Partial | `InsightTypography` fixed sizes | Readable on dark theme; **no Dynamic Type** — accessibility gap from OGM design pass. |
| **Badges** | Real and connected | `OGMBadge` — Location, OCR, visual reasoning, etc. | v3.0: status bar “GPS” → “Location”. Photo badges use `customerAnalysisLabel`. |
| **Product naming** | Real and connected | `ProductBranding.appName` / `assistantName` = “Offgrid Minds” | Previews updated v3.0. Internal module names still “Insight*”. |
| **Customer-facing copy** | Partial | Status: “Processing voice”, “Replying” (v3.0) | Remaining technical terms: “Offline Brain”, “Visual Reasoning”, “SmolVLM” in Setup/Storage (acceptable for model names). `PhotoOcrEditView` placeholder still says “OCR”. |
| **Orphan assets** | Broken or missing | `offgrid_splash.imageset` | Unused after OGM splash rewrite — safe to remove later. |
| **Imageset resolution** | Partial | `OGMLogoMark`, `OGMLogoMoonlight` — 1× entries only | May look soft on @3x devices; needs device visual check. |

### Logo usage audit (three roles)

| Role | Where | Stretch / clip risk | Status |
|------|-------|---------------------|--------|
| App icon | Home screen | None (square asset) | ✓ Correct asset |
| Splash / setup | `SplashView`, `FirstRunSetupView`, `ModelSetupOverlay` | Was **cropped** (`.fill`) — **fixed to `.fit`** v3.0 | Validate letterboxing on iPhone |
| In-app mark | `StatusIndicatorView`, `EmptyStateView` | `.fit` in fixed frame — no stretch | ✓ Not overused after shimmer dedupe |

---

## 4. Physical-iPhone validation checklist

Use on a **physical iPhone** (8 GB and 6 GB if possible):

### Setup, branding & models
- [ ] Splash moonlight backdrop — no awkward crop; mark centered and crisp
- [ ] App icon sharp on home screen (@3x)
- [ ] Complete first-run wizard; confirm Offline Brain download size and storage headroom
- [ ] Finish with voice **skipped**, then download from Setup → Storage; confirm mic transcribes (not mock text)
- [ ] Finish with vision **skipped**; confirm “Text from photo” badge
- [ ] Download visual reasoning from Setup; confirm “Photo + visual reasoning” badge; engine picks up SmolVLM without relaunch

### Core chat
- [ ] Text question against bundled Florida Coastal Mind; confirm Sources used appear
- [ ] Streaming cancel (Stop) mid-reply — label reads “Replying…”
- [ ] Hold-to-talk and tap-to-toggle voice; TTS speaks reply

### Photo & workspace
- [ ] Camera capture and library pick
- [ ] Tap photo bubble → Visual Workspace pinch-zoom
- [ ] Tap manual source → PDF page + prev/next
- [ ] Header map → workspace map; pan/zoom; tap geo pin
- [ ] Attach photo from **inside** workspace composer

### Context features
- [ ] Location ask-each-time / always / off; badge reads “Location”
- [ ] Remember/recall/forget memory commands
- [ ] Personality preset change affects tone
- [ ] Import CSV or PDF manual; confirm retrieval

### Prompt Builder
- [ ] Enable wand → rough question → improved draft in composer
- [ ] Restore Original → edit → normal Send
- [ ] Voice transcript → Prompt Builder improve

### Persistence & accessibility
- [ ] Force-quit and relaunch; chat history and sources intact
- [ ] Photo messages show thumbnails from saved paths
- [ ] Larger Dynamic Type setting — note unreadable areas (expected gap)
- [ ] Reduce Motion — note pulsing OGM mark (no guard today)

### Stress / RAM
- [ ] Voice → photo → chat sequence on 6 GB device without crash
- [ ] SmolVLM + Phi-4 residency handoff latency acceptable
- [ ] Landscape Visual Workspace layout

---

## 5. Known blockers

| Blocker | Severity | Status |
|---------|----------|--------|
| No iOS simulator / device run in audit environment | Process | Xcode iOS 26.5 simulator not available here |
| RAM pressure on 6 GB with Phi-4 + SmolVLM + voice | Product | Needs device profiling |
| Unsent photo attachment lost on relaunch | UX | Open — in-memory `visualContext` only |
| Photo context remains in composer after send until cleared | UX | Open |
| No “new chat” / session reset UI (`resetMemory` unreachable) | UX | Open |
| Non-manual sources cannot open in workspace (excerpt only) | UX | Acceptable for v3.0 |
| Fixed typography — poor Dynamic Type support | Accessibility | Open from OGM design pass |
| `GeoMapView.swift` dead code still in target | Maintenance | Documented; remove when convenient |

---

## 6. Small polish items

- Remove orphan `offgrid_splash.imageset` and dead `GeoMapView.swift` from target
- Add @2x/@3x variants for `OGMLogoMark` and `OGMLogoMoonlight`
- Clear `visualContext` after photo turn completes
- Add reduce-motion fallback for `OGMBrandMark` pulse
- VoiceOver label for thinking state (mark is hidden)
- Mind library: delete/remove installed Minds
- Workspace map offline banner + coordinate strip (parity with old map)
- Rename `PhotoOcrEditView` placeholder to “Edit text from photo…”
- Demo Mind checklist “missing” copy during first-run before engine starts

---

## 7. What is ready for a first device build

**Ready to install on a physical iPhone for alpha testing:**

- First-run setup with reduced-feature path (LLM-only minimum)
- Premium OGM dark UI with correct logo roles (icon, splash, in-app mark)
- Offline text chat with Minds retrieval and source attribution
- PDF manual import and manual page workspace
- Photo questions with text extraction (and visual reasoning when downloaded)
- Visual Workspace (photo, map, PDF)
- Prompt Builder
- Personal memory and personality
- Location-enriched questions
- User data import (CSV/JSON/text/Markdown)
- Session persistence across relaunch

**Treat as alpha — validate on device before external demo:**

- Voice transcription and hold-to-talk
- SmolVLM visual reasoning quality and latency
- Phi-4 Metal performance and memory on 6–8 GB phones
- Map tiles offline behavior and GPS accuracy
- Splash letterboxing and logo sharpness on @3x
- Dynamic Type and Reduce Motion accessibility

---

## 8. Smallest recommended next build step

**Install v3.0 on one physical iPhone** and run §4 checklist in a single 30-minute session. Log only failures. Highest priority:

1. Skip voice → download later → real transcription (engine reinit path)  
2. Skip vision → download later → “Photo + visual reasoning” without relaunch (v3.0 reinit fix)  
3. Splash + home screen logo appearance on @3x hardware  

Fix only what fails on hardware; do not start new features until those three pass.

---

## v3.0 audit fixes applied (same commit)

- Reinitialize engine after post-setup vision download and after voice model removal
- `ModelSetupOverlay.downloadModel()` respects `skippedVoice`
- Splash moonlight backdrop `.fill` → `.fit` (avoid crop)
- Status badge “GPS” → “Location”; Info.plist location string de-technified
- Customer photo labels: “Text from photo” / “Photo + visual reasoning”
- Status labels: “Processing voice”, “Replying” (header + composer stop bar)
- Voice error messages no longer mention “Whisper”
- Remove duplicate `OGMBrandMark` from `ThinkingShimmer` (header mark only)
- Preview strings “Insight” → “Offgrid Minds”
- Photo observation fallback copy aligned with new labels

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
