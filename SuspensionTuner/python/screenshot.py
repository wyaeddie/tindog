"""Render the app with sample inputs to docs/*.png (used for README screenshots).

Usage: QT_QPA_PLATFORM=offscreen python3 screenshot.py
"""
import sys
from pathlib import Path

from PySide6.QtWidgets import QApplication

import app as gui

OUT = Path(__file__).resolve().parent.parent / "docs"

SCENARIOS = [
    ("screenshot-fork.png", "fork", "Fox", "fox-36-factory", "185", "lb", "71", "in", "L", "enduro"),
    ("screenshot-shock.png", "shock", "Cane Creek", "cane-creek-kitsuma-coil", "185", "lb", "71", "in", "M", "park"),
]


def main():
    qapp = QApplication(sys.argv)
    qapp.setStyleSheet(gui.STYLE)
    for fname, kind, brand, mid, w, wu, h, hu, frame, style in SCENARIOS:
        win = gui.MainWindow()
        win.resize(1280, 900)
        win.kind_seg.buttons[kind].click()
        win.brand_seg.buttons[brand].click()
        win.model_box.setCurrentIndex(win.model_box.findData(mid))
        win.weight_unit.buttons[wu].click(); win.weight.setText(w)
        win.height_unit.buttons[hu].click(); win.height.setText(h)
        win.frame_seg.buttons[frame].click()
        win.style_seg.buttons[style].click()
        win.show(); qapp.processEvents()
        win.grab().save(str(OUT / fname))
        print("wrote", OUT / fname)


if __name__ == "__main__":
    main()
