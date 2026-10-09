"""Suspension Tuner — desktop GUI (PySide6). Run: python3 app.py"""
from __future__ import annotations

import sys

from PySide6.QtCore import Qt
from PySide6.QtGui import QDoubleValidator
from PySide6.QtWidgets import (
    QApplication, QButtonGroup, QComboBox, QFrame, QGridLayout, QHBoxLayout,
    QLabel, QLineEdit, QMainWindow, QPushButton, QScrollArea, QSlider,
    QVBoxLayout, QWidget,
)

from suspension_engine import (
    FRAME_SIZES, STYLE_LABELS, STYLES, RiderInput, calculate, load_catalog,
)

ACCENT = "#FF7A1A"
STYLE = f"""
QWidget {{ background: #0D0F13; color: #E8EAED; font-family: 'Inter', 'SF Pro Text', 'Helvetica Neue', sans-serif; font-size: 13px; }}
QLabel {{ background: transparent; }}
QFrame#panel {{ background: #15181E; border: 1px solid #22262E; border-radius: 18px; }}
QFrame#card {{ background: #1A1E25; border: 1px solid #262B34; border-radius: 14px; }}
QFrame#hero {{ background: qlineargradient(x1:0,y1:0,x2:1,y2:1, stop:0 #FF7A1A, stop:1 #E0431B); border-radius: 18px; }}
QFrame#warn {{ background: #2A2112; border: 1px solid #5A4318; border-radius: 14px; }}
QLabel#section {{ color: #8A919C; font-size: 11px; font-weight: 600; letter-spacing: 1.2px; }}
QLabel#muted {{ color: #8A919C; font-size: 12px; }}
QLabel#cardLabel {{ color: #8A919C; font-size: 11px; font-weight: 600; letter-spacing: 0.8px; }}
QLabel#cardValue {{ color: #FFFFFF; font-size: 19px; font-weight: 700; }}
QPushButton {{ background: #1E222A; border: 1px solid #2A2F38; border-radius: 10px; padding: 8px 12px; color: #C9CDD3; }}
QPushButton:hover {{ border-color: #3A404B; color: #FFFFFF; }}
QPushButton:checked {{ background: {ACCENT}; border-color: {ACCENT}; color: #111; font-weight: 700; }}
QPushButton:disabled {{ color: #4A505A; border-color: #1F232A; }}
QPushButton#chip {{ border-radius: 15px; padding: 6px 12px; font-size: 12px; }}
QComboBox, QLineEdit {{ background: #1E222A; border: 1px solid #2A2F38; border-radius: 10px; padding: 9px 12px; color: #FFFFFF; }}
QComboBox:focus, QLineEdit:focus {{ border-color: {ACCENT}; }}
QComboBox:disabled, QLineEdit:disabled {{ color: #4A505A; }}
QComboBox::drop-down {{ border: none; width: 24px; }}
QComboBox QAbstractItemView {{ background: #1E222A; border: 1px solid #2A2F38; selection-background-color: {ACCENT}; selection-color: #111; }}
QSlider::groove:horizontal {{ height: 6px; background: #262B34; border-radius: 3px; }}
QSlider::sub-page:horizontal {{ background: {ACCENT}; border-radius: 3px; }}
QSlider::handle:horizontal {{ background: #FFFFFF; width: 18px; height: 18px; margin: -6px 0; border-radius: 9px; }}
QScrollArea {{ border: none; }}
"""


def discard(w: QWidget):
    """Detach and delete immediately-invisible (deleteLater alone leaves it painted until the loop runs)."""
    w.hide()
    w.setParent(None)
    w.deleteLater()


def section(text: str) -> QLabel:
    lbl = QLabel(text.upper())
    lbl.setObjectName("section")
    return lbl


