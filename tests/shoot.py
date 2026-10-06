#!/usr/bin/env python3
"""Screenshots of the Hand Recorder's window (app/main.qml), offscreen, failing on any QML
warning or layout problem.

It loads the window as ft_handrec.main() does (QGuiApplication, the Basic style, a Backend with
the frames image provider, the backend and startPage context properties), but with a dry-run
backend on a scratch base: sessions start no processes and Upload makes no network calls. To be
sure nothing on the headset is touched, the session module's host commands, unit starts and
camera broker are stubbed out before anything can call them, and so is the headset-worn check.
Then it shows each page, in the states worth looking at, and saves window.grabWindow() as PNG.

  QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software frame-job --local -- \\
      .venv/bin/python tests/shoot.py --base /tmp/hr-port-test --out /tmp/hr-port-shots

--base is emptied first (it must be a scratch folder, never the real one). Exits 1 on any QML
warning or error, or when text is cut off or something sticks out of the window (listed).
tests/test_window.py runs the same without saving.
"""
import argparse
import os
import shutil
import sys
import threading
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REC = os.path.join(ROOT, "frametop", "hands", "rec")
QML = os.path.join(ROOT, "app", "main.qml")
sys.path.insert(0, REC)
sys.path.insert(0, os.path.join(REC, "tests"))

SESSION_A = "20261002-101500"   # exported, with a deleted range
SESSION_B = "20261003-184200"   # not exported
WIDTH, HEIGHT = 1280, 800
FONT = "Noto Sans"   # Theme.fontFamily, as on SteamOS
# Messages from the platform, not the window (none here; containers without a session can
# print these).
BENIGN = ("This plugin does not support propagateSizeHints()", "QStandardPaths: XDG_RUNTIME_DIR")
REAL_BASE = os.path.realpath(os.path.expanduser("~/.local/share/frametop/hands/contrib"))


def make_safe():
    """Stub out everything in the session module that runs host commands or starts units, so
    a slip (Restart SteamVR, the light check's ft-camd start) runs nothing."""
    import ft_handrec
    import session
    import takes

    def refuse(*_a, **_k):
        raise RuntimeError("test: not started")
    session.host_command = lambda *cmd: ["false"]
    session.start_unit = refuse
    session.stop_unit = lambda *_a, **_k: None
    session.unit_active = lambda *_a, **_k: False
    session.start_camd = lambda *_a, **_k: False
    session.ring_lighting = lambda *_a, **_k: None   # no camera ring: deterministic, reads nothing
    session.camera_check = lambda repair=False: {"status": "unknown", "summary": "unknown: test",
                                                 "reason": "test", "evidence": []}
    session.host_path = lambda path: None             # no factory calibration copied into the base
    ft_handrec.headset_worn = lambda: False
    takes.free_bytes = lambda path: FREE["bytes"]

    class QuietPanel(session.Panel):
        """The dry-run panel, without printing its commands."""
        def __init__(self, *a, **k):
            k["out"] = lambda *_a, **_k: None
            super().__init__(*a, **k)
    session.Panel = QuietPanel


FREE = {"bytes": 120 * 1000 ** 3}


class DummySession:
    """Stands in for a running session for the made-up session states."""
    session_dir = ""

    def __getattr__(self, name):
        return lambda *a, **k: None


