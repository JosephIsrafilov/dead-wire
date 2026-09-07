# M1 Technical Debt Register

**Updated:** 2026-09-04

## Current verification baseline

The Windows runner completes **32/32 suites with 0 failures and 1273
assertions**. Both runners use Godot's `Dummy` audio driver in headless mode so
the result does not depend on a host audio device. Production-scene headless
boot and the main-menu-to-office smoke test also exit with code 0.

## Headless teardown resource warnings

Godot 4.7.1 can finish an individual test and the production scene with exit
code 0, while reporting ObjectDB/RID allocations during shutdown (including
Canvas, CanvasItem, viewport, texture, scene, and shaped-text resources). The
warnings reproduce in the restricted desktop session when Godot cannot create
its `user://` editor data directory. They are therefore not currently
attributed to an M1 scene or test fixture.

Follow-up: repeat the full `tools/run_all_tests.ps1` run on a clean Windows
machine with a writable Godot user directory, then capture `--verbose` output.
Only after that reproduction should individual scene/test ownership be fixed.
