"""Unit tests for the playtest log summary (plan 10.6); stdlib only."""
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("summarize_playtest.py")
SPEC = importlib.util.spec_from_file_location("summarize_playtest", MODULE_PATH)
summarize_playtest = importlib.util.module_from_spec(SPEC)
sys.modules["summarize_playtest"] = summarize_playtest
SPEC.loader.exec_module(summarize_playtest)

SESSION = [
    {"t": 0.0, "event": "session_start", "build": ""},
    {"t": 3.2, "event": "document_opened", "id": "duty_sheet"},
    {"t": 9.0, "event": "signed_on", "station_time": "11:00 P.M."},
    {"t": 20.5, "event": "night_start"},
    {"t": 41.0, "event": "copy_finished", "scenario": "baseline_train_17"},
    {"t": 44.1, "event": "route", "action": "CLEAR EAST", "outcome": "CORRECT", "since_copy_s": 3.1},
    {"t": 60.0, "event": "tape_read"},
    {"t": 62.0, "event": "figure_visible"},
    {"t": 63.5, "event": "figure_observed"},
    {"t": 70.0, "event": "whisper_shown"},
    {"t": 72.0, "event": "paused"},
    {"t": 80.0, "event": "copy_finished", "scenario": "core_hook"},
    {"t": 95.0, "event": "filing", "scenario": "core_hook", "action": "file_amended", "word_length": 5, "since_copy_s": 15.0},
    {"t": 140.0, "event": "night_end"},
    {"t": 170.0, "event": "watch_closed"},
    {"t": 181.5, "event": "exit"},
    {"t": 181.6, "event": "session_end"},
]


class SummaryTests(unittest.TestCase):
    def _write(self, directory: Path, events: list[dict]) -> Path:
        path = directory / "session_1_1.jsonl"
        path.write_text("\n".join(json.dumps(e) for e in events) + "\n", encoding="utf-8")
        return path

    def test_summary_reports_the_night_a_moderator_needs(self):
        with tempfile.TemporaryDirectory() as directory:
            text = summarize_playtest.summarize(self._write(Path(directory), SESSION))
        for wanted in ("181.5", "duty_sheet", "CLEAR EAST", "CORRECT", "3.1", "file_amended",
                       "5 letters", "15.0", "figure seen 1", "looked at 1", "tape read 1",
                       "paused 1", "signed on", "closed the watch", "reached the exit"):
            with self.subTest(wanted=wanted):
                self.assertIn(wanted, text)

    def test_a_session_that_never_ends_says_so(self):
        with tempfile.TemporaryDirectory() as directory:
            text = summarize_playtest.summarize(self._write(Path(directory), SESSION[:6]))
        self.assertIn("did not reach the exit", text)

    def test_broken_lines_are_counted_not_fatal(self):
        with tempfile.TemporaryDirectory() as directory:
            path = self._write(Path(directory), SESSION)
            with path.open("a", encoding="utf-8") as handle:
                handle.write("{not json\n")
            text = summarize_playtest.summarize(path)
        self.assertIn("1 unreadable line", text)


if __name__ == "__main__":
    unittest.main()