class Shooter:
    def __init__(self, out=None, log=print):
        from PySide6.QtCore import QtMsgType, qInstallMessageHandler
        from PySide6.QtGui import QGuiApplication
        from PySide6.QtQuickControls2 import QQuickStyle
        self.out = out
        self.log = log
        self.problems = []
        self.shots = []
        self.app = QGuiApplication.instance() or QGuiApplication([sys.argv[0]])
        self.app.setApplicationName("ft-handrec")
        QQuickStyle.setStyle("Basic")
        kinds = {QtMsgType.QtWarningMsg, QtMsgType.QtCriticalMsg, QtMsgType.QtFatalMsg}

        def handler(mode, context, message):
            if mode in kinds and not any(b in message for b in BENIGN):
                where = f"{context.file}:{context.line}: " if context and context.file else ""
                self.problem(where + message)
        qInstallMessageHandler(handler)
        self.keep = []    # backends and engines live to the end (their threads may still report)

    def problem(self, text):
        if text not in self.problems:
            self.problems.append(text)
            self.log("PROBLEM: " + text)

    # --- the window
    def load(self, base, start_page=""):
        import ft_handrec
        import takes
        from PySide6.QtCore import QUrl
        from PySide6.QtQml import QQmlApplicationEngine, QQmlEngine
        store = takes.Store(base)
        engine = QQmlApplicationEngine()
        engine.warnings.connect(lambda errors: [self.problem(e.toString()) for e in errors])
        engine.addImageProvider("frames", ft_handrec.FrameProvider(store))
        backend = ft_handrec.Backend(store, {"dry_run": True, "speed": 20}, hub_dry_run=True)
        engine.rootContext().setContextProperty("backend", backend)
        engine.rootContext().setContextProperty("startPage", start_page)
        engine.load(QUrl.fromLocalFile(QML))
        if not engine.rootObjects():
            self.problem("main.qml didn't load")
            raise SystemExit(1)
        self.keep += [engine, backend]
        self.engine, self.backend, self.window = engine, backend, engine.rootObjects()[0]
        self.ctx = QQmlEngine.contextForObject(self.window)
        self.wait(400)
        if (self.window.width(), self.window.height()) != (WIDTH, HEIGHT):
            self.problem(f"window is {self.window.width()}x{self.window.height()}, not {WIDTH}x{HEIGHT}")
        from PySide6.QtGui import QFontInfo
        family = QFontInfo(self.window.property("font")).family()
        if family != FONT:   # listed first: another font lays out differently, so cut-offs follow
            self.problem(f"the window's font is {family!r}, not {FONT!r}: install it (Ubuntu: fonts-noto-core)")

    def close(self):
        self.backend.shutdown()
        self.window.setProperty("quitting", True)
        self.window.hide()
        self.wait(50)

    def finish(self):
        """Delete the windows before their backends, so no binding sees a backend gone."""
        for obj in self.keep:
            if obj.inherits("QQmlApplicationEngine"):
                obj.deleteLater()
        self.wait(100)
        self.keep = []

    def js(self, code):
        from PySide6.QtQml import QQmlExpression
        expr = QQmlExpression(self.ctx, self.window, code)
        value = expr.evaluate()
        if expr.hasError():
            self.problem(f"js {code!r}: {expr.error().toString()}")
        return value[0] if isinstance(value, tuple) else value

    def later(self, code, ms=300):
        """Run code from the event loop, then wait. Anything that loads image://frames goes this
        way: evaluated directly, it runs with the GIL held, and the image loader thread, which
        needs it for the provider, deadlocks against the next image request."""
        self.js("Qt.callLater(function() { %s })" % code)
        self.wait(ms)

    def wait(self, ms):
        from PySide6.QtCore import QEventLoop, QTimer
        loop = QEventLoop()
        QTimer.singleShot(ms, loop.quit)
        loop.exec()

    def wait_for(self, check, timeout=30.0, step=50):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            if check():
                return True
            self.wait(step)
        return False

    def show(self, page):
        self.later(f"root.show({page}Page)")

    def flick(self):
        return self.js("pageStack.currentItem.flickable || null")

    def scroll(self, y):
        self.js(f"(f => {{ if (f) f.contentY = Math.max(0, Math.min({y}, f.contentHeight - f.height)) }})"
                "(pageStack.currentItem.flickable)")
        self.wait(100)

    def scroll_to_text(self, text):
        """Scroll the current page so the label with this text is near the top."""
        item = self.find_text(self.js("pageStack.currentItem"), text)
        flick = self.flick()
        if item is None or flick is None:
            self.problem(f"no {text!r} to scroll to")
            return
        from PySide6.QtCore import QPointF
        y = item.mapToItem(flick.property("contentItem"), QPointF(0, 0)).y()
        self.scroll(y - 20)

    def find_text(self, item, text):
        if item is None:
            return None
        if item.inherits("QQuickText") and item.property("text") == text and item.isVisible():
            return item
        for child in item.childItems():
            found = self.find_text(child, text)
            if found is not None:
                return found
        return None

    def find_combo(self, item, text):
        if item is None:
            return None
        if item.inherits("QQuickComboBox") and item.property("displayText") == text and item.isVisible():
            return item
        for child in item.childItems():
            found = self.find_combo(child, text)
            if found is not None:
                return found
        return None

    def find_button(self, item, text):
        if item is None:
            return None
        if item.inherits("QQuickAbstractButton") and item.property("text") == text and item.isVisible():
            return item
        for child in item.childItems():
            found = self.find_button(child, text)
            if found is not None:
                return found
        return None

    def shoot(self, name, settle=250):
        self.wait(settle)
        self.check_layout(name)
        if self.out:
            path = os.path.join(self.out, name + ".png")
            if not self.window.grabWindow().save(path):
                self.problem(f"couldn't save {path}")
            self.shots.append(path)
        else:
            self.window.grabWindow()
            self.shots.append(name)
        self.log("shot " + name)

    def shoot_pages(self, name, limit=12):
        """The current page from the top, a screen at a time."""
        flick = self.flick()
        self.scroll(0)
        if flick is None:
            self.shoot(name)
            return
        step = max(200, flick.property("height") - 120)
        k, y = 1, 0
        while True:
            self.scroll(y)
            self.shoot(f"{name}-{k}")
            if y + flick.property("height") >= flick.property("contentHeight") - 1 or k >= limit:
                break
            k, y = k + 1, y + step
        self.scroll(0)

    # --- layout checks: cut-off text, and things outside the window or a scroll area's width
    def check_layout(self, shot):
        from PySide6.QtCore import QRectF
        win = QRectF(0, 0, self.window.width(), self.window.height())
        self._walk(self.window.contentItem(), win, False, shot)

    def on(self, item, code):
        """Evaluate code with item as its scope (for what PySide6 can't convert, such as enums
        and a combo box's popup)."""
        from PySide6.QtQml import QQmlExpression
        expr = QQmlExpression(self.ctx, item, code)
        value = expr.evaluate()
        if expr.hasError():
            self.problem(f"js {code!r}: {expr.error().toString()}")
        return value[0] if isinstance(value, tuple) else value

    def _read(self, item, name):
        return self.on(item, f"Number({name})")

    def _describe(self, item):
        text = item.property("text") if item.inherits("QQuickText") or item.inherits("QQuickTextEdit") else ""
        name = item.metaObject().className()
        return f"{name} {str(text)[:60]!r}" if text else name

    def _walk(self, item, clip, scrolled, shot):
        from PySide6.QtCore import QPointF, QRectF
        if not item.isVisible() or item.opacity() == 0:
            return
        w, h = item.width(), item.height()
        p = item.mapToScene(QPointF(0, 0))
        rect = QRectF(p.x(), p.y(), w, h)
        if w > 0 and h > 0 and clip is not None:
            if rect.right() > clip.right() + 1.5 or rect.left() < clip.left() - 1.5:
                self.problem(f"[{shot}] {self._describe(item)} sticks out sideways "
                             f"({rect.left():.0f}..{rect.right():.0f}, room {clip.left():.0f}..{clip.right():.0f})")
            if not scrolled and rect.bottom() > clip.bottom() + 1.5:
                self.problem(f"[{shot}] {self._describe(item)} sticks out at the bottom "
                             f"({rect.bottom():.0f} > {clip.bottom():.0f})")
        if item.inherits("QQuickText"):
            if item.property("truncated"):
                self.problem(f"[{shot}] {self._describe(item)} is cut off (elided)")
            elif (w > 0 and item.property("contentWidth") > w + 1.5
                  and self._read(item, "wrapMode") == 0 and self._read(item, "elide") == 0):
                self.problem(f"[{shot}] {self._describe(item)} is wider than its box "
                             f"({item.property('contentWidth'):.0f} > {w:.0f})")
        child_clip, child_scrolled = clip, scrolled
        if item.inherits("QQuickFlickable"):
            child_clip, child_scrolled = rect.intersected(clip) if clip is not None else rect, True
        elif item.clip():
            child_clip = None     # clipped on purpose (a progress bar's sweep): not checked inside
        for child in item.childItems():
            self._walk(child, child_clip, child_scrolled, shot)


