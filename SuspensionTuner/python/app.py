"""Suspension Tuner — desktop GUI (PySide6). Run: python3 app.py"""
from __future__ import annotations

import sys

from PySide6.QtCore import Qt
from PySide6.QtGui import QDoubleValidator, QGuiApplication, QIntValidator, QKeySequence, QPainter, QShortcut
from PySide6.QtPrintSupport import QPrintDialog, QPrinter
from PySide6.QtWidgets import (
    QApplication, QButtonGroup, QComboBox, QFileDialog, QFrame, QGridLayout, QHBoxLayout,
    QLabel, QLineEdit, QMainWindow, QMenu, QMessageBox, QPushButton, QScrollArea, QSlider,
    QVBoxLayout, QWidget,
)

from suspension_engine import (
    FRAME_SIZES, STYLE_LABELS, STYLES, RiderInput, calculate, load_catalog,
)

# Inputs keep the orange accent; the output side is green.
ACCENT = "#FF7A1A"
PINK = "#F472B6"
VIOLET = "#A78BFA"
SKY = "#38BDF8"
AMBER = "#FBBF24"
GREEN = "#22C55E"
GREEN_BRIGHT = "#16A34A"
GREEN_DEEP = "#065F46"

# Brand colour + monogram (stand-in for logos, which are trademarked artwork).
BRANDS = {
    "Fox": ("FOX", "#E8541E", "#FFFFFF"),
    "RockShox": ("RS", "#D71920", "#FFFFFF"),
    "Öhlins": ("Ö", "#FFD100", "#111111"),
    "Marzocchi": ("MZ", "#C8102E", "#FFFFFF"),
    "Cane Creek": ("CC", "#0072CE", "#FFFFFF"),
    "DVO": ("DVO", "#78BE20", "#111111"),
    "Formula": ("F", "#F2F2F2", "#111111"),
    "Manitou": ("M", "#1D4ED8", "#FFFFFF"),
    "EXT": ("EXT", "#4B5563", "#FFFFFF"),
    "PUSH Industries": ("PUSH", "#9333EA", "#FFFFFF"),
    "SR Suntour": ("SR", "#0EA5E9", "#FFFFFF"),
    "X-Fusion": ("XF", "#14B8A6", "#FFFFFF"),
}


def card_color(label: str) -> str:
    l = label.lower()
    if "rebound" in l:
        return SKY
    if "compression" in l:
        return VIOLET
    if "spacer" in l or "progression" in l:
        return AMBER
    if "lockout" in l:
        return PINK
    return GREEN


STYLE = f"""
QWidget {{ background: #0D0F13; color: #E8EAED; font-family: 'Inter', 'SF Pro Text', 'Helvetica Neue', sans-serif; font-size: 13px; }}
QLabel {{ background: transparent; }}
QFrame#panel {{ background: #15181E; border: 1px solid #22262E; border-radius: 18px; }}
QFrame#card {{ background: #1A1E25; border: 1px solid #262B34; border-radius: 14px; }}
QFrame#hero {{ background: qlineargradient(x1:0,y1:0,x2:1,y2:1, stop:0 {GREEN_BRIGHT}, stop:1 {GREEN_DEEP}); border-radius: 18px; }}
QFrame#warn {{ background: #2A2112; border: 1px solid #5A4318; border-radius: 14px; }}
QLabel#muted {{ color: #8A919C; font-size: 12px; }}
QLabel#cardValue {{ color: #FFFFFF; font-size: 19px; font-weight: 700; }}
QPushButton {{ background: #1E222A; border: 1px solid #2A2F38; border-radius: 10px; padding: 8px 12px; color: #D5D9DF; }}
QPushButton:hover {{ border-color: #3A404B; color: #FFFFFF; }}
QPushButton:checked {{ background: {ACCENT}; border-color: {ACCENT}; color: #111; font-weight: 700; }}
QPushButton:disabled {{ color: #4A505A; border-color: #1F232A; }}
QPushButton#chip {{ padding: 6px 10px; font-size: 12px; text-align: left; }}
QPushButton#reset {{ background: rgba(255,122,26,0.12); border: 1px solid rgba(255,122,26,0.5); border-radius: 14px; color: {ACCENT}; font-weight: 700; padding: 6px 14px; }}
QPushButton#action {{ background: rgba(34,197,94,0.14); border: 1px solid rgba(34,197,94,0.55); color: {GREEN}; font-weight: 700; padding: 8px 14px; }}
QPushButton#action::menu-indicator {{ image: none; width: 0; }}
QComboBox, QLineEdit {{ background: #1E222A; border: 1px solid #2A2F38; border-radius: 10px; padding: 9px 12px; color: #FFFFFF; }}
QComboBox:focus, QLineEdit:focus {{ border-color: {ACCENT}; }}
QComboBox:disabled, QLineEdit:disabled {{ color: #4A505A; }}
QComboBox::drop-down {{ border: none; width: 24px; }}
QComboBox QAbstractItemView, QMenu {{ background: #1E222A; border: 1px solid #2A2F38; selection-background-color: {GREEN}; selection-color: #111; }}
QMenu::item {{ padding: 6px 18px; }}
QSlider::groove:horizontal {{ height: 6px; background: #262B34; border-radius: 3px; }}
QSlider::sub-page:horizontal {{ background: {ACCENT}; border-radius: 3px; }}
QSlider::handle:horizontal {{ background: #FFFFFF; width: 18px; height: 18px; margin: -6px 0; border-radius: 9px; }}
QScrollArea {{ border: none; }}
"""


