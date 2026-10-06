#!/usr/bin/env python3
"""The dashboard spike (standalone-recorder plan, step 1): a small PySide6 window to open from
SteamVR's "Launch a program" and see what works there before the recorder relies on it:
  1. Does it show as a dashboard panel, take pointer clicks, scroll, and take text from the
     SteamVR keyboard? Does opening a link bring up a browser that's usable in the headset? Does
     copy and paste work?
  2. With the dashboard closed, does ft-handpanel (built for the host by scripts/build.sh) show
     over the SteamVR home? Does the headset button reach this process, and what does Steam do
     with it?
  3. Does the sleep block (systemd-inhibit, as the recorder's export and upload use) hold?
Everything it sees goes to ~/.local/state/frametop-hand-recorder/spike.log, one JSON object a
line, so the results can be read afterwards. Run it with spike/run.sh (spike/install.sh adds
the menu entry).
"""
import json
import os
import socket
import subprocess
import sys
import time

from PySide6.QtCore import Property, QObject, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QDesktopServices, QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "frametop", "hands", "rec"))
import session  # noqa: E402  (the headset button reader)

LOG = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
                   "frametop-hand-recorder", "spike.log")
PANEL = os.path.join(ROOT, "build", "hands", "rec", "build", "ft-handpanel")
PANEL_SOCKET = "ft_handrec_spike"     # not the recorder's, so a real session isn't disturbed
AWAKE_UNIT = "frametop-handrec-spike-awake.service"
LINK = "https://huggingface.co/login"


def log(event, **data):
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    with open(LOG, "a") as f:
        f.write(json.dumps({"t": time.strftime("%H:%M:%S"), "event": event, **data}) + "\n")