def seed(base):
    """Two recorded sessions (test_validate.make_session), the first with a deleted range and
    exported."""
    import takes
    import test_validate
    contributor = test_validate.make_session(base, sid=SESSION_A)
    test_validate.make_session(base, contributor=contributor, sid=SESSION_B)
    store = takes.Store(base)
    index = takes.take_index(store.take_dir(SESSION_A, "01-hand-size"))
    store.delete_range(SESSION_A, "01-hand-size", index.time_ns(3), index.time_ns(5))
    if takes.find_zstd():
        store.export(SESSION_A, low_priority=True)
    return takes.find_zstd() is not None


def fake_status(**kw):
    status = {"state": "ready", "mode": "step", "section": "hand-size", "title": "Hand size",
              "section_index": 1, "section_count": 4, "step_index": 2, "step_count": 6, "prompt": "",
              "seconds_left": 0.0, "note": "", "hands": {"left": None, "right": None}, "take": "01-hand-size",
              "error": "", "waiting": False, "countdown": 0, "big": "", "can_redo": True, "image": "",
              "image_mode": "", "caption": "", "position": "", "distance": "", "ready_text": "", "button": True,
              "mouse": False, "camera": None, "nohands": False, "strip": [], "cue": -1, "quick": True}
    status.update(kw)
    return status


