# State Contract — DEAD WIRE

## Core Separation of Concerns

DEAD WIRE divides runtime story and simulation state into two physically and semantically independent systems:

```text
WORLDSTATE
Objective truth: what actually happened in the world.

KNOWLEDGESTATE
Subjective truth: what Elias has acquired and knows.
```

---

## Architectural Invariants

1. **Objective Truth vs. Acquired Knowledge:**
   - `WorldState` stores the ground-truth state of the environment, objects, and characters.
   - `KnowledgeState` stores exclusively what facts Elias has discovered, read, or deduced.

2. **Independence of Fact Identifiers:**
   - The same `fact_id: StringName` (e.g. `&"eleanor_alive"`) can exist independently in both stores with different meanings (`WorldState` stores the objective value `true`, while `KnowledgeState` stores whether Elias has learned it).

3. **No Automatic Cross-Coupling:**
   - Mutating `WorldState` (via `WorldState.set_fact()`) **never** automatically invokes `KnowledgeState.learn()`.
   - Acquiring knowledge (via `KnowledgeState.learn()`) **never** mutates `WorldState`.

4. **External Narrative Layers:**
   - Written Transcripts, Elias Perception, and UI representation do **not** automatically belong to or derive from either store.
   - Narrative triggers and game systems must explicitly write each transition to the intended layer.

---

## Minimal Example

```gdscript
# An objective event occurs in the world:
WorldState.set_fact(&"eleanor_alive", true)

# Elias does not know this yet:
assert(KnowledgeState.knows(&"eleanor_alive") == false)

# Elias reads a telegram or discovers a clue:
KnowledgeState.learn(&"eleanor_alive")

# Elias now knows, while the objective world state remains intact:
assert(KnowledgeState.knows(&"eleanor_alive") == true)
assert(WorldState.get_fact(&"eleanor_alive") == true)
```
