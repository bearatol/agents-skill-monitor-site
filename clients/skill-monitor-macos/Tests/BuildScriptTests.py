"""Regressions for generated build destinations; no compiler is executed."""

import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


class BuildDestinations(unittest.TestCase):
    def test_intermediate_symlink_is_rejected_before_compilation(self):
        repository = Path(__file__).resolve().parents[3]
        build = repository / "build"
        spec = importlib.util.spec_from_file_location("monitor_build", Path(__file__).resolve().parents[1] / "build.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory(prefix=".build-path-test-", dir=build) as temporary:
            root = Path(temporary) / "project"
            (root / "build").mkdir(parents=True)
            outside = Path(temporary) / "outside-output"
            outside.mkdir()
            (root / "build" / "skill-monitor-macos").symlink_to(outside, target_is_directory=True)
            module.ROOT = root
            module.OUTPUT = root / "build" / "skill-monitor-macos" / module.VERSION
            def forbidden_compiler(*arguments, **kwargs):
                self.fail("The unsafe output reached a compiler step")
            with patch("sys.argv", ["build.py", "--arch", "arm64"]), patch.object(module, "run", forbidden_compiler), \
                    patch.object(module.platform, "system", return_value="Darwin"):
                with self.assertRaisesRegex(SystemExit, "symlink"):
                    module.main()
            self.assertEqual(list(outside.iterdir()), [], "Rejected destination must remain untouched")


if __name__ == "__main__":
    unittest.main()
