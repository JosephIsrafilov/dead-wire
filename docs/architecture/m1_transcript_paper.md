# M1 Automatic Transcript Paper Contract
**Project:** DEAD WIRE  
**Phase:** Milestone 1 — Gate 11 (Automatic Transcript Paper)  
**Author:** Senior Technical Researcher  
**Status:** IMPLEMENTED & VALIDATED  

---

## 1. Executive Summary & Purpose

The `TranscriptPaper` represents Elias Crane's physical telegram transcript pad positioned on the telegraph operator desk.

In alignment with the source-of-truth pipeline:
```text
TRUE SIGNAL (Sounder Playback)
      ↓
ELIAS PERCEPTION (Subjective reception)
      ↓
WRITTEN TRANSCRIPT (Automatic written transcript on paper pad)
      ↓
PLAYER INTERPRETATION (Player reads and verifies physical evidence)
```

The paper pad displays strictly Elias's **`written_transcript`**.

---

## 2. Invariants & Strict Layer Separation

1. **Source Isolation:**
   - The paper pad accepts text solely through `set_transcript_text()`.
   - It possesses zero references to `true_message` or `TransmissionData.true_message`.
2. **Zero Error Notification:**
   - The paper pad displays whatever Elias wrote without evaluating or reporting mismatches.
   - Discrepancies between sounder audio and paper text (e.g. `WATER` vs `WATCHER`) must be detected solely by the player.
3. **Lifecycle States:**
   - Pre-transmission / Blank: Displays `[BLANK TELEGRAM PAD]`.
   - During transmission: Remains unrevealed until transmission completion.
   - Post-transmission: Revealed and readable upon player inspection.
4. **Interaction:**
   - Implements standard `Interactable` on Layer 2 with prompt `"Read Telegram Transcript"`.
   - Emits `transcript_inspected(text)` and `transcript_closed()`.

---

## 3. Public API

```gdscript
class_name TranscriptPaper
extends Node3D

signal transcript_inspected(text: String)
signal transcript_closed()

func set_transcript_text(text: String) -> void
func reveal_transcript() -> void
func clear_transcript() -> void
func get_transcript_text() -> String
func is_revealed() -> bool
func get_interactable() -> Interactable
```
