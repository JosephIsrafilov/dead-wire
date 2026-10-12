import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "repro"))
import run_crash_probe


class CrashProbeTests(unittest.TestCase):
    def test_probe_records_separate_streams_and_unsigned_code_without_engine_run(self):
        class Completed:
            returncode = -1073741819
            stdout = b"probe stdout\n"
            stderr = b"probe stderr\n"

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            suite = root / run_crash_probe.SUITE
            suite.parent.mkdir(parents=True)
            suite.write_text("fixture\n", encoding="utf-8")
            engine = root / "fake-engine.exe"
            engine.write_bytes(b"engine")
            old_root = run_crash_probe.ROOT
            run_crash_probe.ROOT = root
            try:
                with patch.object(run_crash_probe.subprocess, "run", return_value=Completed()) as run:
                    with patch.object(run_crash_probe, "sha256", side_effect=lambda path: "hash"):
                        with patch.object(sys, "argv", ["run_crash_probe.py", "--godot", str(engine), "--out", "probe"]):
                            self.assertEqual(run_crash_probe.main(), 1)
                run.assert_called_once()
                command = run.call_args.args[0]
                self.assertIn("--verbose", command)
                self.assertIn("--headless", command)
                self.assertIn("Dummy", command)
                evidence_dir = next((root / "probe").iterdir())
                result = json.loads((evidence_dir / "result.json").read_text(encoding="utf-8"))
                self.assertEqual(result["returncode_hex"], "0xC0000005")
                self.assertEqual((evidence_dir / "stdout.log").read_bytes(), b"probe stdout\n")
                self.assertEqual((evidence_dir / "stderr.log").read_bytes(), b"probe stderr\n")
            finally:
                run_crash_probe.ROOT = old_root

    def test_default_output_has_unique_run_directory(self):
        # Run identifiers combine microsecond timestamps and random UUID material.
        first = run_crash_probe.datetime.now().strftime("%Y%m%d_%H%M%S_%f") + "_" + run_crash_probe.uuid.uuid4().hex[:8]
        second = run_crash_probe.datetime.now().strftime("%Y%m%d_%H%M%S_%f") + "_" + run_crash_probe.uuid.uuid4().hex[:8]
        self.assertNotEqual(first, second)


if __name__ == "__main__":
    unittest.main()
