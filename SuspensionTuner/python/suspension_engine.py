"""Suspension setup calculator.

Mirrored 1:1 in apple/Sources/SuspensionKit/Engine.swift — change both
together (the parity tests in each language pin the same expected numbers).

Where the maker publishes a setup chart (the catalog's "mfg" block) the numbers
are read straight from it; anything the maker doesn't publish is calculated and
flagged as an estimate. Never exceed the max pressure printed on the product.
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
TOKEN_BUMP = {"trail": 0, "enduro": 1, "park": 2}
STYLE_TIP = {
    "trail": "Trail: the firm end of the sag range pedals best.",
    "enduro": "Enduro: aim for the middle of the sag range.",
    "park": "Bike Park: run the plush end of the sag range and add a volume spacer if you bottom out.",
}
QUALITY_TITLES = {"manufacturer": "Manufacturer chart", "partial": "Partly manufacturer", "estimate": "Estimate"}


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
class Click:
    key: str
    value: int
    of: int
    from_closed: bool
    range_text: str | None = None
    is_manufacturer: bool = False


@dataclass
class Recommendation:
    headline_label: str
    headline_value: str
    headline_unit: str
    settings: list[Setting] = field(default_factory=list)
    tips: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    spring_value: int = 0
    sag_percent: int = 0
    sag_min: int | None = None
    sag_max: int | None = None
    tokens: int | None = None
    token_max: int | None = None
    clicks: list[Click] = field(default_factory=list)
    quality: str = "estimate"
    source_title: str | None = None
    source_url: str | None = None


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


def _possessive(name: str) -> str:
    return name + ("'" if name.endswith("s") else "'s")


def _clicks(n) -> str:
    return "click" if n == 1 else "clicks"


def _num(v: float) -> str:
    return str(int(v)) if v == int(v) else f"{v:.1f}"


def _table(tables, travel: float):
    """The table for this travel (exact range, else the nearest one)."""
    if not tables:
        return None

    def dist(t):
        r = t.get("travel")
        if not r:
            return 0
        return r[0] - travel if travel < r[0] else travel - r[1] if travel > r[1] else 0
    return min(tables, key=dist)


def _lookup(kind: str, rows: list, x: float) -> dict:
    """"steps" rows are [from, value...]; "linear" rows are [x, y] points, interpolated between."""
    if kind == "linear" and len(rows) > 1:
        i = 0
        while i < len(rows) - 2 and x > rows[i + 1][0]:
            i += 1
        a, b = rows[i], rows[i + 1]
        v = a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0])
        return dict(row=a, value=v, x0=a[0], x1=b[0], y0=a[1], y1=b[1],
                    outside=x < rows[0][0] or x > rows[-1][0])
    width = rows[1][0] - rows[0][0] if len(rows) > 1 else 10
    i = 0
    for n, r in enumerate(rows):
        if r[0] <= x:
            i = n
    x1 = rows[i + 1][0] if i + 1 < len(rows) else rows[i][0] + width
    return dict(row=rows[i], value=rows[i][1], x0=rows[i][0], x1=x1, y0=rows[i][1], y1=rows[i][1],
                outside=x < rows[0][0] or x >= rows[-1][0] + width)


def _chart_span(t: dict) -> str:
    rows = t["rows"]
    end = rows[-1][0] if t["type"] == "linear" else rows[-1][0] + (rows[1][0] - rows[0][0] if len(rows) > 1 else 10)
    return f"{_num(rows[0][0])}–{_num(end)} lb"


def calculate(model: dict, rider: RiderInput) -> Recommendation:
    is_fork = model["kind"] == "fork"
    style = rider.style
    mfg = model.get("mfg")
    brand = model["brand"]
    rider_lb = rider.weight_kg * LB_PER_KG                  # what the maker's charts are read with
    system_lb = (rider.weight_kg + GEAR_KG) * LB_PER_KG     # used by the calculated estimates
    w = _weight_index(system_lb)

    rec_size = recommended_frame_size(rider.height_cm)
    frame_idx = FRAME_SIZES.index(rider.frame_size)
    fit_delta = FRAME_SIZES.index(rec_size) - frame_idx
    front_bias = _clamp(0.40 + 0.01 * (frame_idx - 1) + 0.01 * fit_delta, 0.36, 0.46)
    rear_bias = 1 - front_bias

    warnings: list[str] = []
    tips: list[str] = []
    settings: list[Setting] = []
    estimated: list[str] = []

    # ---- sag --------------------------------------------------------------
    sag_min = sag_max = None
    if mfg and mfg.get("sag") and len(mfg["sag"]) == 2:
        sag_min, sag_max = int(mfg["sag"][0]), int(mfg["sag"][1])
        sag_pct = _round_half_up((mfg["sag"][0] + mfg["sag"][1]) / 2)
    else:
        sag_pct = FORK_SAG[style] if is_fork else SHOCK_SAG[style]
        if model["category"] == "xc":
            sag_pct -= 3 if is_fork else 2
        if mfg:
            estimated.append("sag target")
    sag = sag_pct / 100
    sag_mm = (rider.travel_mm if is_fork else rider.stroke_mm) * sag
    sag_range = None
    if sag_min is not None:
        sag_range = f"about {sag_min}%" if sag_min == sag_max else f"{sag_min}–{sag_max}%"

    # ---- spring -----------------------------------------------------------
    pressure_from_chart = False
    leverage = 0.0
    if model["spring"] == "air":
        max_psi = model["maxPsi"] or 999
        t = _table(mfg and mfg.get("pressure"), rider.travel_mm)
        if t:
            hit = _lookup(t["type"], t["rows"], rider_lb)
            p = _round_half_up(hit["value"])
            pressure_from_chart = True
            if t["type"] == "linear":
                detail = (f"{brand} chart: {_num(hit['y0'])}–{_num(hit['y1'])} psi for "
                          f"{_num(hit['x0'])}–{_num(hit['x1'])} lb riders.")
            else:
                detail = f"{brand} chart, {_num(hit['x0'])}–{_num(hit['x1'])} lb row."
            detail += f" Fine-tune ±10 psi to hit {sag_range or f'{sag_pct}%'} sag."
            if hit["outside"]:
                warnings.append(f"At {_round_half_up(rider_lb)} lb you're outside {_possessive(brand)} chart ({_chart_span(t)}) — "
                                + ("the chart was extended in a straight line." if t["type"] == "linear"
                                   else "the nearest row was used.")
                                + " Set sag carefully.")
        elif mfg and mfg.get("pressureRule") == "bodyWeight":
            p = _round_half_up(rider_lb)
            pressure_from_chart = True
            detail = f"{brand}: start at your body weight in lb, then adjust until sag is {sag_range or f'{sag_pct}%'}."
        else:
            if is_fork:
                psi = model["psiRatio"] * system_lb * (front_bias / 0.40) * math.sqrt(20 / sag_pct)
            else:
                leverage = rider.travel_mm / rider.stroke_mm
                psi = (model["psiRatio"] * system_lb * (rear_bias / 0.60)
                       * math.sqrt(28 / sag_pct) * (leverage / 2.7))
            p = _round_half_up(psi)
            estimated.append("air pressure")
            detail = "Estimate — set to sag. Adjust ±5 psi per ~2% sag change."
        if p > max_psi:
            warnings.append(f"{p} psi exceeds the {max_psi} psi max — capped. "
                            "Consider more volume spacers or a firmer spring.")
            p = max_psi
        headline = ("Air pressure", str(p), "psi")
        spring_value = p
        settings.append(Setting("Air pressure", f"{p} psi", f"{detail} Max {max_psi} psi."))
        rt = _table(mfg and mfg.get("ramp"), rider.travel_mm)
        if rt:
            r = _round_half_up(_lookup(rt["type"], rt["rows"], rider_lb)["value"])
            settings.append(Setting("Ramp-up chamber", f"{r} psi",
                                    f"{brand} chart. More = more progressive (less bottom-out)."))
    else:
        stroke = rider.stroke_mm
        leverage = rider.travel_mm / stroke
        rear_static = rear_bias + 0.10
        raw = system_lb * rear_static * leverage / (sag * (stroke / 25.4))
        rate = 25 * _round_half_up(raw / 25)
        spring_value = rate
        headline = ("Spring rate", str(rate), "lb/in")
        settings.append(Setting("Coil spring", f"{rate} lb/in",
                                f"Calculated for {sag_pct}% sag at a {leverage:.2f}:1 leverage ratio — coil rates "
                                "depend on the frame, so makers don't chart them. Use 1–2 turns of preload at most."))

    settings.append(Setting("Sag", f"{sag_pct}%  ·  {sag_mm:.1f} mm",
                            (f"{brand}: {sag_range} of {'travel' if is_fork else 'shock stroke'}. " if sag_range else "")
                            + ("Measured on the stanchion" if is_fork
                               else "Measured on the shock shaft, seated in attack position")))

    # ---- progression ------------------------------------------------------
    tokens = token_max = None
    if mfg and mfg.get("tokens"):
        row = min(mfg["tokens"], key=lambda r: abs(r["travel"] - rider.travel_mm))
        tokens, token_max = row["installed"], row["max"]
        settings.append(Setting("Volume spacers", f"{tokens} token{'s' if tokens != 1 else ''}",
                                f"{brand} stock for {_num(row['travel'])} mm travel. Max {token_max}. "
                                "Add one if you bottom out harshly."))
    elif model["tokens"]:
        t = model["tokens"]["default"] + TOKEN_BUMP[style]
        if system_lb > 210:
            t += 1
        elif system_lb < 140:
            t -= 1
        tokens, token_max = int(_clamp(t, 0, model["tokens"]["max"])), model["tokens"]["max"]
        estimated.append("volume spacers")
        settings.append(Setting("Volume spacers", f"{tokens} token{'s' if tokens != 1 else ''}",
                                f"Estimate. Max {token_max}. Add one if you bottom out harshly."))
    elif model["spring"] == "air" and not (mfg and mfg.get("ramp")):
        settings.append(Setting("Progression", "See brand chart",
                                "Uses a ramp-up chamber / inserts instead of tokens."))

    # ---- damping ----------------------------------------------------------
    clicks: list[Click] = []
    adj = model["adjusters"]
    rules = {r["key"]: r for r in ((mfg and mfg.get("damping")) or [])}
    adjusters = [
        ("rebound", "Rebound", ""),
        ("lsr", "Low-speed rebound", ""),
        ("hsr", "High-speed rebound", ""),
        ("lsc", "Low-speed compression", " Controls brake dive and pedal bob."),
        ("hsc", "High-speed compression", " Controls big hits and square edges."),
    ]
    for key, label, why in adjusters:
        n = adj[key]
        if not n:
            continue
        rule = rules.get(key)
        if rule and rule["by"] == "middle":
            v = _round_half_up(n / 2)
            clicks.append(Click(key, v, n, False, None, True))
            settings.append(Setting(label, f"{v} {_clicks(v)} in",
                                    f"{brand}: start in the middle (of {n}), then add or remove to taste.{why}"))
        elif rule:
            rows = rule.get("rows") or [[0, 0]]
            by = rule["by"]
            if by == "weight":
                hit = _lookup("steps", rows, rider_lb)
                basis = f" for {_num(hit['x0'])}–{_num(hit['x1'])} lb riders"
            elif by == "psi":
                hit = _lookup("steps", rows, spring_value)
                basis = f" at {spring_value} psi"
            elif by == "rate":
                hit = _lookup("steps", rows, spring_value)
                basis = f" for a {spring_value} lb/in spring"
            else:
                hit = _lookup("steps", rows, 0)
                basis = ""
            lo = hit["row"][1]
            hi = hit["row"][2] if len(hit["row"]) > 2 else None
            v = _round_half_up((lo + hi) / 2) if hi is not None else int(lo)
            of = max(n, int(hi if hi is not None else lo))
            from_closed = rule["from"] == "closed"
            rng = f"{int(lo)}–{int(hi)}" if hi is not None else None
            clicks.append(Click(key, v, of, from_closed, rng, True))
            settings.append(Setting(label, f"{rng or v} {_clicks(rng or v)} {'out' if from_closed else 'in'}",
                                    f"{brand} chart{basis}. Counted "
                                    f"{'out from fully closed' if from_closed else 'in from fully open'}, of {of}.{why}"))
        else:
            is_reb = key in ("rebound", "lsr", "hsr")
            if is_reb:
                base = 0.55 if key == "hsr" else 0.65
                v = int(_clamp(_round_half_up(n * (base - 0.35 * w)), 1, max(1, n - 1)))
            else:
                frac = LSC_FRACTION[style] if key == "lsc" else HSC_FRACTION[style]
                v = int(_clamp(_round_half_up(n * _clamp(frac + 0.1 * w, 0, 1)), 0, n))
            estimated.append(label.lower())
            clicks.append(Click(key, v, n, is_reb, None, False))
            settings.append(Setting(label, f"{v} {_clicks(v)} {'out' if is_reb else 'in'}",
                                    f"Estimate. Counted {'out from fully closed' if is_reb else 'in from fully open'}, "
                                    f"of {n}.{why}"))

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
        warnings.append(f"At {total_in // 12}′{total_in % 12}″ ({_round_half_up(rider.height_cm)} cm) a size {rec_size} "
                        f"frame is typical; you chose {rider.frame_size}."
                        + ("" if pressure_from_chart else " Weight balance was adjusted for this."))
    if CATEGORY_RANK[model["category"]] == 0 and style != "trail":
        warnings.append(f"The {model['name']} is an XC product — not intended for "
                        f"{STYLE_LABELS[style].lower()} riding.")
    if style == "park" and CATEGORY_RANK[model["category"]] < 2:
        warnings.append("Bike park riding usually calls for an enduro or DH-rated product.")

    # ---- source & tips --------------------------------------------------------
    quality = mfg["quality"] if mfg else "estimate"
    if quality == "manufacturer" and estimated:
        quality = "partial"
    if mfg:
        tips.append(f"Source: {mfg['sourceTitle']}.")
        if estimated:
            tips.append(f"Not in {_possessive(brand)} published chart, so estimated: {', '.join(estimated)}.")
        tips.append(f"Manufacturer charts don't change with riding style. {STYLE_TIP[style]}")
    else:
        tips.append(f"No published {brand} setup chart was found for this model — all values are calculated estimates.")
    if pressure_from_chart:
        tips.append(f"Chart read at your body weight: {_round_half_up(rider_lb)} lb. "
                    "Riding with a heavy pack? Enter your weight with gear.")
    else:
        tips.append(f"Estimates use your weight with gear: {_round_half_up(system_lb)} lb "
                    f"({_round_half_up(rider.weight_kg)} kg rider + {GEAR_KG:.0f} kg gear).")
    if model["spring"] == "air":
        tips.append("Cycle the suspension 10× after inflating, then re-check sag.")
    tips.append("Change one setting at a time, 2 clicks at a time, on the same test loop.")
    if model["note"]:
        tips.append(model["note"])

    return Recommendation(*headline, settings=settings, tips=tips, warnings=warnings,
                          spring_value=spring_value, sag_percent=sag_pct, sag_min=sag_min, sag_max=sag_max,
                          tokens=tokens, token_max=token_max, clicks=clicks, quality=quality,
                          source_title=mfg["sourceTitle"] if mfg else None,
                          source_url=mfg.get("source") if mfg else None)