class Segmented(QWidget):
    """Row of mutually exclusive toggle buttons."""

    def __init__(self, options: list[tuple[str, str]], on_change, chip=False, columns=0):
        super().__init__()
        layout = QGridLayout(self) if columns else QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(6)
        self.group = QButtonGroup(self)
        self.group.setExclusive(True)
        self.buttons: dict[str, QPushButton] = {}
        for i, (key, label) in enumerate(options):
            b = QPushButton(label)
            b.setCheckable(True)
            b.setCursor(Qt.PointingHandCursor)
            if chip:
                b.setObjectName("chip")
            self.group.addButton(b)
            self.buttons[key] = b
            if columns:
                layout.addWidget(b, i // columns, i % columns)
            else:
                layout.addWidget(b)
            b.clicked.connect(lambda _=False, k=key: on_change(k))

    def select(self, key: str):
        self.buttons[key].setChecked(True)

    def value(self) -> str | None:
        for k, b in self.buttons.items():
            if b.isChecked():
                return k
        return None


class SettingCard(QFrame):
    def __init__(self, label: str, value: str, detail: str):
        super().__init__()
        self.setObjectName("card")
        v = QVBoxLayout(self)
        v.setContentsMargins(16, 14, 16, 14)
        v.setSpacing(4)
        a = QLabel(label.upper()); a.setObjectName("cardLabel")
        b = QLabel(value); b.setObjectName("cardValue")
        c = QLabel(detail); c.setObjectName("muted"); c.setWordWrap(True)
        for w in (a, b, c):
            v.addWidget(w)
        v.addStretch()


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Suspension Tuner")
        self.catalog = load_catalog()
        self.kind = "fork"
        self.brand: str | None = None
        self.model: dict | None = None

        root = QWidget()
        self.setCentralWidget(root)
        outer = QHBoxLayout(root)
        outer.setContentsMargins(20, 20, 20, 20)
        outer.setSpacing(20)

        # ---------------- left: inputs ----------------
        left = QFrame(); left.setObjectName("panel"); left.setFixedWidth(430)
        lv = QVBoxLayout(left)
        lv.setContentsMargins(22, 22, 22, 22)
        lv.setSpacing(10)

        title = QLabel("Suspension Tuner")
        title.setStyleSheet("font-size: 24px; font-weight: 800;")
        sub = QLabel("Dial in your fork and shock in seconds."); sub.setObjectName("muted")
        lv.addWidget(title); lv.addWidget(sub); lv.addSpacing(8)

        lv.addWidget(section("1 · Component"))
        self.kind_seg = Segmented([("fork", "Fork  ·  Front"), ("shock", "Shock  ·  Rear")], self.set_kind)
        self.kind_seg.select("fork")
        lv.addWidget(self.kind_seg)

        lv.addWidget(section("2 · Brand"))
        self.brand_holder = QVBoxLayout(); self.brand_holder.setContentsMargins(0, 0, 0, 0)
        lv.addLayout(self.brand_holder)

        lv.addWidget(section("3 · Model"))
        self.model_box = QComboBox()
        self.model_box.currentIndexChanged.connect(self.set_model)
        lv.addWidget(self.model_box)

        lv.addSpacing(6)
        lv.addWidget(section("4 · Rider"))
        self.weight = QLineEdit(); self.weight.setPlaceholderText("Weight")
        self.weight.setValidator(QDoubleValidator(20, 400, 1))
        self.weight_unit = Segmented([("lb", "lb"), ("kg", "kg")], lambda _: self.recalc())
        self.weight_unit.select("lb")
        self.height = QLineEdit(); self.height.setPlaceholderText("Height")
        self.height.setValidator(QDoubleValidator(40, 250, 1))
        self.height_unit = Segmented([("in", "in"), ("cm", "cm")], lambda _: self.recalc())
        self.height_unit.select("in")
        for caption, edit, unit in (("Weight", self.weight, self.weight_unit),
                                    ("Height", self.height, self.height_unit)):
            cap = QLabel(caption); cap.setObjectName("muted"); cap.setFixedWidth(52)
            row = QHBoxLayout(); row.addWidget(cap); row.addWidget(edit, 1); row.addWidget(unit)
            unit.setFixedWidth(110)
            edit.textChanged.connect(self.recalc)
            lv.addLayout(row)

        lv.addWidget(section("Frame size"))
        self.frame_seg = Segmented([(s, s) for s in FRAME_SIZES], lambda _: self.recalc())
        self.frame_seg.select("M")
        lv.addWidget(self.frame_seg)

        lv.addWidget(section("Riding style"))
        self.style_seg = Segmented([(s, STYLE_LABELS[s]) for s in STYLES], lambda _: self.recalc())
        self.style_seg.select("trail")
        lv.addWidget(self.style_seg)

        self.travel_label = QLabel(); self.travel_label.setObjectName("section")
        self.travel = QSlider(Qt.Horizontal); self.travel.valueChanged.connect(self.recalc)
        self.stroke_label = QLabel(); self.stroke_label.setObjectName("section")
        self.stroke = QSlider(Qt.Horizontal); self.stroke.valueChanged.connect(self.recalc)
        for w in (self.travel_label, self.travel, self.stroke_label, self.stroke):
            lv.addWidget(w)
        lv.addStretch()
        outer.addWidget(left)

        # ---------------- right: results ----------------
        scroll = QScrollArea(); scroll.setWidgetResizable(True)
        self.results = QWidget()
        self.rv = QVBoxLayout(self.results)
        self.rv.setContentsMargins(4, 4, 4, 4)
        self.rv.setSpacing(14)
        scroll.setWidget(self.results)
        outer.addWidget(scroll, 1)

        self.rider_widgets = [self.weight, self.weight_unit, self.height, self.height_unit,
                              self.frame_seg, self.style_seg, self.travel, self.stroke]
        self.set_kind("fork")

    # ---------------- state ----------------
    def models_for(self, kind, brand=None):
        return [m for m in self.catalog["models"]
                if m["kind"] == kind and (brand is None or m["brand"] == brand)]

    def set_kind(self, kind: str):
        self.kind = kind
        brands = list(dict.fromkeys(m["brand"] for m in self.models_for(kind)))
        while self.brand_holder.count():
            discard(self.brand_holder.takeAt(0).widget())
        self.brand_seg = Segmented([(b, b) for b in brands], self.set_brand, chip=True, columns=3)
        self.brand_holder.addWidget(self.brand_seg)
        self.brand = None
        self.model_box.blockSignals(True)
        self.model_box.clear()
        self.model_box.addItem("Select a brand first")
        self.model_box.setEnabled(False)
        self.model_box.blockSignals(False)
        self.set_model(-1)

    def set_brand(self, brand: str):
        self.brand = brand
        self.model_box.blockSignals(True)
        self.model_box.clear()
        self.model_box.addItem("Choose a model…")
        for m in self.models_for(self.kind, brand):
            spring = "" if self.kind == "fork" else f"  ({m['spring']})"
            self.model_box.addItem(f"{m['name']}{spring}", m["id"])
        self.model_box.setEnabled(True)
        self.model_box.blockSignals(False)
        self.set_model(0)

    def set_model(self, index: int):
        mid = self.model_box.itemData(index) if index > 0 else None
        self.model = next((m for m in self.catalog["models"] if m["id"] == mid), None)
        enabled = self.model is not None
        for w in self.rider_widgets:
            w.setEnabled(enabled)
        is_shock = self.kind == "shock"
        self.stroke.setVisible(is_shock); self.stroke_label.setVisible(is_shock)
        if self.model:
            t = self.model["travel"]
            for slider, rng in ((self.travel, t), (self.stroke, self.model["stroke"])):
                if rng:
                    slider.blockSignals(True)
                    # slider works in 0.5 mm steps so 62.5 mm strokes are reachable
                    slider.setRange(int(rng["min"] * 2), int(rng["max"] * 2))
                    slider.setSingleStep(5); slider.setPageStep(10)
                    slider.setValue(int(rng["default"] * 2))
                    slider.blockSignals(False)
        self.recalc()

    def rider_input(self) -> RiderInput | None:
        try:
            weight = float(self.weight.text())
            height = float(self.height.text())
        except ValueError:
            return None
        if self.weight_unit.value() == "lb":
            weight /= 2.20462
        if self.height_unit.value() == "in":
            height *= 2.54
        if not (30 <= weight <= 180 and 120 <= height <= 230):
            return None
        return RiderInput(weight, height, self.frame_seg.value(), self.style_seg.value(),
                          self.travel.value() / 2, self.stroke.value() / 2)

    # ---------------- rendering ----------------
    def clear_results(self):
        def clear(layout):
            while layout.count():
                item = layout.takeAt(0)
                if item.widget():
                    discard(item.widget())
                elif item.layout():
                    clear(item.layout())
        clear(self.rv)

    def empty_state(self, headline: str, body: str):
        box = QFrame(); box.setObjectName("panel")
        v = QVBoxLayout(box); v.setContentsMargins(40, 60, 40, 60)
        icon = QLabel("⚙"); icon.setAlignment(Qt.AlignCenter)
        icon.setStyleSheet(f"font-size: 46px; color: {ACCENT};")
        h = QLabel(headline); h.setAlignment(Qt.AlignCenter); h.setStyleSheet("font-size: 20px; font-weight: 700;")
        b = QLabel(body); b.setAlignment(Qt.AlignCenter); b.setObjectName("muted"); b.setWordWrap(True)
        for w in (icon, h, b):
            v.addWidget(w)
        self.rv.addWidget(box)
        self.rv.addStretch()

    def recalc(self, *_):
        is_shock = self.kind == "shock"
        self.travel_label.setText(f"{'Rear wheel travel' if is_shock else 'Fork travel'}  ·  "
                                  f"{self.travel.value() / 2:g} mm".upper())
        self.stroke_label.setText(f"Shock stroke  ·  {self.stroke.value() / 2:g} mm".upper())
        self.clear_results()
        if not self.model:
            self.empty_state("Pick your suspension",
                             "Choose fork or shock, a brand, then a model to unlock rider inputs.")
            return
        rider = self.rider_input()
        if not rider:
            self.empty_state(f"{self.model['brand']} {self.model['name']}",
                             "Enter your weight and height to calculate a setup.")
            return
        rec = calculate(self.model, rider)
        m = self.model

        # header
        head = QHBoxLayout()
        hv = QVBoxLayout()
        name = QLabel(f"{m['brand']} {m['name']}"); name.setStyleSheet("font-size: 24px; font-weight: 800;")
        meta = QLabel(f"{m['kind'].title()}  ·  {m['spring'].title()} spring  ·  {m['damper']} damper  ·  "
                      f"{STYLE_LABELS[rider.style]}")
        meta.setObjectName("muted")
        hv.addWidget(name); hv.addWidget(meta)
        head.addLayout(hv, 1)
        self.rv.addLayout(head)

        # hero
        hero = QFrame(); hero.setObjectName("hero")
        hl = QHBoxLayout(hero); hl.setContentsMargins(26, 22, 26, 22)
        left = QVBoxLayout()
        cap = QLabel(rec.headline_label.upper()); cap.setStyleSheet("color: rgba(0,0,0,0.6); font-weight: 700; letter-spacing: 1.2px; font-size: 12px;")
        big = QLabel(f"{rec.headline_value}<span style='font-size:22px'> {rec.headline_unit}</span>")
        big.setStyleSheet("color: #111; font-size: 56px; font-weight: 800;")
        spring_detail = QLabel(rec.settings[0].detail)
        spring_detail.setStyleSheet("color: rgba(0,0,0,0.65); font-size: 12px;")
        left.addWidget(cap); left.addWidget(big); left.addWidget(spring_detail)
        hl.addLayout(left, 1)
        sag = next(s for s in rec.settings if s.label == "Sag")
        right = QVBoxLayout(); right.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
        sc = QLabel("TARGET SAG"); sc.setStyleSheet("color: rgba(0,0,0,0.6); font-weight: 700; letter-spacing: 1.2px; font-size: 12px;")
        sv = QLabel(sag.value.replace("  ·  ", "  /  ")); sv.setStyleSheet("color: #111; font-size: 26px; font-weight: 800;")
        sc.setAlignment(Qt.AlignRight); sv.setAlignment(Qt.AlignRight)
        sd = QLabel(sag.detail); sd.setStyleSheet("color: rgba(0,0,0,0.65); font-size: 12px;")
        sc.setAlignment(Qt.AlignRight); sd.setAlignment(Qt.AlignRight)
        right.addWidget(sc); right.addWidget(sv); right.addWidget(sd)
        hl.addLayout(right)
        self.rv.addWidget(hero)

        # cards
        grid = QGridLayout(); grid.setSpacing(12)
        for col in range(3):
            grid.setColumnStretch(col, 1)
        cards = [s for s in rec.settings[1:] if s is not sag]
        for i, s in enumerate(cards):
            grid.addWidget(SettingCard(s.label, s.value, s.detail), i // 3, i % 3)
        self.rv.addLayout(grid)

        for w_text in rec.warnings:
            warn = QFrame(); warn.setObjectName("warn")
            wl = QHBoxLayout(warn); wl.setContentsMargins(16, 12, 16, 12)
            t = QLabel(f"⚠  {w_text}"); t.setWordWrap(True); t.setStyleSheet("color: #F5C26B;")
            wl.addWidget(t)
            self.rv.addWidget(warn)

        tips = QFrame(); tips.setObjectName("card")
        tv = QVBoxLayout(tips); tv.setContentsMargins(18, 16, 18, 16); tv.setSpacing(6)
        tv.addWidget(section("Setup notes"))
        for tip in rec.tips:
            t = QLabel(f"•  {tip}"); t.setWordWrap(True); t.setStyleSheet("color: #C9CDD3;")
            tv.addWidget(t)
        disc = QLabel(self.catalog["disclaimer"]); disc.setObjectName("muted"); disc.setWordWrap(True)
        tv.addSpacing(4); tv.addWidget(disc)
        self.rv.addWidget(tips)
        self.rv.addStretch()


def main(argv=None):
    app = QApplication(argv or sys.argv)
    app.setStyleSheet(STYLE)
    win = MainWindow()
    win.resize(1280, 860)
    win.show()
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
