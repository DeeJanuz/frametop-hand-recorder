#!/usr/bin/env python3
"""The window (app/main.qml) loads offscreen against the real backend with no QML warning or
error, on every page and in the states tests/shoot.py drives (a dry-run backend on a scratch
base: no processes, no units, no network), and nothing is cut off or sticks out of the
1280x800 window. Skipped without PySide6.

  QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software python3 tests/test_window.py
"""
import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)


class WindowTest(unittest.TestCase):
    def test_pages(self):
        try:
            import PySide6.QtQuick  # noqa: F401
        except ImportError as e:
            self.skipTest(f"no PySide6: {e}")
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        os.environ.setdefault("QT_QUICK_BACKEND", "software")
        import shoot
        base = tempfile.mkdtemp(prefix="handrec-window-test-")
        try:
            problems, shots = shoot.run(os.path.join(base, "base"), out=None, log=lambda line: None)
        finally:
            shutil.rmtree(base, ignore_errors=True)
        self.assertGreater(len(shots), 20)
        self.assertEqual(problems, [])


if __name__ == "__main__":
    unittest.main()
