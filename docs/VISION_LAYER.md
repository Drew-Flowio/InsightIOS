# iOS Vision Layer — Core Product Requirement

**Status:** Architecture requirement (not optional)  
**Current shipping path:** v1.6 OCR / extracted-observations bridge  
**Target:** True on-device visual reasoning

---

## Product decision

True visual reasoning is **core to Offgrid Minds**, not a nice-to-have.

The app must eventually **understand photos directly** — parts, damage, diagrams, species, context — not only the text OCR extracts from them.

v1.6 is a **bridge**: useful today, honest about limits, and wired into the same chat / Mind / voice pipeline. It is **not** the final vision product.

---

## Required future capability

Offgrid Minds on iPhone must eventually:

- Identify visible boat/motor parts and equipment components
- Notice cracks, leaks, corrosion, wiring issues, labels, gauges, and warning signs
- Help with maps, schematics, diagrams, and manual pages
- Identify fish and species from photos (domain-specific Minds)
- Ask for another angle when uncertain instead of guessing
- Combine visual observations with Expert Pack / Mind retrieval
- Answer conversationally and speak the answer aloud (existing voice pipeline)

These capabilities must run **on-device** and integrate with **Expert Packs** (`.ogpack` / knowledge volumes), not replace them.

---

## Target pipeline

All photo turns should converge on one product pipeline:

```
Photo
  → OCR + visual model observations
  → Expert Pack retrieval (enabled Minds)
  → reasoning model (Phi-4 / successor)
  → spoken answer (TTS)
```

### Stage responsibilities

| Stage | Role |
|-------|------|
| **Photo ingest** | Camera / Photos picker, persist image, thumbnail in chat |
| **OCR + visual observations** | Apple Vision OCR **plus** VLM-produced structured observations (parts, damage, layout, uncertainty) |
| **Expert Pack retrieval** | Keyword/entity retrieval from installed Minds using question + OCR + visual tokens |
| **Reasoning model** | Phi-4 (today) consumes **observations + retrieved records**, not raw pixels |
| **Spoken answer** | TTS after streaming text; same cancel/stop behavior as v1.5 voice |

Important: even with a VLM, the reasoning model may still receive **structured observations** rather than raw image tensors in prompt context — but those observations must come from **visual understanding**, not OCR alone.

---

## Current v1.6 bridge vs future true VLM

| | **v1.6 (shipping bridge)** | **Future true VLM path** |
|---|---------------------------|---------------------------|
| **What “sees” the photo** | Apple Vision framework (OCR, coarse labels, barcodes) | On-device vision-language model (e.g. SmolVLM-class via llama.cpp) |
| **Prompt honesty** | Explicit: *“The assistant cannot see the image directly.”* | Explicit: observations from a local VLM; model still reasons over text context |
| **Part / damage reasoning** | Indirect — only if OCR or weak labels mention it | Direct — model describes visible parts, wear, leaks, wiring, gauge state |
| **Maps / schematics / manuals** | OCR text only | Layout + symbols + text + spatial relationships |
| **Fish / species ID** | Not supported | Supported via domain Minds + visual ID |
| **Uncertainty** | Generic “low confidence” from Vision scores | Conversational “show me another angle” when VLM confidence is low |
| **Mind retrieval query** | User question + OCR + coarse labels | User question + OCR + **VLM observation summary** + entities |
| **Persistence** | `image_path`, `ocr_text`, user question in SQLite | Same, plus structured `visual_observations` JSON when available |
| **Model residency** | No extra model; Vision is system framework | Additional VLM weights (tiered by RAM); coordinated unload with Phi-4 / Whisper |
| **Product status** | **Bridge — ship and use now** | **Core product requirement — must land** |

### What stays from v1.6 in the future

- Photo attach UX, editable OCR field, thumbnail in chat
- `runTurn` as the single inference path (text, voice, photo)
- Mind retrieval, source attribution, streaming, TTS, cancellation
- Honest prompting — never claim the LLM saw pixels it did not receive