def discard(w: QWidget):
    """Detach and delete immediately (deleteLater alone leaves it painted until the loop runs)."""
    w.hide()
    w.setParent(None)
    w.deleteLater()


def section(text: str, color: str = "#8A919C") -> QLabel:
    lbl = QLabel(text.upper())
    lbl.setStyleSheet(f"color: {color}; font-size: 11px; font-weight: 700; letter-spacing: 1.2px;")
    return lbl


def brand_badge(brand: str, size: int = 52) -> QLabel:
    mono, bg, fg = BRANDS.get(brand, (brand[:2].upper(), "#8A919C", "#FFFFFF"))
    b = QLabel(mono)
    b.setAlignment(Qt.AlignCenter)
    b.setFixedSize(size, size)
    font_px = int(size * (0.26 if len(mono) > 2 else 0.38))
    b.setStyleSheet(f"background: {bg}; color: {fg}; border-radius: {int(size * 0.26)}px; "
                    f"font-size: {font_px}px; font-weight: 900;")
    return b


def chip(text: str, color: str) -> QLabel:
    c = QLabel(text)
    c.setStyleSheet(f"color: {color}; background: rgba({int(color[1:3], 16)},{int(color[3:5], 16)},"
                    f"{int(color[5:7], 16)},0.14); border-radius: 9px; padding: 2px 8px; "
                    "font-size: 11px; font-weight: 600;")
    return c


