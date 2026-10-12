# Applicability of upstream #117991 to DEAD WIRE crash

## Hypothesis (frozen before running)
The 0xC0000005 read at Godot RVA +0x547AF6 is an engine-side use-after-free in
`GDScriptLanguage::finish()` (gdscript.cpp:2239-2265): `s = s->next()` runs while the local
`Ref<GDScript> scr` still holds the previous node, so destroying `scr` can free the node `s`
already points at. Upstream PR #117991 clears `base`/`base_cache` inside `GDScript::clear()` so
the last base reference drops BEFORE the list advances.

Single variable changed per arm; engine binary frozen; ≤5 serial runs per arm.

## Applicability: CONFIRMED at source+binary level (high confidence)
- PR #117991: merged=true, merge commit 0dd6299f7146362d36b130ac1dc42406cfb3ede6, **milestone 4.8**,
  5 added lines in modules/gdscript/gdscript.cpp (clear(): base_cache + base).
- Our engine: 4.7.1.stable.official.a13da4feb. Saved exact-commit source `gdscript_exact_commit.cpp`
  GDScript::clear() (line 1428..1485) ends with `functions_to_clear.clear();` — **no base/base_cache
  release**. Fix absent.
- Shipped binary (sha16 323f9c4cc5db674e, PE stripped): loop at 0x547AA0 is structurally
  GDScriptLanguage::finish: `mov r13,[rdi+1d0]` (script_list.first) @547ADC, faulting
  `mov r12,[r13+8]` (s->self()) @547AF6, `mov r13,[r13+0x10]` (s->next()) @547C53,
  `jne 0x547af6` @547C69. Same site as all three dumps.

So: our engine is affected by the code path the PR fixes. That is a *code-path* statement, not
proof that the specific freeing destructor in our crash is `base`.

## Control arm: upstream MRP on our engine = NO CRASH (INCONCLUSIVE, not "not affected")
Downloaded the official MRP from issue #117975 (heap-after-free.zip, 2292 B, HTTP 200) to scratch.
Scripts: base.gd (Node3D), child1.gd/child2.gd both `extends Base` with a typed cross-reference
(var helper: Child2 / var helper: Child1) — exactly the cyclic base pattern of the PR.
- run1: main scene UID unresolved (project not imported) → exit 1, not a crash observation.
- import: exit 0.
- run2 (frozen control, 60 s headless): **exit 0x00000000, no access violation.**

Conclusion: the MRP does not reproduce on our engine/build, so the trigger is heap-layout/ordering
dependent (upstream states it is rare and needed a TSAN build to see). Therefore:
- A clean MRP run is NOT evidence that our crash has another cause.
- A clean MRP run also gives NO evidence that #117991 would fix our crash.
Any statement stronger than "the code path is affected and the fix is absent" would be unfounded.

## Why no fix is applied in this pass
A verified fix would require an engine that actually contains the patch. Options and why each needs
owner approval (see approval_request.md): official 4.8-beta/rc build with #117991 (new engine +
matching export templates ~1.28 GB download), or a local source build (hours of SCons + templates).
Neither may be started without explicit permission, and neither may be assumed to resolve DEAD WIRE's
crash until a frozen-control comparison exists. No project-side speculative patch was applied: the
concrete `base`-trigger in our suites is not identified, and mass-removing type hints/preloads or
adding waits is explicitly forbidden.
