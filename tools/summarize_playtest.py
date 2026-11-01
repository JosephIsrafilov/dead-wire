"""Summarize a DEAD WIRE playtest log (plan 10.6, ROADMAP 2.8).

The game writes user://playtest/session_<unix>_<ms>.jsonl for a watch begun
from the title: one JSON object per line with "t" (seconds) and "event". This
prints what a moderator needs beside the recording. Stdlib only.

    python tools/summarize_playtest.py <session.jsonl> [more.jsonl ...]
"""
from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path


def load(path: Path) -> tuple[list[dict], int]:
    events: list[dict] = []
    broken = 0
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            broken += 1
            continue
        if isinstance(item, dict) and "event" in item:
            events.append(item)
        else:
            broken += 1
    return events, broken


def summarize(path: Path) -> str:
    events, broken = load(path)
    counts = Counter(e["event"] for e in events)
    last = max((float(e.get("t", 0.0)) for e in events), default=0.0)
    exit_time = next((float(e["t"]) for e in events if e["event"] == "exit"), None)
    out = [f"Session {path.name}: {last:.1f} s logged, {len(events)} events"]
    if broken:
        out.append(f"  {broken} unreadable line" + ("s" if broken != 1 else ""))
    documents = Counter(e.get("id", "?") for e in events if e["event"] == "document_opened")
    if documents:
        out.append("  documents: " + ", ".join(f"{name} x{n}" for name, n in sorted(documents.items())))
    if counts["signed_on"]:
        out.append("  signed on in the ledger")
    for e in events:
        if e["event"] == "route":
            out.append(f"  route at {float(e['t']):.1f} s: {e.get('action')} -> {e.get('outcome')}"
                       f" ({float(e.get('since_copy_s', -1)):.1f} s after the copy)")
        elif e["event"] == "filing":
            out.append(f"  filing at {float(e['t']):.1f} s: {e.get('action')}, {e.get('word_length')} letters"
                       f" ({float(e.get('since_copy_s', -1)):.1f} s after the copy)")
        elif e["event"] in ("traffic_missed", "route_defaulted"):
            out.append(f"  {e['event'].replace('_', ' ')} at {float(e['t']):.1f} s (slot {e.get('slot')})")
    out.append(f"  figure seen {counts['figure_visible']}, looked at {counts['figure_observed']}")
    out.append(f"  tape read {counts['tape_read']}, register wound {counts['register_wound']}")
    out.append(f"  whisper shown {counts['whisper_shown']}; paused {counts['paused']}")
    if counts["watch_closed"]:
        out.append("  closed the watch in the ledger")
    if exit_time is not None:
        out.append(f"  reached the exit at {exit_time:.1f} s")
    else:
        out.append("  did not reach the exit")
    return "\n".join(out)


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    for name in argv:
        print(summarize(Path(name)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