class Segmented(QWidget):
    """Row of mutually exclusive toggle buttons."""

    def __init__(self, options: list[tuple[str, str]], on_change, chip=False, columns=0, dots=None):
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
            if dots:
                # brand colour as a stripe on the chip's left edge
                b.setStyleSheet(f"QPushButton:!checked {{ border-left: 4px solid {dots[key]}; }}")
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
        color = card_color(label)
        r, g, b_ = int(color[1:3], 16), int(color[3:5], 16), int(color[5:7], 16)
        self.setStyleSheet(
            f"SettingCard {{ background: qlineargradient(x1:0,y1:0,x2:1,y2:1, stop:0 rgba({r},{g},{b_},0.13), "
            f"stop:0.6 #1A1E25); border: 1px solid rgba({r},{g},{b_},0.4); border-radius: 14px; }}")
        v = QVBoxLayout(self)
        v.setContentsMargins(16, 14, 16, 14)
        v.setSpacing(4)
        a = QLabel(f"●  {label.upper()}")
        a.setStyleSheet(f"color: {color}; font-size: 11px; font-weight: 700; letter-spacing: 0.8px;")
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
        self.last: tuple | None = None  # (model, rider, recommendation) for share/print

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

        header = QHBoxLayout()
        titles = QVBoxLayout(); titles.setSpacing(2)
        title = QLabel(f"<span style='color:{ACCENT}'>Suspension</span> <span style='color:{PINK}'>Tuner</span>")
        title.setStyleSheet("font-size: 24px; font-weight: 800;")
        sub = QLabel("Dial in your fork and shock in seconds."); sub.setObjectName("muted")
        titles.addWidget(title); titles.addWidget(sub)
        header.addLayout(titles, 1)
        reset = QPushButton("↺  Reset"); reset.setObjectName("reset"); reset.setCursor(Qt.PointingHandCursor)
        reset.setToolTip("Clear all selections and inputs (Ctrl+R)")
        reset.clicked.connect(self.reset)
        QShortcut(QKeySequence("Ctrl+R"), self, activated=self.reset)
        header.addWidget(reset, 0, Qt.AlignTop)
        lv.addLayout(header); lv.addSpacing(8)

        lv.addWidget(section("1 · Component", ACCENT))
        self.kind_seg = Segmented([("fork", "Fork  ·  Front"), ("shock", "Shock  ·  Rear")], self.set_kind)
        lv.addWidget(self.kind_seg)

        lv.addWidget(section("2 · Brand", PINK))
        self.brand_holder = QVBoxLayout(); self.brand_holder.setContentsMargins(0, 0, 0, 0)
        lv.addLayout(self.brand_holder)

        lv.addWidget(section("3 · Model", VIOLET))
        self.model_box = QComboBox()
        self.model_box.currentIndexChanged.connect(self.set_model)
        lv.addWidget(self.model_box)

        lv.addSpacing(6)
        lv.addWidget(section("4 · Rider", SKY))

        def caption(text):
            c = QLabel(text); c.setFixedWidth(52)
            c.setStyleSheet(f"color: {SKY}; font-size: 12px; font-weight: 600;")
            return c

        def unit(text):
            u = QLabel(text); u.setStyleSheet(f"color: {SKY}; font-weight: 700;")
            return u

        self.weight = QLineEdit(); self.weight.setPlaceholderText("Weight")
        self.weight.setValidator(QDoubleValidator(20, 400, 1))
        self.weight_unit = Segmented([("lb", "lb"), ("kg", "kg")], lambda _: self.recalc())
        self.weight_unit.setFixedWidth(110)
        row = QHBoxLayout(); row.addWidget(caption("Weight")); row.addWidget(self.weight, 1); row.addWidget(self.weight_unit)
        lv.addLayout(row)

        self.height_ft = QLineEdit(); self.height_ft.setPlaceholderText("5")
        self.height_ft.setValidator(QIntValidator(3, 7))
        self.height_in = QLineEdit(); self.height_in.setPlaceholderText("10")
        self.height_in.setValidator(QDoubleValidator(0, 11.9, 1))
        row = QHBoxLayout(); row.addWidget(caption("Height"))
        row.addWidget(self.height_ft, 1); row.addWidget(unit("ft"))
        row.addWidget(self.height_in, 1); row.addWidget(unit("in"))
        lv.addLayout(row)
        for edit in (self.weight, self.height_ft, self.height_in):
            edit.textChanged.connect(self.recalc)

        lv.addWidget(section("Frame size", AMBER))
        self.frame_seg = Segmented([(s, s) for s in FRAME_SIZES], lambda _: self.recalc())
        lv.addWidget(self.frame_seg)

        lv.addWidget(section("Riding style", GREEN))
        self.style_seg = Segmented([(s, STYLE_LABELS[s]) for s in STYLES], lambda _: self.recalc())
        lv.addWidget(self.style_seg)

        self.travel_label = QLabel()
        self.travel = QSlider(Qt.Horizontal); self.travel.valueChanged.connect(self.recalc)
        self.stroke_label = QLabel()
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

        self.rider_widgets = [self.weight, self.weight_unit, self.height_ft, self.height_in,
                              self.frame_seg, self.style_seg, self.travel, self.stroke]
        QShortcut(QKeySequence.Print, self, activated=self.print_report)
        self.reset()

    # ---------------- state ----------------
    def models_for(self, kind, brand=None):
        return [m for m in self.catalog["models"]
                if m["kind"] == kind and (brand is None or m["brand"] == brand)]

    def reset(self):
        for edit in (self.weight, self.height_ft, self.height_in):
            edit.blockSignals(True); edit.clear(); edit.blockSignals(False)
        self.weight_unit.select("lb")
        self.frame_seg.select("M")
        self.style_seg.select("trail")
        self.kind_seg.select("fork")
        self.set_kind("fork")

    def set_kind(self, kind: str):
        self.kind = kind
        brands = list(dict.fromkeys(m["brand"] for m in self.models_for(kind)))
        while self.brand_holder.count():
            discard(self.brand_holder.takeAt(0).widget())
        self.brand_seg = Segmented([(b, b) for b in brands], self.set_brand, chip=True, columns=3,
                                   dots={b: BRANDS.get(b, ("", "#8A919C", ""))[1] for b in brands})
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

    def height_inches(self) -> float | None:
        try:
            ft = float(self.height_ft.text())
            inches = float(self.height_in.text()) if self.height_in.text() else 0.0
        except ValueError:
            return None
        return ft * 12 + inches if 0 <= inches < 12 else None

    def rider_input(self) -> RiderInput | None:
        try:
            weight = float(self.weight.text())
        except ValueError:
            return None
        total_in = self.height_inches()
        if total_in is None:
            return None
        if self.weight_unit.value() == "lb":
            weight /= 2.20462
        height = total_in * 2.54
        if not (30 <= weight <= 180 and 120 <= height <= 230):
            return None
        return RiderInput(weight, height, self.frame_seg.value(), self.style_seg.value(),
                          self.travel.value() / 2, self.stroke.value() / 2)

    def rider_summary(self) -> str:
        inches = self.height_in.text() or "0"
        return (f"{self.weight.text()} {self.weight_unit.value()} · {self.height_ft.text()}′{inches}″ · "
                f"Frame {self.frame_seg.value()} · {STYLE_LABELS[self.style_seg.value()]}")

    def summary_text(self) -> str:
        m, _, rec = self.last
        lines = [f"Suspension Tuner — {m['brand']} {m['name']} ({m['kind']})", f"Rider: {self.rider_summary()}", ""]
        lines += [f"{s.label}: {s.value}" for s in rec.settings]
        if rec.warnings:
            lines += [""] + [f"⚠️ {w}" for w in rec.warnings]
        lines += [""] + [f"• {t}" for t in rec.tips] + ["", self.catalog["disclaimer"]]
        return "\n".join(lines)

    # ---------------- share / print ----------------
    def copy_summary(self):
        QGuiApplication.clipboard().setText(self.summary_text())
        QMessageBox.information(self, "Copied", "Setup copied to the clipboard — paste it into Messages, Mail or Notes.")

    def save_image(self):
        m = self.last[0]
        default = f"{m['brand']} {m['name']} setup.png".replace("/", "-")
        path, _ = QFileDialog.getSaveFileName(self, "Save setup as image", default, "PNG image (*.png)")
        if path:
            self.results.grab().save(path)

    def save_pdf(self):
        m = self.last[0]
        default = f"{m['brand']} {m['name']} setup.pdf".replace("/", "-")
        path, _ = QFileDialog.getSaveFileName(self, "Save setup as PDF", default, "PDF (*.pdf)")
        if path:
            printer = QPrinter(QPrinter.HighResolution)
            printer.setOutputFormat(QPrinter.PdfFormat)
            printer.setOutputFileName(path)
            self.paint_to(printer)

    def print_report(self):
        if not self.last:
            return
        printer = QPrinter(QPrinter.HighResolution)
        if QPrintDialog(printer, self).exec():
            self.paint_to(printer)

    def paint_to(self, printer: QPrinter):
        pix = self.results.grab()
        painter = QPainter(printer)
        page = printer.pageLayout().paintRectPixels(printer.resolution())
        scaled = pix.scaled(page.size(), Qt.KeepAspectRatio, Qt.SmoothTransformation)
        painter.drawPixmap(0, 0, scaled)
        painter.end()

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

    def empty_state(self, headline: str, body: str, brand: str | None = None):
        box = QFrame(); box.setObjectName("panel")
        v = QVBoxLayout(box); v.setContentsMargins(40, 60, 40, 60); v.setSpacing(10)
        if brand:
            icon = brand_badge(brand, 64)
        else:
            icon = QLabel("⚙"); icon.setStyleSheet(f"font-size: 46px; color: {GREEN};")
        h = QLabel(headline); h.setAlignment(Qt.AlignCenter); h.setStyleSheet("font-size: 20px; font-weight: 700;")
        b = QLabel(body); b.setAlignment(Qt.AlignCenter); b.setObjectName("muted"); b.setWordWrap(True)
        v.addWidget(icon, 0, Qt.AlignHCenter)
        v.addWidget(h); v.addWidget(b)
        self.rv.addWidget(box)
        self.rv.addStretch()

    def recalc(self, *_):
        is_shock = self.kind == "shock"
        mm = f"<span style='color:{ACCENT}'>{self.travel.value() / 2:g} MM</span>"
        self.travel_label.setText(f"{'REAR WHEEL TRAVEL' if is_shock else 'FORK TRAVEL'}  ·  {mm}")
        self.stroke_label.setText(f"SHOCK STROKE  ·  <span style='color:{ACCENT}'>{self.stroke.value() / 2:g} MM</span>")
        for lbl in (self.travel_label, self.stroke_label):
            lbl.setStyleSheet("color: #8A919C; font-size: 11px; font-weight: 700; letter-spacing: 1.2px;")
        self.clear_results()
        self.last = None
        if not self.model:
            self.empty_state("Pick your suspension",
                             "Choose fork or shock, a brand, then a model to unlock rider inputs.")
            return
        rider = self.rider_input()
        if not rider:
            self.empty_state(f"{self.model['brand']} {self.model['name']}",
                             "Enter your weight and height (ft + in) to calculate a setup.",
                             brand=self.model["brand"])
            return
        rec = calculate(self.model, rider)
        m = self.model
        self.last = (m, rider, rec)

        # header: badge · name · chips · share/print
        head = QHBoxLayout(); head.setSpacing(14)
        head.addWidget(brand_badge(m["brand"]))
        hv = QVBoxLayout(); hv.setSpacing(6)
        brand_color = BRANDS.get(m["brand"], ("", GREEN, ""))[1]
        name = QLabel(f"<span style='color:{brand_color}'>{m['brand']}</span> {m['name']}")
        name.setStyleSheet("font-size: 24px; font-weight: 800;")
        chips = QHBoxLayout(); chips.setSpacing(6)
        for text, color in ((m["kind"].title(), SKY), (f"{m['spring'].title()} spring", AMBER),
                            (m["damper"], VIOLET), (STYLE_LABELS[rider.style], GREEN)):
            chips.addWidget(chip(text, color))
        chips.addStretch()
        hv.addWidget(name); hv.addLayout(chips)
        head.addLayout(hv, 1)

        share = QPushButton("⇪  Share"); share.setObjectName("action"); share.setCursor(Qt.PointingHandCursor)
        menu = QMenu(share)
        menu.addAction("Copy setup as text", self.copy_summary)
        menu.addAction("Save as image (PNG)…", self.save_image)
        menu.addAction("Save as PDF…", self.save_pdf)
        share.setMenu(menu)
        prt = QPushButton("⎙  Print"); prt.setObjectName("action"); prt.setCursor(Qt.PointingHandCursor)
        prt.setToolTip("Print this setup (Ctrl+P)")
        prt.clicked.connect(self.print_report)
        head.addWidget(share, 0, Qt.AlignVCenter); head.addWidget(prt, 0, Qt.AlignVCenter)
        self.rv.addLayout(head)

        # hero
        hero = QFrame(); hero.setObjectName("hero")
        hl = QHBoxLayout(hero); hl.setContentsMargins(26, 22, 26, 22)
        cap_css = "color: rgba(255,255,255,0.75); font-weight: 700; letter-spacing: 1.2px; font-size: 12px;"
        det_css = "color: rgba(255,255,255,0.85); font-size: 12px;"
        left = QVBoxLayout()
        cap = QLabel(rec.headline_label.upper()); cap.setStyleSheet(cap_css)
        big = QLabel(f"{rec.headline_value}<span style='font-size:22px'> {rec.headline_unit}</span>")
        big.setStyleSheet("color: #FFFFFF; font-size: 56px; font-weight: 800;")
        spring_detail = QLabel(rec.settings[0].detail); spring_detail.setStyleSheet(det_css)
        left.addWidget(cap); left.addWidget(big); left.addWidget(spring_detail)
        hl.addLayout(left, 1)
        sag = next(s for s in rec.settings if s.label == "Sag")
        right = QVBoxLayout(); right.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
        sc = QLabel("TARGET SAG"); sc.setStyleSheet(cap_css)
        sv = QLabel(sag.value.replace("  ·  ", "  /  ")); sv.setStyleSheet("color: #FFFFFF; font-size: 26px; font-weight: 800;")
        sd = QLabel(sag.detail); sd.setStyleSheet(det_css)
        for w in (sc, sv, sd):
            w.setAlignment(Qt.AlignRight)
            right.addWidget(w)
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
        tv.addWidget(section("Setup notes", GREEN))
        for tip in rec.tips:
            t = QLabel(f"<span style='color:{GREEN}'>✔</span>&nbsp;&nbsp;{tip}")
            t.setWordWrap(True); t.setStyleSheet("color: #D5D9DF;")
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
