"""The CI wrapper must reap both successful and failed builds."""
import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "scripts"))
from run_nxnative_ci import progress, supervise


class CIRunnerTests(unittest.TestCase):
    def test_collects_success_and_failure_without_a_heartbeat_hang(self):
        with tempfile.TemporaryDirectory() as temp:
            for code in (0, 7):
                output = Path(temp) / str(code)
                with contextlib.redirect_stdout(io.StringIO()):
                    result = supervise([sys.executable, "-c", f"print('private output'); raise SystemExit({code})"],
                                       output, "test/private", "test", tick=0.02, snapshot_interval=300)
                self.assertEqual(result, code)
                self.assertIn("private output", (output / "build-console.log").read_text())

    def test_public_progress_contains_counts_without_source_paths(self):
        with tempfile.TemporaryDirectory() as temp:
            log = Path(temp) / "console.log"
            log.write_text("private path /some/game/file\ncompiling: 35%, 9,800/27,984 shaders\n")
            self.assertEqual(progress(log), "Preparing shader libraries: 9,800 / 27,984")
            log.write_text("External resources: 18000 files\n")
            self.assertEqual(progress(log), "Archiving external resources: 18000 files")

    def test_upload_errors_do_not_change_build_exit_status(self):
        def fail(_):
            raise RuntimeError("private storage unavailable")
        with tempfile.TemporaryDirectory() as temp, contextlib.redirect_stdout(io.StringIO()):
            result = supervise([sys.executable, "-c", "import time; time.sleep(0.15)"], Path(temp),
                               "test/private", "test", tick=0.01, snapshot_interval=0.02, upload=fail)
        self.assertEqual(result, 0)


if __name__ == "__main__":
    unittest.main()
