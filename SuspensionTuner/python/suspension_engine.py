"""Suspension setup calculator.

The math here is mirrored 1:1 in apple/Sources/SuspensionKit/Engine.swift.
If you change a constant or formula, change it in both places (the parity
tests in each language pin the same expected numbers).

All outputs are *starting points*: always confirm against the manufacturer's
setup chart and never exceed the max pressure printed on the product.
"""
from __future__ import annotations

import json
import math
import urllib.parse
from dataclasses import dataclass, field
from pathlib import Path

CATALOG_PATH = (Path(__file__).resolve().parent.parent
                / "apple" / "Sources" / "SuspensionKit" / "Resources" / "catalog.json")

LB_PER_KG = 2.20462
GEAR_KG = 5.0  # helmet, pack, water, shoes

FRAME_SIZES = ["S", "M", "L", "XL"]
STYLES = ["trail", "enduro", "park"]
STYLE_LABELS = {"trail": "Trail", "enduro": "Enduro", "park": "Bike Park"}

FORK_SAG = {"trail": 20, "enduro": 22, "park": 23}
SHOCK_SAG = {"trail": 28, "enduro": 30, "park": 31}
LSC_FRACTION = {"trail": 0.30, "enduro": 0.40, "park": 0.50}
HSC_FRACTION = {"trail": 0.25, "enduro": 0.40, "park": 0.55}
CATEGORY_RANK = {"xc": 0, "trail": 1, "enduro": 2, "dh": 3}


def load_catalog(path: Path = CATALOG_PATH) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def specs_url(catalog: dict, model: dict) -> str:
    """Official product page when we have a verified one, else a search of the brand's own site."""
    if model.get("url"):
        return model["url"]
    domain = catalog["brandSites"][model["brand"]]
    query = f"site:{domain} {model['name']} specs"
    return "https://www.google.com/search?q=" + urllib.parse.quote_plus(query)


@dataclass
class RiderInput:
    weight_kg: float
    height_cm: float
    frame_size: str          # S / M / L / XL
    style: str               # trail / enduro / park
    travel_mm: float         # fork travel, or rear-wheel travel for a shock
    stroke_mm: float = 0.0   # shock stroke (shocks only)


@dataclass
class Setting:
    label: str
    value: str
    detail: str = ""


@dataclass
class Recommendation:
    headline_label: str
    headline_value: str
    headline_unit: str
    settings: list[Setting] = field(default_factory=list)
    tips: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


def recommended_frame_size(height_cm: float) -> str:
    if height_cm < 163:
        return "S"
    if height_cm < 175:
        return "M"
    if height_cm < 186:
        return "L"
    return "XL"


def _clamp(v: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, v))


def _round_half_up(v: float) -> int:
    # Python's round() is banker's rounding; Swift's .rounded() is half-away-from-zero.
    return int(math.floor(v + 0.5))


def _weight_index(system_lb: float) -> float:
    """0 for a light rider (120 lb incl. gear) to 1 for a heavy one (260 lb)."""
    return _clamp((system_lb - 120) / 140, 0, 1)