class Spike(QObject):
    pressesChanged = Signal()
    stateChanged = Signal()
    _gesture = Signal(str)

    def __init__(self):
        super().__init__()
        self._gestures = {"press": 0, "double": 0, "hold": 0}   # session.ButtonGestures
        self._last = ""
        self._panel = None
        self._awake = False
        self._gesture.connect(self._on_gesture)
        self._button = None
        path = session.find_button(session.read_input_devices())
        log("button-device", path=path)
        if path:
            self._button = session.ButtonReader(path, self._gesture.emit, log=lambda s: log("button", text=s)).start()

    def _on_gesture(self, gesture):
        self._gestures[gesture] += 1
        self._last = gesture
        log("headset-button", gesture=gesture, counts=self._gestures)
        self.pressesChanged.emit()

    @Property(str, notify=pressesChanged)
    def presses(self):
        g = self._gestures
        return "%d presses, %d double presses, %d holds%s" % (
            g["press"], g["double"], g["hold"], " (last: %s)" % self._last if self._last else "")

    @Property(str, constant=True)
    def info(self):
        app = QGuiApplication.instance()
        screen = app.primaryScreen()
        g = screen.geometry() if screen else None
        keys = ("QT_QPA_PLATFORM", "DISPLAY", "WAYLAND_DISPLAY", "XDG_CURRENT_DESKTOP", "XDG_SESSION_TYPE",
                "GAMESCOPE_WAYLAND_DISPLAY", "STEAM_GAMESCOPE_VIRTUAL_WHITE", "SteamGameId")
        lines = ["Qt platform: " + app.platformName(),
                 "Screen: %s" % ("%dx%d" % (g.width(), g.height()) if g else "none")
                 + (", scale %.2f" % screen.devicePixelRatio() if screen else "")]
        lines += ["%s=%s" % (k, os.environ[k]) for k in keys if k in os.environ]
        return "\n".join(lines)

    @Slot(str, str)
    def note(self, event, detail):
        log(event, detail=detail)

    @Slot(result=bool)
    def openLink(self):
        ok = QDesktopServices.openUrl(QUrl(LINK))
        log("open-link", url=LINK, ok=ok)
        return ok

    @Slot(str)
    def copy(self, text):
        QGuiApplication.clipboard().setText(text)
        log("copy", text=text)

    @Slot(result=str)
    def paste(self):
        text = QGuiApplication.clipboard().text()
        log("paste", text=text)
        return text

    def _panel_cmd(self, cmd):
        s = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        try:
            s.bind("\0ft_handrec_spike_client")
            s.settimeout(1.0)
            s.sendto(cmd.encode(), "\0" + PANEL_SOCKET)
            return s.recv(4096).decode(errors="replace")
        except OSError as e:
            return "error " + str(e)
        finally:
            s.close()

    @Property(bool, notify=stateChanged)
    def panelOn(self):
        return self._panel is not None and self._panel.poll() is None

    @Slot(result=str)
    def togglePanel(self):
        if self.panelOn:
            self._panel.stdin.close()
            self._panel.wait(5)
            self._panel = None
            log("panel", state="stopped")
            self.stateChanged.emit()
            return "Panel stopped"
        if not os.access(PANEL, os.X_OK):
            log("panel", state="missing", path=PANEL)
            return "No panel binary: run scripts/build-in-container.sh first"
        logf = open(LOG + ".panel", "a")
        self._panel = subprocess.Popen([PANEL, "--watch-stdin", "--socket", PANEL_SOCKET], stdin=subprocess.PIPE,
                                       stdout=logf, stderr=logf)
        reply = ""
        for _ in range(50):
            reply = self._panel_cmd("ping")
            if reply.startswith("ok"):
                break
            if self._panel.poll() is not None:
                log("panel", state="exited", code=self._panel.returncode)
                self._panel = None
                self.stateChanged.emit()
                return "The panel exited (see spike.log.panel)"
            time.sleep(0.1)
        for cmd in ("title Dashboard spike", "step Panel test",
                    "text Can you see this panel with the dashboard closed?|Press the headset button once, twice "
                    "quickly, and hold it for 2 s: the window counts each.",
                    "hands seen lost", "show"):
            reply = self._panel_cmd(cmd)
        log("panel", state="shown", reply=reply)
        self.stateChanged.emit()
        return "Panel shown: close the dashboard and look"

    @Property(bool, notify=stateChanged)
    def awake(self):
        return self._awake

    @Slot(result=str)
    def toggleAwake(self):
        if self._awake:
            r = subprocess.run(["systemctl", "--user", "stop", AWAKE_UNIT], capture_output=True, text=True)
            self._awake = False
            log("awake", state="stopped", code=r.returncode)
            self.stateChanged.emit()
            return "Sleep allowed again"
        r = subprocess.run(["systemd-run", "--user", "--quiet", "--collect", "--unit=" + AWAKE_UNIT,
                            "systemd-inhibit", "--what=sleep:idle", "--mode=block", "--who=Hand Recorder spike",
                            "--why=Testing the sleep block", "sleep", "900"], capture_output=True, text=True)
        self._awake = r.returncode == 0
        log("awake", state="started" if self._awake else "failed", code=r.returncode, err=r.stderr.strip())
        self.stateChanged.emit()
        return ("Sleep blocked for 15 min: take the headset off, wait, and see if it sleeps" if self._awake
                else "Couldn't block sleep: " + r.stderr.strip())

    def shutdown(self):
        if self.panelOn:
            self._panel.stdin.close()
            self._panel.wait(5)
        if self._awake:
            subprocess.run(["systemctl", "--user", "stop", AWAKE_UNIT], capture_output=True)
        if self._button:
            self._button.stop()
        log("quit")


def main():
    app = QGuiApplication(sys.argv)
    app.setApplicationName("ft-handrec-spike")
    from PySide6.QtQuickControls2 import QQuickStyle
    QQuickStyle.setStyle("Basic")
    spike = Spike()
    app.aboutToQuit.connect(spike.shutdown)
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("spike", spike)
    engine.load(QUrl.fromLocalFile(os.path.join(os.path.dirname(os.path.abspath(__file__)), "spike.qml")))
    if not engine.rootObjects():
        log("start", ok=False)
        sys.exit(1)
    log("start", ok=True, info=spike.info)
    tick = QTimer(interval=500, timeout=lambda: None)   # let Python see signals
    tick.start()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
