# Historical American Morse Source Audit (1894 Railroad Standard)
**Project:** DEAD WIRE  
**Phase:** Milestone 1 — Gate 08B-1 (Historical Source Audit — Final Evidence Correction)  
**Author:** Senior Technical Researcher  
**Target In-Game Date:** April 1894 (American West Railroad Telegraphy)

---

## 1. Executive Summary & Objective

In **DEAD WIRE**, the core psychological horror dynamic rests upon the strict separation and fidelity of narrative layers:
```text
TRUE MESSAGE (Canonical Text)
      ↓
TRUE SIGNAL (American Morse Discrete Timing Stream)
      ↓
ELIAS PERCEPTION (Cognitive / Acoustic Subjective Impression)
      ↓
WRITTEN TRANSCRIPT (Physical Telegram Form Record)
```

To maintain historical integrity, the game's telegraph simulation must strictly replicate **American Morse** (also historically designated *Railroad Morse* or *Ordinary Morse* in North America), exactly as practiced by professional railroad operators in **April 1894**. 

This document audits 19th-century primary telegraphy manuals to establish:
1. The **canonical timing contract** in relative integer units, distinguishing nominal standard proportions from historical sound-operating variations.
2. The exact **character topology** (ordered arrangement of dot, dash, and spaced elements) for all required Milestone 1 characters.
3. The **M1 Deterministic Fairness Baseline** governing runtime event durations.
4. Verification that the **Gate 08A data model** (`MorseTimingEvent` and `MorseSequenceData`) losslessly represents these historical primitives.

> **CRITICAL HISTORICAL RULE:** Modern International Morse (ITU-R M.1677) must **never** be substituted for American Morse. American Morse possesses distinct timing characteristics—notably **spaced letters** (internal pauses within a character), **variable-length dashes** (short dash, long dash, extra-long cipher), and distinct digit encodings.

---

## 2. Primary Historical Sources & Scan Verifications

All timing values, spacing rules, and character topologies in this audit are directly verified against digitized high-resolution scans of 19th-century primary sources:

### Primary Source 1: Franklin Leonard Pope (1891)
- **Title:** *Modern Practice of the Electric Telegraph: A Technical Hand-Book for Electricians, Managers, and Operators*
- **Author:** Franklin Leonard Pope (Telegraphic Engineer; Past President, American Institute of Electrical Engineers)
- **Edition:** 14th Edition, Revised and Enlarged, New York: D. Van Nostrand Company, 1891.
- **Scan Source:** Wikimedia Commons / Internet Archive ID [`modernpracticeof00poperich`](https://upload.wikimedia.org/wikipedia/commons/5/59/Modern_practice_of_the_electric_telegraph%3B_a_technical_handbook_for_electricians%2C_managers%2C_and_operators%2C_with_185_illustrations_%28IA_modernpracticeof00poperich%29.pdf)
- **Verified Sections & Pages:**
  - **Contents (p. xi, PDF p. 12):** Lists Chapter X ("Hints to Learners"), including §371 ("Formation of the Telegraphic Code"), §372 ("The American Morse Code"), §§378–379 ("Reading by Sound").
  - **Section 371 — "Formation of the Telegraphic Code" (printed p. 216, PDF p. 240):** Details Alfred Vail's 1837 code structure consisting of seven elements: (1) dot, (2) dash, (3) long dash, (4) ordinary space, (5) letter-space, (6) word-space, and (7) sentence-space.
  - **Section 372 — "The American Morse Code" (printed pp. 217–219, PDF pp. 241–243):** Provides the complete American Morse alphabet, numerals, and punctuation table. Documents the historical nominal rule ("the dash equal to 3, and the long dash to 6, dots") and the colloquial sound-reading tendency to shorten dashes.
  - **Sections 374–377 (printed pp. 219–222, PDF pp. 243–246):** Key handling, elementary principles, and exercises for spaced letters and dashes.
  - **Sections 378–379 — "Reading by Sound" (printed pp. 222–224, PDF pp. 246–248):** Acoustic distinction between down-stroke (onset) and up-stroke (cessation), noting that a dot and dash produce equal sound volume and are distinguished solely by the duration between clicks.

### Primary Source 2: Franklin Leonard Pope (1874)
- **Title:** *Modern Practice of the Electric Telegraph: A Hand-Book for Electricians and Operators*
- **Author:** Franklin Leonard Pope
- **Edition:** 9th Edition, New York: D. Van Nostrand, 1874.
- **Scan Source:** Wikimedia Commons / Internet Archive ID [`modernpracticeof00pope_0`](https://upload.wikimedia.org/wikipedia/commons/5/54/Modern_practice_of_the_electric_telegraph.A_handbook_for_electricians_and_operators._%28IA_modernpracticeof00pope_0%29.pdf)
- **Verified Sections & Pages:**
  - **Section 150 — "Formation of the Morse Alphabet" (printed p. 96, PDF p. 108):** Defines the three elementary signals (dot, short dash, long dash) and four spacing intervals (element space, spaced-letter space, letter space, word space).
  - **Section 151 — "Units of Length" (printed p. 96, PDF p. 108):** Explicitly defines the canonical nominal proportions:
    1. Short dash = 3 dots ($3\text{ units}$).
    2. Long dash = 6 dots ($6\text{ units}$).
    3. Ordinary internal element space = 1 dot ($1\text{ unit}$).
    4. Spaced-letter space = 2 dots ($2\text{ units}$).
    5. Inter-letter space = 3 dots ($3\text{ units}$).
    6. Inter-word space = 6 dots ($6\text{ units}$).
  - **Section 156 (printed pp. 99–100, PDF pp. 111–112):** Exercises on spaced letters (`C`, `O`, `R`, `Y`, `Z`, `&`), establishing that the internal space is double the ordinary element space ($2\text{ units}$).
  - **Section 157 — "Alphabet & Numerals Table" (printed p. 101, PDF p. 113):** Visual typography confirming exact topologies for `A` through `Z`, `&`, and numerals `1` through `0` (including `1 = .--.` and `7 = --..`).
  - **Section 158 (printed p. 102, PDF p. 114):** Spacing rules and warnings against crowding words.
  - **Section 159 — "Reading by Sound" (printed pp. 102–103, PDF pp. 114–115):** Sounder acoustics and discrimination of `E`, `T`, `L`.

### Primary Source 3: Arthur Potter (1870)
- **Title:** *The Telegraph Instructor: A Rudimentary Treatise on the Art of Telegraphing*
- **Author:** Arthur Potter
- **Publisher:** Philadelphia: Flemming, Potter & Co., 1870.
- **Archive / Catalog:** Library of Congress Control No. [08000715](https://www.loc.gov/item/08000715/)
- **Scan Source:** Wikimedia Commons / Internet Archive ID [`telegraphinstruc00pott`](https://upload.wikimedia.org/wikipedia/commons/3/35/The_telegraph_instructor_%28IA_telegraphinstruc00pott%29.pdf)
- **Verified Sections & Pages:**
  - **Alphabet Topology (printed p. 6, PDF p. 16):** Introduces dots and dashes, defining spaced letters (`C`, `O`, `R`, `Y`, `Z`) and noting that letter `L` is a dash twice the length of `T`.
  - **Sound Operating Timing (printed p. 7, PDF p. 17):** Introduces sound-operating instruction: "To make a dot, strike with a hammer as you count one and raise it instantly; to make a dash, strike and count four, then raise again. The dash taking four times as long as the dot."
  - **Spacing Proportions (printed p. 8, PDF p. 18):**
    - Internal element space: count 1 ($1\text{ unit}$).
    - Spaced-letter internal space: count 2 ($2\text{ units}$).
    - Inter-letter space: count 3 ($3\text{ units}$).
    - Inter-word space: count 4 ($4\text{ units}$).
    - Letter `L` (long dash): count 8 ($8\text{ units}$, twice the 4-count dash).
  - **Alphabet Verification Questionnaire (printed p. 9, PDF p. 19):** Complete catechism confirming character topologies for all letters `A` through `Z` and `&`.
  - **Appendix: Figures & Punctuation (printed p. 21, PDF p. 31):** Typographic table of numerals and punctuation.

---

## 3. Historical Timing Contract & M1 Production Baseline

In American Morse, all temporal events are measured relative to the fundamental unit: the duration of a single **dot mark** ($1\text{ unit}$).

### 3.1 Timing Primitives & Source Evidence Table

| Timing Primitive | M1 Fairness Baseline Value | Primary Source Supporting Nominal Value | Historical Sound-Operating Variant | M1 Production Decision & Rationale |
| :--- | :---: | :--- | :--- | :--- |
| **Dot Mark** | `1 unit` | Pope 1874, §151, p. 96 (PDF p. 108);<br>Pope 1891, §372, p. 217 (PDF p. 241) | Potter 1870, p. 7 (PDF p. 17: "count 1") | **Adopt `1 unit`.** Unanimous base unit across all sources. |
| **Short Dash Mark** | `3 units` | Pope 1874, §151, p. 96 (PDF p. 108: "equal to 3 dots");<br>Pope 1891, §372, p. 218 (PDF p. 242) | Potter 1870, p. 7 (PDF p. 17: count 4);<br>Pope 1891, §372, p. 217 (PDF p. 241: count 2 in fast sending) | **Adopt `3 units`.** Nominal $1:3$ ratio ensures clear acoustic distinction on mechanical sounder. |
| **Long Dash Mark (`L`)** | `6 units` | Pope 1874, §151, p. 96 (PDF p. 108: "equal to 6 dots");<br>Pope 1891, §372, p. 218 (PDF p. 242) | Potter 1870, p. 8 (PDF p. 18: count 8);<br>Pope 1891, §372, p. 218 (PDF p. 242: count 4 in fast sending) | **Adopt `6 units`.** Exactly twice the short dash ($3 \times 2 = 6$), preventing confusion with `T` ($3\text{ units}$). |
| **Ordinary Intra-Element Gap** | `1 unit` | Pope 1874, §151, p. 96 (PDF p. 108: "equal to 1 dot");<br>Pope 1891, §372, p. 218 (PDF p. 242) | Potter 1870, p. 8 (PDF p. 18: "count 1") | **Adopt `1 unit`.** Unanimously confirmed across all historical manuals. |
| **Spaced-Letter Intra-Element Gap** | `2 units` | Pope 1874, §151, p. 96 (PDF p. 108: "equal to 2 dots");<br>Pope 1891, §372, p. 218 (PDF p. 242) | Potter 1870, p. 8 (PDF p. 18: "count 2") | **Adopt `2 units`.** Unanimously confirmed ($2\text{ units}$), distinguishing spaced letters from inter-letter gaps. |
| **Inter-Letter Gap** | `3 units` | Pope 1874, §151, p. 96 (PDF p. 108: "equal to 3 dots");<br>Pope 1891, §372, p. 218 (PDF p. 242) | Potter 1870, p. 8 (PDF p. 18: "count 3") | **Adopt `3 units`.** Unanimously confirmed boundary gap between letters within a word. |
| **Inter-Word Gap** | `6 units` | Pope 1874, §151, p. 96 (PDF p. 108: "equal to 6 dots");<br>Pope 1891, §372, p. 218 (PDF p. 242) | Potter 1870, p. 8 (PDF p. 18: count 4);<br>Pope 1891, §372, p. 218 (PDF p. 242: count 3 in fast sending) | **Adopt `6 units`.** Equal to two letter-spaces ($3 \times 2 = 6$), providing unambiguous word boundary pacing. |

### 3.2 Analysis of Historical Timing Conflicts & The M1 Fairness Policy

A rigorous audit of 19th-century literature reveals that **real operator timing was not monolithic**:
1. **Pope’s Nominal Standard (1874 / 1891):** Derived from early recording registers and codified in textbook standards, maintaining the classic mathematical ratios: $\text{dot}=1$, $\text{dash}=3$, $\text{long dash}=6$, $\text{element gap}=1$, $\text{spaced gap}=2$, $\text{letter gap}=3$, $\text{word gap}=6$.
2. **Potter’s Sound-Operating Method (1870):** Taught learners a counting cadence of $\text{dot}=1$, $\text{dash}=4$, $\text{long dash}=8$, $\text{word gap}=4$.
3. **Pope’s Rapid Sound-Reading Observation (1891):** Noted that commercial sound operators in high-speed traffic routinely compressed dashes to $2\text{ units}$, long dashes to $4\text{ units}$, and word spaces to $3\text{ units}$.

#### M1 Production Decision:
The existence of historical operator divergence confirms that no single operator timing existed in 1894. For **DEAD WIRE**, Milestone 1 adopts the **M1 Deterministic Fairness Baseline** based on Pope's nominal standard (`1 / 3 / 6` for marks, `1 / 2 / 3 / 6` for gaps):
- **Objective Reproducibility:** `TRUE SIGNAL` remains an uncorrupted source of truth.
- **Acoustic Clarity:** Generates clean, distinct click-clack intervals on mechanical sounders.
- **Fair Player Learning:** The player learns stable acoustic patterns before experiencing narrative distortions in Elias's perception.

---

## 4. M1 Character Coverage & Discrete Event Sequences

Milestone 1 requires transmitting and validating the following canonical test messages:
1. `TRAIN 17 CLEAR EAST`
2. `HOLD FREIGHT UNTIL TEN`
3. `WATER`
4. `WATCHER`

The minimum required character set consists of **18 alphanumeric characters** plus **Inter-Word Space**:
`A`, `C`, `D`, `E`, `F`, `G`, `H`, `I`, `L`, `N`, `O`, `R`, `S`, `T`, `U`, `W`, `1`, `7`, `[SPACE]`.

> **Methodological Rule on Character Specification:**
> Character topology (the sequence of dot, dash, and spaced elements) is confirmed by primary historical sources. Exact runtime event durations follow the **M1 Deterministic Fairness Baseline**. Character definitions contain **only internal elements**; inter-letter gaps (`GAP(3)`) and inter-word gaps (`GAP(6)`) are sequence compositors added during message encoding.

---

### 4.1 Detailed Character Entries

#### Character: `A`
- **Character Topology:** Dot, Dash
- **M1 Discrete Event Sequence:**
  ```text
  MARK(1)
  GAP(1)
  MARK(3)
  ```
- **Total Character Duration:** $1 + 1 + 3 = 5\text{ units}$
- **Primary Verifications:** Pope 1874 (§157, p. 101 / PDF p. 113); Pope 1891 (§372, p. 217 / PDF p. 241); Potter 1870 (p. 6, 9 / PDF p. 16, 19).
- **Status:** `CONFIRMED`

---

#### Character: `C` *(Spaced Letter)*
- **Character Topology:** Dot, Dot, [Space], Dot
- **M1 Discrete Event Sequence:**
  ```text
  MARK(1)
  GAP(1)
  MARK(1)
  GAP(2)
  MARK(1)
  ```
- **Total Character Duration:** $1 + 1 + 1 + 2 + 1 = 6\text{ units}$
- **Primary Verifications:** Pope 1874 (§156, p. 100 / PDF p. 112; §157, p. 101 / PDF p. 113); Pope 1891 (§372, p. 217 / PDF p. 241); Potter 1870 (p. 6, 9 / PDF p. 16, 19).
- **Status:** `CONFIRMED`
- **Notes:** Two dots, intra-character spaced gap of $2\text{ units}$, one dot (`.. .`). Rhythmically distinct from `S` (three continuous dots with $1\text{-unit}$ gaps) and `I E` (separated by inter-letter gap of $3\text{ units}$).

---

#### Character: `D`
- **Character Topology:** Dash, Dot, Dot
- **M1 Discrete Event Sequence:**
  ```text
  MARK(3)
  GAP(1)
  MARK(1)
  GAP(1)
  MARK(1)
  ```
- **Total Character Duration:** $3 + 1 + 1 + 1 + 1 = 7\text{ units}$
- **Primary Verifications:** Pope 1874 (§157, p. 101 / PDF p. 113); Pope 1891 (§372, p. 217 / PDF p. 241); Potter 1870 (p. 9 / PDF p. 19).
- **Status:** `CONFIRMED`

---

#### Character: `E`
- **Character Topology:** Single Dot
- **M1 Discrete Event Sequence:**
  ```text
  MARK(1)
  ```
- **Total Character Duration:** $1\text{ unit}$
- **Primary Verifications:** Pope 1874 (§157, p. 101 / PDF p. 113); Pope 1891 (§372, p. 217 / PDF p. 241); Potter 1870 (p. 9 / PDF p. 19).
- **Status:** `CONFIRMED`

---

#### Character: `F`
- **Character Topology:** Dot, Dash, Dot
- **M1 Discrete Event Sequence:**
  ```text
  MARK(1)
  GAP(1)
  MARK(3)
  GAP(1)
  MARK(1)
  ```
- **Total Character Duration:** $1 + 1 + 3 + 1 + 1 = 7\text{ units}$
- **Primary Verifications:** Pope 1874 (§157, p. 101 / PDF p. 113); Pope 1891 (§372, p. 217 / PDF p. 241); Potter 1870 (p. 9 / PDF p. 19).
- **Status:** `CONFIRMED`
- **Notes:** In American Morse, `F` is `.-.`. **Crucial difference from International Morse** (where `F` is `..-.` and `.-.` represents `R`).

---

#### Character: `G`
- **Character Topology:** Dash, Dash, Dot
- **M1 Discrete Event Sequence:**
  ```text
  MARK(3)
  GAP(1)
  MARK(3)
  GAP(1)
  MARK(1)
  ```
- **Total Character Duration:** $3 + 1 + 3 + 1 + 1 = 9\text{ units}$
- **Primary Verifications:** Pope 1874 (§157, p. 101 / PDF p. 113); Pope 1891 (§372, p. 217 / PDF p. 241); Potter 1870 (p. 9 / PDF p. 19).
- **Status:** `CONFIRMED`

---

#### Character: `H`
- **Character Topology:** Four Dots
- **M1 Discrete Event Sequence:**
  ```text
  MARK(1)
  GAP(1)
  MARK(1)
  GAP(1)
  MARK(1)
  GAP(1)
  MARK(1)
  ```
- **Total Character Duration:** $1 + 1 + 1 + 1 + 1 + 1 + 1 = 7\text{ units}$
- **Primary Verifications:** Pope 1874 (§157, p. 101 / PDF p. 113); Pope 1891 (§372, p. 217 / PDF p. 241); Potter 1870 (p. 9 / PDF p. 19).
- **Status:** `CONFIRMED`

---

#### Character: `I`
- **Character Topology:** Two Dots
- **M1 Discrete Event Sequence:**
  ```text
  MARK(1)
  GAP(1)
  MARK(1)
  ```
- **Total Character Duration:** $1 + 1 + 1 = 3\text{ units}$
- **Primary Verifications:** Pope 1874 (§157, p. 101 / PDF p. 113); Pope 1891 (§372, p. 217 / PDF p. 241); Potter 1870 (p. 9 / PDF p. 19).
- **Status:** `CONFIRMED`
- **Notes:** Two continuous dots with $1\text{-unit}$ gap (`..`). Compare with spaced letter `O` (`. .`).

---

#### Character: `L` *(Long Dash)*
- **Character Topology:** Single Long Dash
- **M1 Discrete Event Sequence:**
  ```text
  MARK(6)
  ```
- **Total Character Duration:** $6\text{ units}$
- **Primary Verifications:** Pope 1874 (§151, p. 96 / PDF p. 108; §157, p. 101 / PDF p. 113); Pope 1891 (§372, p. 218 / PDF p. 242); Potter 1870 (p. 6, 8, 9 / PDF p. 16, 18, 19).
- **Status:** `CONFIRMED`
- **Notes:** Single continuous long mark equal to twice the short dash ($6\text{ units}$). Distinct from short dash `T` ($3\text{ units}$) and International `L` (`.-..`).

---

#### Character: `N`
- **Character Topology:** Dash, Dot
- **M1 Discrete Event Sequence:**
  ```text
  MARK(3)
  GAP(1)
  MARK(1)
  ```
- **Total Character Duration:** $3 + 1 + 1 = 5\text{ units}$
- **Primary Verifications:** Pope 1874 (§157, p. 101 / PDF p. 113); Pope 1891 (§372, p. 217 / PDF p. 241); Potter 1870 (p. 9 / PDF p. 19).
- **Status:** `CONFIRMED`

---

#### Character: `O` *(Spaced Letter)*
- **Character Topology:** Dot, [Space], Dot
- **M1 Discrete Event Sequence:**
  ```text
  MARK(1)
  GAP(2)
  MARK(1)
  ```
- **Total Character Duration:** $1 + 2 + 1 = 4\text{ units}$
- **Primary Verifications:** Pope 1874 (§156, p. 100 / PDF p. 112; §157, p. 101 / PDF p. 113); Pope 1891 (§372, p. 217 / PDF p. 241); Potter 1870 (p. 6, 8, 9 / PDF p. 16, 18, 19).
- **Status:** `CONFIRMED`
- **Notes:** Dot, spaced gap of $2\text{ units}$, dot (`. .`). A critical acoustic distinction:
  - `I` = `MARK(1), GAP(1), MARK(1)` (Duration 3)
  - `O` = `MARK(1), GAP(2), MARK(1)` (Duration 4)
  - `E E` = `MARK(1), GAP(3), MARK(1)` (Duration 5)

---

#### Character: `R` *(Spaced Letter)*
- **Character Topology:** Dot, [Space], Dot Dot
- **M1 Discrete Event Sequence:**
  ```text
  MARK(1)
  GAP(2)
  MARK(1)
  GAP(1)
  MARK(1)
  ```
- **Total Character Duration:** $1 + 2 + 1 + 1 + 1 = 6\text{ units}$
- **Primary Verifications:** Pope 1874 (§156, p. 100 / PDF p. 112; §157, p. 101 / PDF p. 113); Pope 1891 (§372, p. 217 / PDF p. 241); Potter 1870 (p. 6, 8, 9 / PDF p. 16, 18, 19).
- **Status:** `CONFIRMED`
- **Notes:** Dot, spaced gap of $2\text{ units}$, two continuous dots (`. ..`). **Distinct from International Morse** (where `R` is `.-.`).

---

#### Character: `S`
- **Character Topology:** Three Dots
- **M1 Discrete Event Sequence:**
  ```text
  MARK(1)
  GAP(1)
  MARK(1)
  GAP(1)
  MARK(1)
  ```
- **Total Character Duration:** $1 + 1 + 1 + 1 + 1 = 5\text{ units}$
- **Primary Verifications:** Pope 1874 (§157, p. 101 / PDF p. 113); Pope 1891 (§372, p. 217 / PDF p. 241); Potter 1870 (p. 9 / PDF p. 19).
- **Status:** `CONFIRMED`

---

#### Character: `T`
- **Character Topology:** Single Short Dash
- **M1 Discrete Event Sequence:**
  ```text
  MARK(3)
  ```
- **Total Character Duration:** $3\text{ units}$
- **Primary Verifications:** Pope 1874 (§157, p. 101 / PDF p. 113); Pope 1891 (§372, p. 217 / PDF p. 241); Potter 1870 (p. 9 / PDF p. 19).
- **Status:** `CONFIRMED`

---

#### Character: `U`
- **Character Topology:** Dot, Dot, Dash
- **M1 Discrete Event Sequence:**
  ```text
  MARK(1)
  GAP(1)
  MARK(1)
  GAP(1)
  MARK(3)
  ```
- **Total Character Duration:** $1 + 1 + 1 + 1 + 3 = 7\text{ units}$
- **Primary Verifications:** Pope 1874 (§157, p. 101 / PDF p. 113); Pope 1891 (§372, p. 217 / PDF p. 241); Potter 1870 (p. 9 / PDF p. 19).
- **Status:** `CONFIRMED`

---

#### Character: `W`
- **Character Topology:** Dot, Dash, Dash
- **M1 Discrete Event Sequence:**
  ```text
  MARK(1)
  GAP(1)
  MARK(3)
  GAP(1)
  MARK(3)
  ```
- **Total Character Duration:** $1 + 1 + 3 + 1 + 3 = 9\text{ units}$
- **Primary Verifications:** Pope 1874 (§157, p. 101 / PDF p. 113); Pope 1891 (§372, p. 217 / PDF p. 241); Potter 1870 (p. 9 / PDF p. 19).
- **Status:** `CONFIRMED`

---

#### Character: `1` *(Numeral One)*
- **Character Topology:** Dot, Dash, Dash, Dot
- **M1 Discrete Event Sequence:**
  ```text
  MARK(1)
  GAP(1)
  MARK(3)
  GAP(1)
  MARK(3)
  GAP(1)
  MARK(1)
  ```
- **Total Character Duration:** $1 + 1 + 3 + 1 + 3 + 1 + 1 = 11\text{ units}$
- **Primary Verifications:** Pope 1874 (§157, p. 101 / PDF p. 113); Pope 1891 (§372, p. 217 / PDF p. 241); Potter 1870 (Appendix, p. 21 / PDF p. 31).
- **Status:** `CONFIRMED`
- **Notes:** `.--.` in American Morse. **Distinct from International Morse** (where `1` is `.----` and `.--.` is `P`).

---

#### Character: `7` *(Numeral Seven)*
- **Character Topology:** Dash, Dash, Dot, Dot
- **M1 Discrete Event Sequence:**
  ```text
  MARK(3)
  GAP(1)
  MARK(3)
  GAP(1)
  MARK(1)
  GAP(1)
  MARK(1)
  ```
- **Total Character Duration:** $3 + 1 + 3 + 1 + 1 + 1 + 1 = 11\text{ units}$
- **Primary Verifications:** Pope 1874 (§157, p. 101 / PDF p. 113); Pope 1891 (§372, p. 217 / PDF p. 241); Potter 1870 (Appendix, p. 21 / PDF p. 31).
- **Status:** `CONFIRMED`
- **Notes:** `--..` in American Morse. **Distinct from International Morse** (where `7` is `--...` and `--..` is `Z`).

---

#### Delimiter: `[SPACE]` *(Inter-Word Gap)*
- **M1 Discrete Event:**
  ```text
  GAP(6)
  ```
- **Total Duration:** $6\text{ units}$
- **Primary Verifications:** Pope 1874 (§151, p. 96 / PDF p. 108); Pope 1891 (§372, p. 218 / PDF p. 242).
- **Status:** `CONFIRMED` *(Delimiter Timing Policy)*
- **Notes:** Equal to two letter spaces ($3 \times 2 = 6$). Inserted by the encoder between words. (See Section 8.2 for architectural handling).

---

## 5. Summary Table: M1 Character Coverage

| Symbol | Character Topology | M1 Discrete Event Sequence | Total Duration | Primary Verification (Pope 1874 / 1891 / Potter 1870) | Status |
| :---: | :--- | :--- | :---: | :--- | :---: |
| **`A`** | Dot, Dash | `MARK(1), GAP(1), MARK(3)` | 5 | Pope 1874, p. 101; Pope 1891, p. 217; Potter, p. 6 | `CONFIRMED` |
| **`C`** | Dot, Dot, [Space], Dot | `MARK(1), GAP(1), MARK(1), GAP(2), MARK(1)` | 6 | Pope 1874, p. 100-101; Pope 1891, p. 217; Potter, p. 6 | `CONFIRMED` |
| **`D`** | Dash, Dot Dot | `MARK(3), GAP(1), MARK(1), GAP(1), MARK(1)` | 7 | Pope 1874, p. 101; Pope 1891, p. 217; Potter, p. 9 | `CONFIRMED` |
| **`E`** | Dot | `MARK(1)` | 1 | Pope 1874, p. 101; Pope 1891, p. 217; Potter, p. 9 | `CONFIRMED` |
| **`F`** | Dot, Dash, Dot | `MARK(1), GAP(1), MARK(3), GAP(1), MARK(1)` | 7 | Pope 1874, p. 101; Pope 1891, p. 217; Potter, p. 9 | `CONFIRMED` |
| **`G`** | Dash Dash, Dot | `MARK(3), GAP(1), MARK(3), GAP(1), MARK(1)` | 9 | Pope 1874, p. 101; Pope 1891, p. 217; Potter, p. 9 | `CONFIRMED` |
| **`H`** | Four Dots | `MARK(1), GAP(1), MARK(1), GAP(1), MARK(1), GAP(1), MARK(1)` | 7 | Pope 1874, p. 101; Pope 1891, p. 217; Potter, p. 9 | `CONFIRMED` |
| **`I`** | Two Dots | `MARK(1), GAP(1), MARK(1)` | 3 | Pope 1874, p. 101; Pope 1891, p. 217; Potter, p. 9 | `CONFIRMED` |
| **`L`** | Long Dash | `MARK(6)` | 6 | Pope 1874, p. 96, 101; Pope 1891, p. 218; Potter, p. 6 | `CONFIRMED` |
| **`N`** | Dash, Dot | `MARK(3), GAP(1), MARK(1)` | 5 | Pope 1874, p. 101; Pope 1891, p. 217; Potter, p. 9 | `CONFIRMED` |
| **`O`** | Dot, [Space], Dot | `MARK(1), GAP(2), MARK(1)` | 4 | Pope 1874, p. 100-101; Pope 1891, p. 217; Potter, p. 6 | `CONFIRMED` |
| **`R`** | Dot, [Space], Dot Dot | `MARK(1), GAP(2), MARK(1), GAP(1), MARK(1)` | 6 | Pope 1874, p. 100-101; Pope 1891, p. 217; Potter, p. 6 | `CONFIRMED` |
| **`S`** | Three Dots | `MARK(1), GAP(1), MARK(1), GAP(1), MARK(1)` | 5 | Pope 1874, p. 101; Pope 1891, p. 217; Potter, p. 9 | `CONFIRMED` |
| **`T`** | Short Dash | `MARK(3)` | 3 | Pope 1874, p. 101; Pope 1891, p. 217; Potter, p. 9 | `CONFIRMED` |
| **`U`** | Dot Dot, Dash | `MARK(1), GAP(1), MARK(1), GAP(1), MARK(3)` | 7 | Pope 1874, p. 101; Pope 1891, p. 217; Potter, p. 9 | `CONFIRMED` |
| **`W`** | Dot, Dash Dash | `MARK(1), GAP(1), MARK(3), GAP(1), MARK(3)` | 9 | Pope 1874, p. 101; Pope 1891, p. 217; Potter, p. 9 | `CONFIRMED` |
| **`1`** | Dot, Dash Dash, Dot | `MARK(1), GAP(1), MARK(3), GAP(1), MARK(3), GAP(1), MARK(1)` | 11 | Pope 1874, p. 101; Pope 1891, p. 217; Potter, p. 21 | `CONFIRMED` |
| **`7`** | Dash Dash, Dot Dot | `MARK(3), GAP(1), MARK(3), GAP(1), MARK(1), GAP(1), MARK(1)` | 11 | Pope 1874, p. 101; Pope 1891, p. 217; Potter, p. 21 | `CONFIRMED` |
| **`[SPACE]`** | Inter-Word Gap | `GAP(6)` | 6 | Pope 1874, p. 96; Pope 1891, p. 218 | `CONFIRMED` |

---

## 6. Critical Conflict Analysis & Historical Nuances

### 6.1 Contrast: `I` vs `O` vs `E E`
- `I`: Continuous dots $\rightarrow$ `MARK(1), GAP(1), MARK(1)` (Total: 3 units).
- `O`: Spaced dots $\rightarrow$ `MARK(1), GAP(2), MARK(1)` (Total: 4 units).
- `E E`: Two separate letters `E` $\rightarrow$ `MARK(1), GAP(3), MARK(1)` (Total: 5 units).
The distinction relies entirely on whether the internal gap is $1\text{ unit}$, $2\text{ units}$, or $3\text{ units}$. This acoustic subtlety is central to the telegrapher gameplay in **DEAD WIRE**.

### 6.2 Contrast: `T` vs `L` vs Numeral `0` (Historical Complexity)
- `T` (Short Dash): `MARK(3)` ($3\text{ units}$).
- `L` (Long Dash): `MARK(6)` ($6\text{ units}$).
- `0` (Cipher / Numeral Zero): **HISTORICAL VARIATION**.
  - Pope 1874 (§155, p. 99 / PDF p. 111) notes: "It will be observed that the same character is used for L and the cipher or 0. Occurring by itself or among letters it is always translated as L, but when found among figures becomes 0... It was formerly the custom to make the cipher equal to three short dashes [`MARK(9)`]."
  - Because Milestone 1 messages (`TRAIN 17 CLEAR EAST`, `HOLD FREIGHT UNTIL TEN`, `WATER`, `WATCHER`) require only digits `1` and `7`, numeral `0` is **DEFERRED — NOT REQUIRED FOR M1**.
  - `T` ($3\text{ units}$) and `L` ($6\text{ units}$) are completely unambiguous and verified.

### 6.3 Spaced Letters in American Morse
The six spaced letters of American Morse are:
- `C`: `.. .` $\rightarrow$ `MARK(1), GAP(1), MARK(1), GAP(2), MARK(1)` (Required for M1: `CLEAR`, `WATCHER`)
- `O`: `. .` $\rightarrow$ `MARK(1), GAP(2), MARK(1)` (Required for M1: `HOLD`)
- `R`: `. ..` $\rightarrow$ `MARK(1), GAP(2), MARK(1), GAP(1), MARK(1)` (Required for M1: `TRAIN`, `CLEAR`, `FREIGHT`, `WATER`, `WATCHER`)
- `Y`: `.. ..` $\rightarrow$ (Not required for M1)
- `Z`: `... .` $\rightarrow$ (Not required for M1)
- `&`: `. ...` $\rightarrow$ (Not required for M1)

All three M1-required spaced letters (`C`, `O`, `R`) are verified across Pope 1874, Pope 1891, and Potter 1870.

### 6.4 Differences Between American Morse and International Morse
| Symbol | American Morse (1894 Railroad Standard) | International Morse (ITU-R M.1677) | Collision / Confusion Consequence |
| :---: | :---: | :---: | :--- |
| **`F`** | `.-.` | `..-.` | `.-.` is International `R` |
| **`R`** | `. ..` | `.-.` | `. ..` does not exist in International |
| **`C`** | `.. .` | `-.-.` | `.. .` does not exist in International |
| **`O`** | `. .` | `---` | `. .` does not exist in International |
| **`L`** | Long dash (`MARK(6)`) | `.-..` | Long dash does not exist in International |
| **`1`** | `.--.` | `.----` | `.--.` is International `P` |
| **`7`** | `--..` | `--...` | `--..` is International `Z` |

---

## 7. Tech Lead Decision & Conflict Status

- **Confirmed Characters for M1:** 18 alphanumeric characters (`A`, `C`, `D`, `E`, `F`, `G`, `H`, `I`, `L`, `N`, `O`, `R`, `S`, `T`, `U`, `W`, `1`, `7`).
- **Confirmed Delimiters for M1:** Inter-Letter Gap (`GAP(3)`) and Inter-Word Gap (`GAP(6)`).
- **Deferred Elements:** Numeral `0` (historical variation between 6-unit and 9-unit dash; not required for M1 messages).
- **Unresolved Conflicts in M1 Scope:** **0 (NONE)**. Every required M1 character topology and baseline timing proportion is fully documented and resolved.
- **Inter-Character Delimiter Strategy:**
  - Character definitions store **only** internal elements (`MARK` events separated by intra-character `GAP(1)` or `GAP(2)`).
  - An encoder assembling a word inserts `GAP(3)` between consecutive letters.
  - An encoder assembling a sentence inserts `GAP(6)` between consecutive words.

---

## 8. Architectural Assessment of Gate 08A Data Model

We evaluate the Gate 08A timing primitives against the historical source requirements:

### Data Model Primitives:
1. `MorseTimingEvent`:
   - `kind: Kind` (`MARK` or `GAP`)
   - `duration_units: int`
2. `MorseSequenceData`:
   - `events: Array[MorseTimingEvent]`
   - `total_duration_units() -> int`
   - Validation API enforcing boundary conditions (`starts with MARK`, `ends with MARK`, `strictly alternating kinds`).

### Fidelity Check Across M1 Historical Timing Primitives:
1. **Dot:** `MorseTimingEvent(MARK, 1)` $\rightarrow$ **Exact Representation**.
2. **Short Dash:** `MorseTimingEvent(MARK, 3)` $\rightarrow$ **Exact Representation**.
3. **Long Dash:** `MorseTimingEvent(MARK, 6)` $\rightarrow$ **Exact Representation**.
4. **Ordinary Internal Gap:** `MorseTimingEvent(GAP, 1)` $\rightarrow$ **Exact Representation**.
5. **Spaced-Letter Internal Gap:** `MorseTimingEvent(GAP, 2)` $\rightarrow$ **Exact Representation**.
6. **Inter-Letter Gap:** `MorseTimingEvent(GAP, 3)` $\rightarrow$ **Exact Representation**.
7. **Inter-Word Gap:** `MorseTimingEvent(GAP, 6)` $\rightarrow$ **Exact Representation**.

### Invariant & Alternation Verification:
- Every character starts with a `MARK` and ends with a `MARK`.
- Concatenating Letter $A$ (`...MARK`) $+$ `GAP(3)` $+$ Letter $B$ (`MARK...`) produces a strictly alternating sequence (`MARK - GAP - MARK`).
- Concatenating Word $1$ (`...MARK`) $+$ `GAP(6)` $+$ Word $2$ (`MARK...`) produces a strictly alternating sequence (`MARK - GAP - MARK`).
- The resulting sequences completely satisfy all validation rules of `MorseSequenceData` without data loss or truncation.

### 8.1 TRUE SIGNAL Timing Determinism
TRUE SIGNAL timing is **deterministic and invariant**. The timing data model does NOT introduce random operator jitter or fatigue drift in the underlying data. Distortion belongs strictly to the downstream **ELIAS PERCEPTION** and gameplay layers.

### 8.2 Space Character Architectural Handling
- Standalone `MorseSequenceData([GAP(6)])` is intentionally invalid because sequences must start and end with `MARK`.
- `[SPACE]` is NOT an alphabet character resource; it is an encoder-level delimiter inserted during message composition.
- The `AmericanMorseAlphabet` resource will store only characters that produce valid alternating `MorseSequenceData`.

### **Architectural Evaluation Result: PASS**

---

## 9. Next Steps (Gate 08B-2 Preview)

This audit formally approves the historical foundation for **Gate 08B-2 (American Morse Alphabet Data & Encoder)**:
- Create `AmericanMorseAlphabet` mapping resource implementing the 18 confirmed M1 characters.
- Create unit tests validating timing durations, sequence alternation, and encoding of the four M1 messages.
- Proceed strictly within data-model scope without audio nodes, hardware sounders, or playback loops.

---

## 10. Unverified Supplementary Research Leads

The following secondary/period sources were identified during background research but **were not used as active evidence** in the primary tables of this audit because specific pages have not been directly verified in primary scans:
1. **William Maver Jr. (1892):** *American Telegraphy: Systems, Apparatus, Operation*, New York: J.H. Bunnell & Co. (Preserved as a supplementary reference lead).
2. **John Patterson Abernethy (1887):** *The Modern Service of Commercial and Railway Telegraphy*, 5th ed., Cleveland. (Preserved as a supplementary reference lead).
3. **George B. Prescott (1866):** *History, Theory, and Practice of the Electric Telegraph*, Boston: Ticknor and Fields. (Preserved as a supplementary reference lead).
4. **Thomas D. Lockwood (1883):** *Electricity, Magnetism, and Electro-Telegraphy*, New York: D. Van Nostrand. (Preserved as a supplementary reference lead).