def session_states(s):
    """Made-up session states, the fullest the page has to fit (no session runs)."""
    import session
    b = s.backend
    poses = os.path.join(REC, "poses")
    b._session = DummySession()
    states = [
        ("session-ready", fake_status(
            state="ready", waiting=True, image=os.path.join(poses, "spread.png"), image_mode="both",
            caption="Both hands, fingers spread wide, palms towards you",
            position="centre", distance="mid", button=True, ready_text=session.READY_BUTTON,
            prompt="Hold both hands up in front of you, fingers spread, and turn them slowly",
            note="Your left hand is hard to see: hold it a little higher.",
            hands={"left": "lost", "right": "seen"})),
        ("session-sweep", fake_status(
            state="running", section="pose-sweeps", title="Hand poses", section_index=2, step_index=3,
            step_count=12, take="02-pose-sweeps", big="Go", seconds_left=7.4, position="right", distance="far",
            prompt="Keep your right hand moving: make each shape as it lights up",
            strip=[{"image": os.path.join(poses, p + ".png"), "mode": "", "label": p.replace("-", " ").capitalize()}
                   for p in ("count-1", "count-2", "count-3", "count-4", "count-5")], cue=2,
            note="Keep your hand inside the frame.", hands={"left": None, "right": "seen"})),
        ("session-sweep-waiting", fake_status(
            state="ready", waiting=True, section="pose-sweeps", title="Hand poses", section_index=2,
            step_index=1, step_count=12, take="02-pose-sweeps", position="centre", distance="near",
            prompt="Both hands: open, fist, point, pinch, following the pictures",
            strip=[{"image": os.path.join(poses, p + ".png"), "mode": m, "label": p.capitalize()}
                   for p, m in (("open", ""), ("fist", "mirror"), ("point", ""), ("pinch", "mirror"))], cue=0,
            ready_text=session.READY_BUTTON_MOUSE, hands={"left": "seen", "right": "seen"})),
        ("session-countdown", fake_status(
            state="countdown", big="3", image=os.path.join(poses, "fist.png"), image_mode="mirror",
            caption="Left hand, a fist", position="left", distance="near", prompt="Make a fist with your left hand")),
        ("session-nohands", fake_status(
            state="nohands", waiting=True, prompt="The cameras didn't see your hands in that step.",
            note="Check the light, and that nothing covers the cameras.")),
        ("session-paused", fake_status(state="paused", prompt="Paused", mode="auto", step_index=0)),
    ]
    for name, status in states:
        b._on_status(status)
        s.shoot(name, settle=500)
    b._session = None
    b._session_id = SESSION_B
    b._on_status(fake_status(state="done", take=None, can_redo=False, prompt="That's all. Thank you!"))
    s.shoot("session-done")
    b._status, b._session_id = {}, ""
    b.statusChanged.emit()


def dry_run_session(s):
    """A real dry-run session (Session(dry_run=True): no processes, no units, no camera check),
    stepped through for a few states, then stopped."""
    b = s.backend
    answers = {"objects": ["pencil", "phone"], "own_objects": [], "controllers": "none", "sleeves": "short",
               "rings": False, "watch": False, "notes": "", "privacy": True}
    if not b.startSession(answers, "auto", False, True):
        s.problem("the dry-run session didn't start")
        return
    s.later("root.show(sessionPage)")
    seen, nexts = set(), 0
    end = time.monotonic() + 40
    while time.monotonic() < end and len(seen) < 6:
        st = dict(b.status)
        key = (st.get("state"), bool(st.get("strip")))
        if key not in seen and st.get("state") not in (None, "starting"):
            seen.add(key)
            s.shoot("session-dry-%d-%s%s" % (len(seen), st.get("state"), "-strip" if st.get("strip") else ""),
                    settle=60)
        if st.get("waiting"):
            nexts += 1
            b.nextStep()
            if nexts % 3 == 0 and not st.get("strip"):
                b.skipSection()     # on to the poses' strips
        s.wait(60)
    s.show("checklist")
    s.shoot("checklist-session-running")
    s.later("root.show(sessionPage)")
    b.stopSession()
    if not s.wait_for(lambda: not b.sessionActive, 30):
        s.problem("the dry-run session didn't stop")
    s.shoot("session-dry-stopped")