OCR remains valuable even after VLM: labels, serial numbers, and manual text are often clearer from dedicated OCR than from a small VLM alone.

---

## Architecture direction (no big build yet)

Extend the existing types rather than fork a second photo pipeline:

```
PhotoAnalysisResult
  ├── ocrText              (v1.6 — Apple Vision)
  ├── detectedLabels       (v1.6 — coarse classification)
  └── visualObservations   (future — VLM structured output)

VisualContext → PromptBuilder IMAGE CONTEXT block → runTurn → KnowledgeRetriever
```

`SystemVisionImageAnalyzer` (or a sibling `VlmVisionAnalyzer`) should **merge** OCR and VLM outputs into one `PhotoAnalysisResult` before the UI and engine see it.

`ModelCatalog` already lists **SmolVLM-500M-Instruct** assets for future wiring; they are not downloaded or loaded in production today.

**Do not implement yet** (unless explicitly requested):

- Full production VLM download, residency, and UI
- Cloud vision APIs
- Image embeddings / vector index
- Fish ID production models
- GPS / map tile integration
- Replacing Phi-4 with a single multimodal model

---

## Smallest next evaluation milestone

**Goal:** Decide whether SmolVLM-500M-class on-device vision is viable on iPhone before committing to a production vision tier.

### Milestone: `Vision Eval v0` (device-only, no product UI)

1. **Fixture set (10–15 photos)**  
   Cover: outboard telltale / corrosion, wiring, gauge close-up, manual label, schematic snippet, map fragment, fish photo, ambiguous blur. Store under `Packages/InsightCore/Tests/Fixtures/Photos/` (or similar).

2. **Baseline (v1.6)**  
   Run current `SystemVisionImageAnalyzer` + OCR on each fixture; record observations and Mind retrieval hits.

3. **Candidate VLM**  
   Evaluate **SmolVLM-500M-Instruct** (already in `ModelCatalog`) through **llama.cpp + mmproj** on:
   - **Primary:** physical iPhone (8 GB class — current dev device tier)
   - **Secondary:** 16 GB handheld profile (simulator RAM limit or future hardware)

4. **Fixed prompt template**  
   Ask for structured JSON: `{ "parts": [], "issues": [], "text": "", "confidence": "low|medium|high", "needsAnotherAngle": bool }` — no chat UI, CLI or unit test harness only.

5. **Score (manual rubric, ~30 min)**  
   - Part/component identification (Y/N/partial)  
   - Damage/issue mention when present  
   - False claims when absent  
   - Latency (cold + warm) and peak RAM  
   - Whether `needsAnotherAngle` triggers on blurry fixtures  

6. **Decision gate**  
   - If SmolVLM-500M meets bar on 8 GB → plan **v1.7 prototype**: optional VLM observations merged into `PhotoAnalysisResult` behind a feature flag.  
   - If not → evaluate **one** larger tier on 16 GB only (e.g. SmolVLM-2B or Phi-3-Vision-class) before custom training or cloud fallback.

**Out of scope for this milestone:** App Store build, model download UX, concurrent Phi-4 + VLM residency, fish production accuracy.

---

## Related code (today)

| Area | Location |
|------|----------|
| OCR + coarse Vision | `Packages/InsightRuntime/.../SystemVisionImageAnalyzer.swift` |
| Observation formatting | `Packages/InsightCore/.../PhotoAnalysisResult.swift` |
| Photo turn / persistence | `Packages/InsightEngine/.../InsightEngine.swift`, `InsightStorage/Repository.swift` |
| Future VLM catalog entries | `Packages/InsightRuntime/.../ModelCatalog.swift` (`SmolVLM-500M-Instruct`) |
| UI bridge | `InsightApp/Views/Components/PhotoOcrEditView.swift`, `ChatViewModel.attachPhoto` |

See also: [BACKLOG.md](./BACKLOG.md)
