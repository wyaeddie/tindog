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
STYLES = ["xc", "trail", "enduro", "park", "dh"]
STYLE_LABELS = {"xc": "XC", "trail": "Trail", "enduro": "Enduro", "park": "Bike Park", "dh": "Downhill"}
GRAVITY = ("park", "dh")

FORK_SAG = {"xc": 18, "trail": 20, "enduro": 22, "park": 23, "dh": 25}
SHOCK_SAG = {"xc": 25, "trail": 28, "enduro": 30, "park": 31, "dh": 33}
LSC_FRACTION = {"xc": 0.45, "trail": 0.30, "enduro": 0.40, "park": 0.50, "dh": 0.45}
HSC_FRACTION = {"xc": 0.25, "trail": 0.25, "enduro": 0.40, "park": 0.55, "dh": 0.60}
CATEGORY_RANK = {"xc": 0, "trail": 1, "enduro": 2, "dh": 3}
TOKEN_BUMP = {"xc": 0, "trail": 0, "enduro": 1, "park": 2, "dh": 2}
EBIKE_EXTRA_LB = 15.0   # extra sprung weight of an e-bike, used by the calculated estimates
PUMP_TEMP_F = 70.0      # assume the pump is used indoors
PACK_LB = {"none": 0.0, "hip": 5.0, "day": 12.0, "big": 20.0}
PACK_TITLES = {"none": "No pack", "hip": "Hip pack", "day": "Day pack", "big": "Big pack"}
TERRAIN_TITLES = {"mixed": "Mixed", "rough": "Rocky / rooty", "flow": "Flow / jumps"}
PRIORITY_TITLES = {"climb": "Climbing", "balanced": "Balanced", "descend": "Descending"}
WHEEL_TITLES = {"29": "29″", "27.5": "27.5″", "mixed": "Mixed"}
TIRE_WIDTH_TITLES = {"standard": "2.3–2.4″", "wide": "2.5–2.6″"}
STYLE_TIP = {
    "xc": "XC: run the firm end of the sag range and use the lockout on climbs.",
    "dh": "Downhill: run the plush end of the sag range; add high-speed compression or a spacer if you bottom out.",
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
    skill: str = "intermediate"      # relaxed / intermediate / aggressive
    position: str = "neutral"        # neutral / forward
    # today's ride
    terrain: str = "mixed"           # mixed / rough / flow
    condition: str = "dry"           # dry / wet
    temperature_f: float = 70.0
    pack: str = "none"               # none / hip / day / big
    feel: str = "balanced"           # firm / balanced / plush
    priority: str = "balanced"       # climb / balanced / descend
    # the bike
    e_bike: bool = False
    wheel: str = "29"                # 29 / 27.5 / mixed
    tire_width: str = "standard"     # standard (2.3–2.4) / wide (2.5–2.6)
    inserts: bool = False
    frame_rear_sag: float | None = None
    frame_progression: str = "average"   # linear / average / progressive
    service_hours: float = 0.0       # hours since this end was serviced


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
    trail_psi: int | None = None
    tire_psi: int = 0
    service_due: bool = False


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


def _describe(nudges) -> str:
    return ", ".join(r for r, _ in nudges)


def calculate(model: dict, rider: RiderInput) -> Recommendation:
    is_fork = model["kind"] == "fork"
    style = rider.style
    mfg = model.get("mfg")
    brand = model["brand"]
    pack_lb = PACK_LB[rider.pack]
    rider_lb = rider.weight_kg * LB_PER_KG                  # body weight
    chart_lb = rider_lb + pack_lb                           # what the maker's charts are read with
    system_lb = (rider.weight_kg + GEAR_KG) * LB_PER_KG + pack_lb + (EBIKE_EXTRA_LB if rider.e_bike else 0)
    w = _weight_index(system_lb)

    rec_size = recommended_frame_size(rider.height_cm)
    frame_idx = FRAME_SIZES.index(rider.frame_size)
    fit_delta = FRAME_SIZES.index(rec_size) - frame_idx
    forward = 0.02 if rider.position == "forward" else 0
    front_bias = _clamp(0.40 + 0.01 * (frame_idx - 1) + 0.01 * fit_delta + forward, 0.36, 0.48)
    rear_bias = 1 - front_bias

    warnings: list[str] = []
    tips: list[str] = []
    settings: list[Setting] = []
    estimated: list[str] = []

    # ---- sag --------------------------------------------------------------
    # base = the middle of the recommended range; feel picks the firm end, middle or plush end.
    sag_min = sag_max = None
    sag_note = ""
    style_sag = float(FORK_SAG[style] if is_fork else SHOCK_SAG[style])
    if model["category"] == "xc":
        style_sag -= 3 if is_fork else 2
    maker_sag = mfg["sag"] if mfg and mfg.get("sag") and len(mfg["sag"]) == 2 else None
    if not is_fork and rider.frame_rear_sag and rider.frame_rear_sag > 0:
        fs = rider.frame_rear_sag
        base, lo, hi = fs, fs - 2, fs + 2
        maker_mid = (maker_sag[0] + maker_sag[1]) / 2 if maker_sag else style_sag
        sag_note = f"Frame maker: {_num(fs)}%. "
    elif maker_sag:
        s0, s1 = maker_sag
        sag_min, sag_max = int(s0), int(s1)
        base = (s0 + s1) / 2
        lo = s0 - 2 if s0 == s1 else s0
        hi = s1 + 2 if s0 == s1 else s1
        maker_mid = base
        rng = f"about {_num(s0)}%" if s0 == s1 else f"{_num(s0)}–{_num(s1)}%"
        sag_note = f"{brand}: {rng} of {'travel' if is_fork else 'shock stroke'}. "
    else:
        base, lo, hi, maker_mid = style_sag, style_sag - 2, style_sag + 2, style_sag
        if mfg:
            estimated.append("sag target")
    # Riding style picks where in the maker's (or frame's) range to sit; a firm/plush feel overrides it.
    range_from_maker = maker_sag is not None or (not is_fork and bool(rider.frame_rear_sag and rider.frame_rear_sag > 0))
    style_target = base if not range_from_maker else lo if style == "xc" else hi if style == "dh" else base
    target = lo if rider.feel == "firm" else hi if rider.feel == "plush" else style_target
    sag_pct = _round_half_up(target)
    sag = sag_pct / 100
    sag_mm = (rider.travel_mm if is_fork else rider.stroke_mm) * sag
    sag_range_text = f"{_num(lo)}–{_num(hi)}%"

    # ---- spring -----------------------------------------------------------
    trail_psi = None
    pressure_from_chart = False
    leverage = 0.0
    if model["spring"] == "air":
        max_psi = (rider.e_bike and mfg and mfg.get("ebikeMaxPsi")) or model["maxPsi"] or 999
        ebike_chart = bool(rider.e_bike and mfg and mfg.get("ebikePressure"))
        changes: list[str] = []
        t = _table(mfg and (mfg.get("ebikePressure") if ebike_chart else mfg.get("pressure")), rider.travel_mm)
        if t:
            hit = _lookup(t["type"], t["rows"], chart_lb)
            psi = hit["value"]
            pressure_from_chart = True
            chart = f"{brand} E-Bike+ chart" if ebike_chart else f"{brand} chart"
            if t["type"] == "linear":
                detail = (f"{chart}: {_num(hit['y0'])}–{_num(hit['y1'])} psi for "
                          f"{_num(hit['x0'])}–{_num(hit['x1'])} lb riders.")
            else:
                detail = f"{chart}, {_num(hit['x0'])}–{_num(hit['x1'])} lb row."
            if hit["outside"]:
                warnings.append(f"At {_round_half_up(chart_lb)} lb you're outside {_possessive(brand)} chart ({_chart_span(t)}) — "
                                + ("the chart was extended in a straight line." if t["type"] == "linear"
                                   else "the nearest row was used.")
                                + " Set sag carefully.")
        elif mfg and mfg.get("pressureRule") in ("bodyWeight", "bodyWeightWithGear", "fixed"):
            rule = mfg["pressureRule"]
            factor = mfg.get("pressureFactor") or 1
            if rule == "fixed":
                psi = mfg.get("pressureStart") or 0
            elif rule == "bodyWeightWithGear":
                psi = (chart_lb + GEAR_KG * LB_PER_KG) * factor
            else:
                psi = chart_lb * factor
            pressure_from_chart = True
            detail = f"{brand}: {mfg.get('ruleText') or 'start at your body weight in lb'}."
        else:
            if is_fork:
                psi = model["psiRatio"] * system_lb * (front_bias / 0.40) * math.sqrt(20 / sag_pct)
            else:
                leverage = rider.travel_mm / rider.stroke_mm
                psi = (model["psiRatio"] * system_lb * (rear_bias / 0.60)
                       * math.sqrt(28 / sag_pct) * (leverage / 2.7))
            estimated.append("air pressure")
            detail = "Estimate — set to sag. Adjust ±5 psi per ~2% sag change."
        if pressure_from_chart:
            f = math.sqrt(maker_mid / target)
            if abs(f - 1) > 1e-9:
                psi *= f
                changes.append(f"{'more' if f > 1 else 'less'} for {sag_pct}% sag")
            if is_fork and rider.position == "forward":
                psi *= 1.04
                changes.append("+4% for weight over the front")
            if rider.e_bike and not ebike_chart:
                psi += 10
                sram = brand == "RockShox" and is_fork
                changes.append(f"+10 psi for an e-bike{' (SRAM)' if sram else ''}")
                if not sram:
                    estimated.append("e-bike pressure")
            if changes:
                detail += f" Adjusted: {', '.join(changes)}."
            detail += f" Fine-tune ±10 psi to hit {sag_pct}% sag."
        on_trail = _round_half_up(psi)
        if on_trail > max_psi:
            warnings.append(f"{on_trail} psi exceeds the {max_psi} psi max — capped. "
                            "Consider more volume spacers or a firmer spring.")
            on_trail = max_psi
        # Air pressure follows absolute temperature: pump more indoors if the trail is colder.
        pump = on_trail
        if rider.temperature_f != PUMP_TEMP_F:
            pump = _round_half_up((on_trail + 14.7) * (PUMP_TEMP_F + 459.67) / (rider.temperature_f + 459.67) - 14.7)
            if pump > max_psi:
                pump = max_psi
            if pump != on_trail:
                detail += (f" Pump {pump} psi indoors ({_num(PUMP_TEMP_F)}°F) so it's {on_trail} psi at "
                           f"{_num(rider.temperature_f)}°F on the trail — set {on_trail} if you pump at the trailhead.")
        trail_psi = on_trail
        headline = ("Air pressure", str(pump), "psi")
        spring_value = pump
        settings.append(Setting("Air pressure", f"{pump} psi", f"{detail} Max {max_psi} psi."))
        rt = _table(mfg and mfg.get("ramp"), rider.travel_mm)
        if rt:
            r = _round_half_up(_lookup(rt["type"], rt["rows"], chart_lb)["value"])
            settings.append(Setting(mfg.get("rampLabel") or "Ramp-up chamber", f"{r} psi",
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

    if rider.feel != "balanced":
        feel_text = f" {rider.feel.capitalize()} end of {sag_range_text}."
    elif style_target != base:
        feel_text = f" {STYLE_LABELS[style]}: {'firm' if style == 'xc' else 'plush'} end of {sag_range_text}."
    else:
        feel_text = ""
    settings.append(Setting("Sag", f"{sag_pct}%  ·  {sag_mm:.1f} mm",
                            sag_note + ("Measured on the stanchion." if is_fork
                                        else "Measured on the shock shaft, seated in attack position.") + feel_text))

    # ---- adjustments for today's ride and the rider ------------------------
    reb, lsc, hsc, tok = [], [], [], []
    if rider.terrain == "rough":
        reb.append(("rocky terrain", -1))
        hsc.append(("rocky terrain", -1))
    elif rider.terrain == "flow":
        reb.append(("flow / jumps", 1))
        lsc.append(("flow / jumps", 1))
        hsc.append(("flow / jumps", 1))
        tok.append(("flow / jumps", 1))
    if rider.condition == "wet":
        reb.append(("wet", 1))
        lsc.append(("wet", -1))
    if rider.temperature_f < 40:
        reb.append(("cold oil", -1))
    if rider.skill == "relaxed":
        lsc.append(("relaxed riding", -1))
        hsc.append(("relaxed riding", -1))
    elif rider.skill == "aggressive":
        lsc.append(("aggressive riding", 1))
        hsc.append(("aggressive riding", 1))
        tok.append(("aggressive riding", 1))
    if rider.priority == "climb":
        lsc.append(("climbing priority", 1))
    elif rider.priority == "descend":
        lsc.append(("descending priority", -1))
    if rider.e_bike:
        reb.append(("e-bike", 1))

    # Riding style on top of the maker's baseline (estimates already include style).
    s_reb, s_lsc, s_hsc, s_tok = [], [], [], []
    why_style = f"{STYLE_LABELS[style]} riding"
    if style == "xc":
        s_lsc.append((why_style, 1))
    elif style == "enduro":
        s_hsc.append((why_style, 1))
    elif style == "park":
        s_hsc.append((why_style, 2)); s_lsc.append((why_style, 1)); s_reb.append((why_style, 1)); s_tok.append((why_style, 1))
    elif style == "dh":
        s_hsc.append((why_style, 2)); s_reb.append((why_style, -1)); s_tok.append((why_style, 1))

    # ---- progression ------------------------------------------------------
    tokens = token_max = None
    ebike_tokens = bool(rider.e_bike and mfg and mfg.get("ebikeTokens"))
    if rider.e_bike and not ebike_tokens:
        tok.append(("e-bike", 1))
    if not is_fork and model["spring"] == "air":
        if rider.frame_progression == "linear":
            tok.append(("linear frame", 1))
        elif rider.frame_progression == "progressive":
            tok.append(("progressive frame", -1))
    tok_sum = sum(a for _, a in tok)
    tok_text = f" {tok_sum:+d} for {_describe(tok)}." if tok else ""
    rows = mfg and (mfg.get("ebikeTokens") if ebike_tokens else mfg.get("tokens"))
    if rows:
        all_tok = tok + s_tok
        all_sum = sum(a for _, a in all_tok)
        tok_text = f" {all_sum:+d} for {_describe(all_tok)}." if all_tok else ""
        row = min(rows, key=lambda r: abs(r["travel"] - rider.travel_mm))
        n = int(_clamp(row["installed"] + all_sum, 0, row["max"]))
        tokens, token_max = n, row["max"]
        settings.append(Setting("Volume spacers", f"{n} token{'s' if n != 1 else ''}",
                                f"{brand}{' E-Bike+' if ebike_tokens else ''} stock for {_num(row['travel'])} mm travel: "
                                f"{row['installed']}.{tok_text} Max {row['max']}. Add one if you bottom out harshly."))
    elif model["tokens"]:
        t = model["tokens"]["default"] + TOKEN_BUMP[style]
        if system_lb > 210:
            t += 1
        elif system_lb < 140:
            t -= 1
        tokens, token_max = int(_clamp(t + tok_sum, 0, model["tokens"]["max"])), model["tokens"]["max"]
        estimated.append("volume spacers")
        settings.append(Setting("Volume spacers", f"{tokens} token{'s' if tokens != 1 else ''}",
                                f"Estimate.{tok_text} Max {token_max}. Add one if you bottom out harshly."))
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
        is_reb = key in ("rebound", "lsr", "hsr")
        rule = rules.get(key)
        nudges = (reb if is_reb else lsc if key == "lsc" else hsc) + \
            ((s_reb if is_reb else s_lsc if key == "lsc" else s_hsc) if rule else [])
        firm = sum(a for _, a in nudges)
        of = n
        is_mfg = True
        if rule:
            from_closed = rule["from"] == "closed"
            if rule["by"] == "middle":
                base_lo, base_hi = _round_half_up(n / 2), None
                detail = f"{brand}: start in the middle (of {n}), then add or remove to taste."
            else:
                rows_ = rule.get("rows") or [[0, 0]]
                by = rule["by"]
                if by == "weight":
                    hit = _lookup("steps", rows_, chart_lb)
                    basis = f" for {_num(hit['x0'])}–{_num(hit['x1'])} lb riders"
                elif by == "psi":
                    p_ = trail_psi if trail_psi is not None else spring_value
                    hit = _lookup("steps", rows_, p_)
                    basis = f" at {p_} psi"
                elif by == "rate":
                    hit = _lookup("steps", rows_, spring_value)
                    basis = f" for a {spring_value} lb/in spring"
                else:
                    hit = _lookup("steps", rows_, 0)
                    basis = ""
                base_lo = int(hit["row"][1])
                base_hi = int(hit["row"][2]) if len(hit["row"]) > 2 else None
                of = max(n, base_hi if base_hi is not None else base_lo)
                detail = (f"{brand} chart{basis}. Counted "
                          f"{'out from fully closed' if from_closed else 'in from fully open'}, of {of}.")
        else:
            from_closed = is_reb
            is_mfg = False
            if is_reb:
                b = 0.55 if key == "hsr" else 0.65
                base_lo = int(_clamp(_round_half_up(n * (b - 0.35 * w)), 1, max(1, n - 1)))
            else:
                frac = LSC_FRACTION[style] if key == "lsc" else HSC_FRACTION[style]
                base_lo = int(_clamp(_round_half_up(n * _clamp(frac + 0.1 * w, 0, 1)), 0, n))
            base_hi = None
            estimated.append(label.lower())
            detail = f"Estimate. Counted {'out from fully closed' if is_reb else 'in from fully open'}, of {n}."
        # + firm means firmer / slower: fewer clicks out from closed, or more clicks in from open
        shift = -firm if from_closed else firm
        new_lo = int(_clamp(base_lo + shift, 0, of))
        new_hi = int(_clamp(base_hi + shift, 0, of)) if base_hi is not None else None
        base_text = f"{base_lo}–{base_hi}" if base_hi is not None else f"{base_lo}"
        if firm != 0:
            direction = ("slower" if firm > 0 else "faster") if is_reb else ("firmer" if firm > 0 else "softer")
            detail += f" Adjusted {abs(firm)} {_clicks(abs(firm))} {direction} from {base_text} for {_describe(nudges)}."
        elif nudges:
            detail += f" ({_describe(nudges)} cancel out.)"
        rng = f"{new_lo}–{new_hi}" if new_hi is not None and new_hi != new_lo else None
        value = _round_half_up((new_lo + new_hi) / 2) if new_hi is not None else new_lo
        clicks.append(Click(key, value, of, from_closed, rng, is_mfg))
        settings.append(Setting(label, f"{rng or value} {_clicks(value) if rng is None else 'clicks'} "
                                       f"{'out' if from_closed else 'in'}", detail + why))

    # ---- lockout / climb --------------------------------------------------
    if model["climb"]:
        if style in GRAVITY:
            how = "Leave open for lift laps; use only on long fire-road climbs."
        elif rider.priority == "climb":
            how = "Climbing priority: use the firm / climb mode on every sustained climb."
        elif rider.priority == "descend":
            how = "Descending priority: leave it open except on pavement."
        else:
            how = "Open on descents, firm for long climbs and pavement."
        settings.append(Setting("Lockout / climb", model["climb"], how))
    else:
        settings.append(Setting("Lockout / climb", "None",
                                "Use more low-speed compression for climbing support."))

    # ---- tires (an estimate: tires are part of the suspension) -------------
    tire_lb = rider_lb + GEAR_KG * LB_PER_KG + pack_lb
    rear_tire = 0.11 * tire_lb + 3.5
    if rider.e_bike:
        rear_tire += 3
    if rider.tire_width == "wide":
        rear_tire -= 2
    if rider.inserts:
        rear_tire -= 2
    if rider.condition == "wet":
        rear_tire -= 1
    front_tire = rear_tire - 3
    if rider.wheel == "27.5":
        front_tire += 1
        rear_tire += 1
    elif rider.wheel == "mixed":
        rear_tire += 1
    front_psi = int(_clamp(_round_half_up(front_tire), 15, 40))
    rear_psi = int(_clamp(_round_half_up(rear_tire), 15, 40))
    tire_psi = front_psi if is_fork else rear_psi
    settings.append(Setting("Tire pressure", f"{tire_psi} psi {'front' if is_fork else 'rear'}",
                            f"Estimate for tubeless {WHEEL_TITLES[rider.wheel]} {TIRE_WIDTH_TITLES[rider.tire_width]} tires"
                            f"{' with inserts' if rider.inserts else ''}{' on an e-bike' if rider.e_bike else ''}. "
                            f"{'Rear' if is_fork else 'Front'}: {rear_psi if is_fork else front_psi} psi. "
                            "Lower = more grip; add 1–2 psi if you feel rim strikes."))

    # ---- service ------------------------------------------------------------
    hours = rider.service_hours
    service_due = False
    if hours > 0:
        if brand in ("Fox", "Marzocchi"):
            interval, full, schedule = 125, 125, f"{brand}: full service every 125 h or once a year"
        elif brand == "RockShox":
            interval, full = 50, 200
            schedule = (f"RockShox: {'lower-leg' if is_fork else 'air-can'} service every 50 h, "
                        "damper and spring every 200 h")
        else:
            interval, full, schedule = 100, 100, f"Typical interval about 100 h — check {_possessive(brand)} schedule"
        settings.append(Setting("Service", f"{_num(hours)} h since service", f"{schedule}."))
        if hours >= interval:
            service_due = True
            what = "a full service" if hours >= full else f"a {'lower-leg' if is_fork else 'air-can'} service"
            warnings.append(f"{model['name']} is due {what}: {_num(hours)} h since the last one. "
                            "Old oil and dry seals make damping feel slow and harsh.")

    # ---- fit & warnings -----------------------------------------------------
    if fit_delta != 0:
        total_in = _round_half_up(rider.height_cm / 2.54)
        warnings.append(f"At {total_in // 12}′{total_in % 12}″ ({_round_half_up(rider.height_cm)} cm) a size {rec_size} "
                        f"frame is typical; you chose {rider.frame_size}."
                        + ("" if pressure_from_chart else " Weight balance was adjusted for this."))
    if CATEGORY_RANK[model["category"]] == 0 and style not in ("trail", "xc"):
        warnings.append(f"The {model['name']} is an XC product — not intended for "
                        f"{STYLE_LABELS[style].lower()} riding.")
    if style in GRAVITY and CATEGORY_RANK[model["category"]] < 2:
        warnings.append(f"{'Bike park' if style == 'park' else 'Downhill'} riding usually calls for an enduro or DH-rated product.")
    if not is_fork and model["spring"] == "coil" and rider.frame_progression == "linear":
        warnings.append("Linear frame with a coil shock: use a progressive spring or more bottom-out control "
                        "(HBO / HSC) so you don't bottom out harshly.")
    if rider.temperature_f <= 32:
        warnings.append("Below freezing: fork and shock oil thickens, so everything feels slower and firmer "
                        "until it warms up.")

    # ---- source & tips --------------------------------------------------------
    quality = mfg["quality"] if mfg else "estimate"
    if quality == "manufacturer" and estimated:
        quality = "partial"
    if mfg:
        tips.append(f"Source: {mfg['sourceTitle']}.")
        if estimated:
            tips.append(f"Not in {_possessive(brand)} published chart, so estimated: {', '.join(estimated)}.")
        tips.append(f"Trail uses the maker's baseline as is. {STYLE_TIP[style]}" if style == "trail"
                    else f"{STYLE_LABELS[style]} adjusts the maker's baseline — each change is listed on its setting. {STYLE_TIP[style]}")
    else:
        tips.append(f"No published {brand} setup chart was found for this model — all values are calculated estimates.")
    today = []
    if rider.terrain != "mixed":
        today.append(TERRAIN_TITLES[rider.terrain].lower())
    if rider.condition == "wet":
        today.append("wet")
    if rider.temperature_f != PUMP_TEMP_F:
        today.append(f"{_num(rider.temperature_f)}°F")
    if rider.pack != "none":
        today.append(PACK_TITLES[rider.pack].lower())
    if rider.feel != "balanced":
        today.append(f"{rider.feel} feel")
    if rider.priority != "balanced":
        today.append(f"{PRIORITY_TITLES[rider.priority].lower()} priority")
    if rider.e_bike:
        today.append("e-bike")
    if today:
        tips.append(f"Adjusted for: {', '.join(today)}.")
    if pressure_from_chart:
        tips.append(f"Chart read at {_round_half_up(chart_lb)} lb"
                    + (f" (your {_round_half_up(rider_lb)} lb + {_num(pack_lb)} lb {PACK_TITLES[rider.pack].lower()})."
                       if pack_lb > 0 else " — your body weight."))
    else:
        tips.append(f"Estimates use your weight with gear: {_round_half_up(system_lb)} lb "
                    f"({_round_half_up(rider.weight_kg)} kg rider + {GEAR_KG:.0f} kg gear"
                    + (f" + {_num(pack_lb)} lb pack" if pack_lb > 0 else "")
                    + (f" + {_num(EBIKE_EXTRA_LB)} lb e-bike" if rider.e_bike else "") + ").")
    if model["spring"] == "air":
        tips.append("Cycle the suspension 10× after inflating, then re-check sag.")
    tips.append("Change one setting at a time, 2 clicks at a time, on the same test loop.")
    if model["note"]:
        tips.append(model["note"])

    max_out = None
    if model["spring"] == "air":
        max_out = (rider.e_bike and mfg and mfg.get("ebikeMaxPsi")) or model["maxPsi"]
    return Recommendation(*headline, settings=settings, tips=tips, warnings=warnings,
                          spring_value=spring_value, sag_percent=sag_pct, sag_min=sag_min, sag_max=sag_max,
                          tokens=tokens, token_max=token_max, clicks=clicks, quality=quality,
                          source_title=mfg["sourceTitle"] if mfg else None,
                          source_url=mfg.get("source") if mfg else None,
                          trail_psi=trail_psi, tire_psi=tire_psi, service_due=service_due)
