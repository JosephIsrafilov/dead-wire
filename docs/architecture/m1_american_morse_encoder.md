# American Morse Deterministic Encoder Contract (Milestone 1)
**Project:** DEAD WIRE  
**Phase:** Milestone 1 — Gate 08B-2B (American Morse Encoder)  
**Author:** Senior Technical Researcher  
**Status:** IMPLEMENTED & VALIDATED  

---

## 1. Executive Summary & Purpose

In **DEAD WIRE**, the telegraph system operates on a strictly separated source-of-truth pipeline:
```text
TRUE MESSAGE (Canonical Text)
      ↓ (AmericanMorseEncoder)
TRUE SIGNAL (Deterministic MorseSequenceData in integer units)
      ↓ (Future Physical Playback)
ELIAS PERCEPTION (What Elias subjectively receives)
      ↓ (Future Elias Transcription Layer)
WRITTEN TRANSCRIPT (Elias's automatic written output)
      ↓
PLAYER INTERPRETATION (Player verifies and interprets the evidence)
```

The `AmericanMorseEncoder` is a stateless, pure functional translator whose sole responsibility is to convert a valid uppercase message into a deterministic `MorseSequenceData` stream of relative timing units (`MARK` and `GAP`), using an `AmericanMorseAlphabetData` resource.

### Layer Separation Rules:
- **WRITTEN TRANSCRIPT** is created automatically by Elias (his physical handwriting record), not by the player.
- The **PLAYER** reads, verifies, and interprets the physical evidence and discrepancies.
- The **encoder** creates strictly **TRUE SIGNAL**.
- The encoder possesses zero knowledge of Elias's perception, the written transcript, or player interpretation.
- These layers must never be collapsed or combined into a single text value.

---

## 2. Exact Public API

```gdscript
class_name AmericanMorseEncoder
extends RefCounted

const INTER_LETTER_GAP_UNITS: int = 3
const INTER_WORD_GAP_UNITS: int = 6

func get_encoding_errors(
	message: String,
	alphabet: AmericanMorseAlphabetData
) -> PackedStringArray

func encode(
	message: String,
	alphabet: AmericanMorseAlphabetData
) -> MorseSequenceData
```

---

## 3. Strict Validation Contract

`get_encoding_errors()` deterministically rejects any invalid input. No implicit transformations or corrections are applied.

### Rejected Conditions:
1. **Null Alphabet:** `alphabet == null`
2. **Invalid Alphabet:** `alphabet.get_validation_errors().size() > 0`
3. **Empty Message:** `message == ""`
4. **Whitespace-Only Message:** e.g., `"   "`
5. **Leading Space:** `message.begins_with(" ")`
6. **Trailing Space:** `message.ends_with(" ")`
7. **Consecutive Spaces:** `message.contains("  ")`
8. **Lowercase Characters:** e.g., `'a'`–`'z'` (rejected with position reporting)
9. **Unsupported Characters:** Any symbol absent from the supplied alphabet resource (rejected with position reporting)
10. **Unsupported Whitespace:** Newlines (`\n`, `\r`), tabs (`\t`), and other non-space whitespace

### Explicitly Forbidden Normalizations:
- **No `strip_edges()`:** Leading and trailing spaces are validation failures, not silently stripped.
- **No automatic uppercase conversion:** Lowercase input fails validation; it is not auto-converted.
- **No whitespace collapsing:** Multiple spaces fail validation; they are not merged.
- **No partial encoding:** If a single character fails validation, `encode()` returns `null`.

---

## 4. Sequence Assembly & Delimiter Rules

A valid message consists of words separated by a single space (`" "`).

1. **Character Elements:**
   - The elementary timing marks and internal gaps for each character are retrieved from `alphabet.get_sequence(symbol)`.
   - Internal spaced-letter pauses (e.g., `GAP(2)` in `C`, `O`, `R`) and long dashes (e.g., `MARK(6)` in `L`) remain unchanged.
2. **Inter-Letter Gaps (`GAP(3)`):**
   - Inserted strictly between consecutive characters within the same word (`INTER_LETTER_GAP_UNITS = 3`).
   - Not inserted after the last letter of a word.
3. **Inter-Word Gaps (`GAP(6)`):**
   - Inserted strictly between consecutive words (`INTER_WORD_GAP_UNITS = 6`).
   - Not inserted after the final word.
4. **Boundary & Alternation Invariants:**
   - The resulting `MorseSequenceData` always starts with `MARK` and ends with `MARK`.
   - No leading or trailing `GAP` is present.
   - `MARK` and `GAP` strictly alternate across the entire stream.
   - Standalone `[GAP(6)]` sequences are never created.

---

## 5. Deep-Copy Data Ownership Contract

`AmericanMorseAlphabetData` resources are shared, read-only configuration objects. 

To prevent memory corruption and shared mutable state:
- The encoder **never** mutates the sequence returned by `alphabet.get_sequence()`.
- The encoder **never** returns or shares the alphabet's internal `MorseSequenceData` or `MorseTimingEvent` instances.
- Every `MorseTimingEvent` (both letter marks/gaps and delimiter gaps) in the output sequence is instantiated as a **new, independent object** (`MorseTimingEvent.new()`).
- Multiple calls to `encode()` with the same input produce value-equivalent sequences with distinct object instances.

---

## 6. Deterministic TRUE SIGNAL Rule

The output of `AmericanMorseEncoder` represents **TRUE SIGNAL**:
- Timings are exact integer relative units (`1`, `2`, `3`, `6`).
- Zero operator jitter, hand fatigue, battery decay, or line resistance is introduced at this layer.
- Layer assignment in `TransmissionData` is the responsibility of future game orchestration, not the encoder.

---

## 7. Deferred Systems (Explicit Non-Scope)

The following systems are intentionally excluded from Gate 08B-2B:
- **MorseScheduler / Real-Time Playback:** Audio scheduling and wall-clock seconds conversion.
- **WPM / Speed Scaling:** Deferred. Gate 08B-2B defines only integer relative timing units. No wall-clock conversion formula or standard-word convention is approved at this gate.
- **SounderController / Audio Nodes:** Physical click-clack audio synthesis, timbre, resonant chamber acoustics.
- **Perception Distortion / Narrative Horror:** Elias's fatigue, cognitive slippage, or psychological auditory distortion.
- **Telegraph State Machine / UI:** Hardware interaction, telegram paper transcript, or routing boards.
