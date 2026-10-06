#!/usr/bin/env python3
"""Draw app/icon.png: the recorder's open-hand pose picture on a dark rounded tile, with a red
record dot. Run with the venv's Python (PySide6): .venv/bin/python scripts/make-icon.py"""
import os
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
from PySide6.QtCore import QPointF, QRectF, Qt  # noqa: E402
from PySide6.QtGui import QColor, QGuiApplication, QImage, QPainter, QPen  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HAND = os.path.join(ROOT, "frametop", "hands", "rec", "poses", "open.png")
OUT = os.path.join(ROOT, "app", "icon.png")
SIZE = 256

app = QGuiApplication(sys.argv[:1])
hand = QImage(HAND)
if hand.isNull():
    sys.exit("can't read " + HAND)
img = QImage(SIZE, SIZE, QImage.Format_ARGB32_Premultiplied)
img.fill(Qt.transparent)
p = QPainter(img)
p.setRenderHint(QPainter.Antialiasing)
p.setRenderHint(QPainter.SmoothPixmapTransform)
tile = QRectF(8, 8, SIZE - 16, SIZE - 16)
p.setPen(QPen(QColor("#4cd9ff"), 6))
p.setBrush(QColor("#1b1e23"))
p.drawRoundedRect(tile, 44, 44)
# The hand, cropped to its drawing (the picture has wide margins) and centred a little low
crop = hand.copy(140, 30, 240, 450).scaled(124, 232, Qt.KeepAspectRatio, Qt.SmoothTransformation)
p.save()
p.setClipRect(tile.adjusted(6, 6, -6, -6))
p.drawImage(int((SIZE - crop.width()) / 2) - 14, 34, crop)
p.restore()
p.setPen(QPen(QColor("#1b1e23"), 8))
p.setBrush(QColor("#ff4d4d"))
p.drawEllipse(QPointF(SIZE - 58, 58), 24, 24)
p.end()
img.save(OUT)
print("wrote", OUT)