def calculate(model: dict, rider: RiderInput) -> Recommendation:
    is_fork = model["kind"] == "fork"
    style = rider.style
    system_lb = (rider.weight_kg + GEAR_KG) * LB_PER_KG
    w = _weight_index(system_lb)

    # Weight distribution: bigger frames and riders "large" for their frame
    # push more weight onto the front wheel.
    rec_size = recommended_frame_size(rider.height_cm)
    frame_idx = FRAME_SIZES.index(rider.frame_size)
    fit_delta = FRAME_SIZES.index(rec_size) - frame_idx
    front_bias = _clamp(0.40 + 0.01 * (frame_idx - 1) + 0.01 * fit_delta, 0.36, 0.46)
    rear_bias = 1 - front_bias

    sag_pct = FORK_SAG[style] if is_fork else SHOCK_SAG[style]
    if model["category"] == "xc":
        sag_pct -= 3 if is_fork else 2

    warnings: list[str] = []
    tips: list[str] = []
    settings: list[Setting] = []

    # ---- spring -----------------------------------------------------------
    if is_fork:
        sag_mm = rider.travel_mm * sag_pct / 100
        base_sag = 20
        psi = model["psiRatio"] * system_lb * (front_bias / 0.40) * math.sqrt(base_sag / sag_pct)
    else:
        stroke = rider.stroke_mm
        sag_mm = stroke * sag_pct / 100
        leverage = rider.travel_mm / stroke
        if model["spring"] == "air":
            psi = (model["psiRatio"] * system_lb * (rear_bias / 0.60)
                   * math.sqrt(28 / sag_pct) * (leverage / 2.7))
        else:
            rear_static = rear_bias + 0.10
            stroke_in = stroke / 25.4
            rate = system_lb * rear_static * leverage / (sag_pct / 100 * stroke_in)
            rate = 25 * _round_half_up(rate / 25)

    if model["spring"] == "air":
        psi_i = _round_half_up(psi)
        if psi_i > model["maxPsi"]:
            warnings.append(f"Calculated {psi_i} psi exceeds the {model['maxPsi']} psi max — "
                            "capped. Consider a firmer spring or more tokens.")
            psi_i = model["maxPsi"]
        headline = ("Air pressure", str(psi_i), "psi")
        settings.append(Setting("Air pressure", f"{psi_i} psi",
                                f"Max {model['maxPsi']} psi. Adjust ±5 psi per ~2% sag change."))
    else:
        headline = ("Spring rate", str(rate), "lb/in")
        settings.append(Setting("Coil spring", f"{rate} lb/in",
                                f"Leverage ratio {leverage:.2f}:1. Max 1–2 turns of preload."))

    settings.append(Setting("Sag", f"{sag_pct}%  ·  {sag_mm:.1f} mm",
                            "Measured on the stanchion" if is_fork
                            else "Measured on the shock shaft, seated in attack position"))

    # ---- progression ------------------------------------------------------
    if model["tokens"]:
        t = model["tokens"]["default"] + {"trail": 0, "enduro": 1, "park": 2}[style]
        if system_lb > 210:
            t += 1
        elif system_lb < 140:
            t -= 1
        t = int(_clamp(t, 0, model["tokens"]["max"]))
        settings.append(Setting("Volume spacers", f"{t} token{'s' if t != 1 else ''}",
                                f"Max {model['tokens']['max']}. Add one if you bottom out harshly."))
    elif model["spring"] == "air":
        settings.append(Setting("Progression", "See brand chart",
                                "Uses a ramp-up chamber / inserts instead of tokens."))

    # ---- damping ----------------------------------------------------------
    adj = model["adjusters"]

    def from_closed(n: int, base: float) -> int:
        return int(_clamp(_round_half_up(n * (base - 0.35 * w)), 1, max(1, n - 1)))

    def from_open(n: int, frac: float) -> int:
        return int(_clamp(_round_half_up(n * _clamp(frac + 0.1 * w, 0, 1)), 0, n))

    if adj["rebound"]:
        n = adj["rebound"]
        settings.append(Setting("Rebound", f"{from_closed(n, 0.65)} clicks out",
                                f"From fully closed (slowest), of {n}"))
    if adj["lsr"]:
        n = adj["lsr"]
        settings.append(Setting("Low-speed rebound", f"{from_closed(n, 0.65)} clicks out",
                                f"From fully closed, of {n}"))
    if adj["hsr"]:
        n = adj["hsr"]
        settings.append(Setting("High-speed rebound", f"{from_closed(n, 0.55)} clicks out",
                                f"From fully closed, of {n}"))
    if adj["lsc"]:
        n = adj["lsc"]
        settings.append(Setting("Low-speed compression", f"{from_open(n, LSC_FRACTION[style])} clicks in",
                                f"From fully open, of {n}. Controls brake dive and pedal bob."))
    if adj["hsc"]:
        n = adj["hsc"]
        settings.append(Setting("High-speed compression", f"{from_open(n, HSC_FRACTION[style])} clicks in",
                                f"From fully open, of {n}. Controls big hits and square edges."))

    # ---- lockout / climb --------------------------------------------------
    if model["climb"]:
        how = ("Leave open for lift laps; use only on long fire-road climbs."
               if style == "park" else "Open on descents, firm for long climbs and pavement.")
        settings.append(Setting("Lockout / climb", model["climb"], how))
    else:
        settings.append(Setting("Lockout / climb", "None",
                                "Use more low-speed compression for climbing support."))

    # ---- fit & warnings -----------------------------------------------------
    if fit_delta != 0:
        total_in = _round_half_up(rider.height_cm / 2.54)
        warnings.append(f"At {total_in // 12}′{total_in % 12}″ ({rider.height_cm:.0f} cm) a size {rec_size} frame is typical; "
                        f"you chose {rider.frame_size}. Weight balance was adjusted for this.")
    if CATEGORY_RANK[model["category"]] == 0 and style != "trail":
        warnings.append(f"The {model['name']} is an XC product — not intended for "
                        f"{STYLE_LABELS[style].lower()} riding.")
    if style == "park" and CATEGORY_RANK[model["category"]] < 2:
        warnings.append("Bike park riding usually calls for an enduro or DH-rated product.")

    tips.append(f"System weight used: {system_lb:.0f} lb "
                f"({rider.weight_kg:.0f} kg rider + {GEAR_KG:.0f} kg gear).")
    if model["spring"] == "air":
        tips.append("Cycle the suspension 10× after inflating, then re-check sag.")
    tips.append("Change one setting at a time, 2 clicks at a time, on the same test loop.")
    if model["note"]:
        tips.append(model["note"])

    return Recommendation(*headline, settings=settings, tips=tips, warnings=warnings)
