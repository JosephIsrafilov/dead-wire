# Implementation review findings and resolutions

## Standards

No hard AGENTS.md/HANDOVER violations were reported. Two judgment risks accepted:
- Editor deferred focus/capture callbacks checked tree membership only before awaiting a frame.
  Reproduced detached callback with get_tree null SCRIPT ERROR and off-tree grab_focus ERROR;
  now both callbacks revalidate tree/lifetime after await. Tests/ui/amendment_lifetime_test.gd,
  red/green logs in this directory. This is a real lifecycle repair, not a broad refactor.
- Routing action whitelist duplicated in board/session. Added one RouteAction value vocabulary,
  retained independent checks at both authority and presentation. No routing framework expansion.

## Spec

Two violations of accepted S2 were reproduced RED and repaired GREEN:
- Session routing could be reentered via routing_resolved before completion, or scenario replaced.
  Resolution now sets authority decision guard before partial-sheet/fact callbacks, captures original
  scenario/outcome, records completion for that scenario, and finishes with immutable old-slot payload.
  Guard clears only after COMPLETE state transition so legitimate session_completed progression can
  synchronously load the next slot. Duplicate route, lapse/reset/load during acceptance are rejected.
- Office load mutated _scenario_index and reset desk/window before session rejected reentrant load.
  Office preflights session.can_load_scenario before any office attribution or UI mutation. Invalid
  resource data follows the same no-op rejection. _bind_signals is idempotent; no accepted UI reset.

Tests: route_reentrancy_test.gd, office_load_atomicity_test.gd, actual office route_deadline_test.gd;
full regression after fixes required. No additional tape/correction validation/input blockers were
reported. Review was static read-only; parent reproduced and verified each accepted defect.

No new mechanics, deadline changes, art changes, commit or push.