def run(base, out=None, log=print, live_session=True):
    """Every shot; returns (problems, shots)."""
    if os.path.realpath(base) == REAL_BASE or os.path.realpath(base).startswith(REAL_BASE + os.sep):
        raise SystemExit("refusing to use the real base: pass a scratch folder")
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    os.environ.setdefault("QT_QUICK_BACKEND", "software")
    if os.path.isdir(base) and set(os.listdir(base)) - {"empty", "data"}:
        raise SystemExit(f"refusing to empty {base}: it holds more than this script's scratch folders")
    make_safe()
    shutil.rmtree(base, ignore_errors=True)
    empty, data = os.path.join(base, "empty"), os.path.join(base, "data")
    os.makedirs(empty)
    if out:
        os.makedirs(out, exist_ok=True)
    s = Shooter(out, log)
    try:
        shots(s, empty, data, live_session)
    finally:
        s.finish()
    return s.problems, s.shots


def shots(s, empty, data, live_session):
    # 1. Nothing yet: the consent first.
    s.load(empty)
    if s.js("pageStack.currentItem.title") != "Welcome":
        s.problem("an empty base doesn't open on Welcome")
    s.shoot_pages("welcome-consent", limit=2)
    s.scroll(10 ** 6)
    s.shoot("welcome-consent-end")
    s.show("review")
    s.shoot("review-empty")
    s.close()

    # 2. Agreed, with two recorded sessions.
    exported = seed(data)
    s.load(data, "review")
    b = s.backend
    if s.js("pageStack.currentItem.title") != "Review":
        s.problem("--page review doesn't open on Review before the consent")
    # The profile agreed to an older CONSENT.md: Welcome asks again, keeping the contributor id.
    s.show("welcome")
    s.scroll(10 ** 6)
    s.shoot("welcome-changed-end")
    b.acceptConsent(True, True, True, "right")
    s.wait(100)
    s.js("toast.opacity = 0")   # its "Thank you" would cover the next shots
    s.show("welcome")
    s.scroll(10 ** 6)
    s.shoot("welcome-agreed-end")

    s.show("checklist")
    s.wait_for(lambda: b.cameraState != "checking" and b.lightingMeasured != "Measuring…", 10)
    s.shoot_pages("checklist")
    b._camera = {"status": "degraded", "reason": "slam_upper_left, slam_upper_right not streaming",
                 "summary": "degraded: 2 of 4 cameras", "evidence": ["XRService log: TrackingCameraInit failed",
                                                                     "ring: 2 of 4 mono cameras"]}
    b.cameraChanged.emit()
    s.shoot("checklist-camera-error")
    s.scroll_to_text("Lighting this round")
    combo = s.find_combo(s.js("pageStack.currentItem"), "Measured by the cameras")
    if combo is None:
        s.problem("no lighting combo box")
    else:
        s.on(combo, "popup.open()")
        s.shoot("checklist-combo-open", settle=400)
        s.on(combo, "popup.close()")
        s.wait(200)
    s.scroll_to_text("Cameras")
    details = s.find_button(s.js("pageStack.currentItem"), "Details")
    if details is None:
        s.problem("no Details button")
    else:
        details.setProperty("checked", True)
    s.shoot("checklist-camera-section")
    b._camera = {}
    b.cameraChanged.emit()
    FREE["bytes"] = 3 * 1000 ** 3
    b.diskChanged.emit()
    s.scroll_to_text("Space")
    s.shoot("checklist-low-disk")
    FREE["bytes"] = 120 * 1000 ** 3
    b.diskChanged.emit()

    s.show("session")
    s.shoot("session-empty")
    session_states(s)
    if live_session:
        dry_run_session(s)

    s.show("review")
    s.shoot("review")
    s.later(f'pageStack.push(takesPage, {{ session: "{SESSION_A}" }})')
    s.shoot("takes", settle=600)
    s.later(f'pageStack.push(viewerPage, {{ session: "{SESSION_A}", take: "01-hand-size" }})')
    s.shoot("viewer", settle=800)
    s.later("pageStack.currentItem.index = 4; pageStack.currentItem.markStart = 10; pageStack.currentItem.markEnd = 15")
    s.shoot("viewer-deleted-marked", settle=800)
    s.later("pageStack.pop()")
    s.later("pageStack.pop()")
    if s.js("pageStack.depth") != 1:
        s.problem("Back didn't return to Review")

    s.js(f'root.chosenSession = "{SESSION_A}"')
    s.show("export")
    s.shoot("export-exported")
    s.js(f'root.chosenSession = "{SESSION_B}"')
    s.show("export")
    s.shoot("export-not-exported")
    b._export_cancel, b._export_session = threading.Event(), SESSION_B
    b._export_fraction, b._export_text = 0.42, "Compressing 01-hand-size: sets 12 of 30"
    b.exportChanged.emit()
    s.shoot("export-progress")
    b._export_cancel = None
    b._export_text = ""
    b.exportChanged.emit()

    s.js(f'root.chosenSession = "{SESSION_A}"')
    s.show("upload")
    if exported:
        s.shoot_pages("upload", limit=4)
        b._login = {"state": "waiting", "url": "https://huggingface.co/oauth/device?user_code=ABCD-EFGH",
                    "code": "ABCD-EFGH", "expires_in": 900, "text": ""}
        b.loginChanged.emit()
        s.scroll_to_text("2. Log in to Hugging Face")
        s.shoot("upload-login-waiting")
        b._login = {"state": "none", "text": "Not logged in"}
        b.loginChanged.emit()
        s.shoot("upload-login-none")
        b._login = {"state": "dry"}
        b.loginChanged.emit()
        # The dry-run upload: hub.py upload --dry-run checks the export; nothing goes out.
        s.js("pageStack.currentItem.startUpload()")
        if not s.wait_for(lambda: not b.uploading, 90):
            s.problem("the dry-run upload didn't finish")
        s.scroll_to_text("3. Upload")
        s.shoot("upload-dry-run-done")
        b._upload = {"session": SESSION_A, "phase": "failed", "text": "", "fraction": 0.0, "log": "",
                     "result": {}, "pr_url": "",
                     "error": {"kind": "invalid", "text": "The export has 2 problems, so it can't be uploaded. "
                               "Export the session again; if that doesn't help, report it.",
                               "errors": ["takes/01-hand-size/sets.bin.zst: checksum mismatch",
                                          "manifest.json: consent version 2026-10-02 isn't current"],
                               "link": "https://huggingface.co/datasets/DeeJanuz/frametop-hands"}}
        b.uploadChanged.emit()
        s.shoot("upload-failed")
        b._upload_proc = DummySession()
        b._upload = {"session": SESSION_A, "phase": "send", "text": "Sending 9 files (1.2 MB)", "fraction": -1.0,
                     "log": "", "result": {}, "error": {},
                     "pr_url": "https://huggingface.co/datasets/DeeJanuz/frametop-hands/discussions/12"}
        b.uploadChanged.emit()
        s.shoot("upload-sending")
        b._upload_proc = None
        b._upload = {}
        b.uploadChanged.emit()
    else:
        s.log("no zstd: nothing exported, so no upload states")
        s.shoot("upload-nothing-exported")

    # Dialogs and messages (never accepted).
    s.show("review")
    s.js('confirm.ask("Delete this session?", "The session of 2026-10-02 10:15 (2 takes, 1.2 MB) and its export '
         'are deleted from the headset for good.", () => {})')
    s.shoot("confirm-delete", settle=400)
    s.js("confirm.reject()")
    s.js("root.askRestartSteamVR()")
    s.shoot("confirm-restart-steamvr", settle=400)
    s.js("confirm.reject()")
    s.wait(300)
    s.js('root.notify("Copied", false)')
    s.shoot("toast", settle=400)
    s.js('root.notify("Export failed: zstd exited with status 1 while compressing 01-hand-size", true)')
    s.shoot("toast-error", settle=400)
    s.close()


def main():
    import faulthandler
    import signal
    faulthandler.register(signal.SIGUSR1, all_threads=True)   # kill -USR1: where it is
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--base", required=True, help="a scratch folder (emptied first)")
    ap.add_argument("--out", help="where the PNGs go (none: shoot without saving)")
    ap.add_argument("--no-session", action="store_true", help="skip the real dry-run session")
    a = ap.parse_args()
    problems, taken = run(a.base, a.out, live_session=not a.no_session)
    print(f"{len(taken)} shots" + (f" in {a.out}" if a.out else ""))
    if problems:
        print(f"{len(problems)} problems:", file=sys.stderr)
        for p in problems:
            print("  " + p, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
