"""Manufacturer setup charts → the "mfg" blocks in catalog.json (re-runnable).

    python3 tools/manufacturer_charts.py apple/Sources/SuspensionKit/Resources/catalog.json

Every number below is copied from the maker's owner's manual / spec sheet named in sourceTitle.
Edit here, re-run, then run both test suites.
"""
import json, sys
path = sys.argv[1]
cat = json.load(open(path, encoding="utf-8"))
M = {m["id"]: m for m in cat["models"]}

FOXM = "https://tech.ridefox.com/bike/owners-manuals/"
SRAM = "https://www.sram.com/globalassets/document-hierarchy/service-manuals/rockshox/front-suspension/2025-front-suspension-specifications.pdf"
W = list(range(120, 250, 10))          # Fox/Marzocchi weight rows: 120-130 … 240-250 lb

def steps(vals, travel=None):
    t = {"type": "steps", "rows": [[w, v] for w, v in zip(W, vals)]}
    if travel: t["travel"] = travel
    return t

def linear(points, travel=None):
    t = {"type": "linear", "rows": [list(p) for p in points]}
    if travel: t["travel"] = travel
    return t

def by_weight(key, vals):
    return {"key": key, "by": "weight", "from": "closed", "rows": [[w, v] for w, v in zip(W, vals)]}

def fixed(key, v, frm="closed"):
    return {"key": key, "by": "fixed", "from": frm, "rows": [[0, v]]}

def middle(key):
    return {"key": key, "by": "middle", "from": "open"}

def tok(*rows):
    return [{"travel": t, "installed": i, "max": m} for t, i, m in rows]

GRIP = list(range(13, 0, -1))
GRIPX = [16, 14, 12, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
X2_LSR = [9, 8, 7, 7, 7, 7, 6, 5, 4, 3, 3, 2, 1]
X2_HSR = [8, 7, 7, 6, 6, 5, 4, 4, 3, 2, 1, 0, 0]
FOX_FORK_SAG = [15, 20]

mfg = {}
# ---------------- Fox forks ----------------
mfg["fox-32-sc-factory"] = dict(quality="manufacturer", source=FOXM + "3104/fork--2026-32mm--or-34mm-",
    sourceTitle="FOX 2026 32/34 owner's manual", sag=FOX_FORK_SAG, maxPsi=140,
    pressure=[steps([65, 70, 74, 80, 85, 90, 96, 101, 106, 111, 116, 121, 126])],
    damping=[by_weight("rebound", GRIP)])
mfg["fox-34-sl-factory"] = dict(quality="manufacturer", source=FOXM + "3087/fork--2026-34sl",
    sourceTitle="FOX 2026 34 SL owner's manual", sag=FOX_FORK_SAG,
    pressure=[steps([64, 69, 74, 78, 83, 88, 92, 97, 102, 106, 111, 116, 120])],
    damping=[by_weight("rebound", GRIP)])
mfg["fox-36-sl-factory"] = dict(quality="manufacturer", source=FOXM + "3088/fork--2026-36sl",
    sourceTitle="FOX 2026 36 SL owner's manual", sag=FOX_FORK_SAG, maxPsi=120,
    pressure=[steps([65, 68, 72, 76, 79, 83, 87, 90, 94, 97, 101, 105, 108])],
    tokens=tok((140, 1, 6), (130, 2, 7), (120, 4, 8)),
    damping=[by_weight("rebound", GRIPX), fixed("lsc", 10), fixed("hsc", 10)])
mfg["fox-36-factory"] = dict(quality="manufacturer", source=FOXM + "3089/fork--2026-36mm",
    sourceTitle="FOX 2026 36 owner's manual", sag=FOX_FORK_SAG, maxPsi=120,
    pressure=[steps([66, 70, 74, 78, 82, 86, 89, 94, 99, 105, 109, 113, 117])],
    tokens=tok((170, 0, 5), (160, 1, 6), (150, 2, 7), (140, 4, 8), (130, 5, 9)),
    damping=[by_weight("lsr", X2_LSR), by_weight("hsr", X2_HSR), fixed("lsc", 10), fixed("hsc", 5)])
mfg["fox-38-factory"] = dict(quality="manufacturer", source=FOXM + "3103/fork--2026-38mm",
    sourceTitle="FOX 2026 38 owner's manual", sag=FOX_FORK_SAG, maxPsi=140,
    pressure=[steps([72, 76, 80, 84, 89, 93, 97, 102, 106, 110, 114, 119, 123])],
    tokens=tok((180, 1, 4), (170, 2, 5), (160, 3, 6), (150, 4, 6)),
    damping=[by_weight("lsr", X2_LSR), by_weight("hsr", X2_HSR), fixed("lsc", 10), fixed("hsc", 5)])
F40 = [10, 9, 8, 8, 7, 7, 6, 5, 5, 4, 3, 3, 2]
mfg["fox-40-factory"] = dict(quality="manufacturer", source=FOXM + "3102/fork--2026-40mm",
    sourceTitle="FOX 2026 40 owner's manual", sag=FOX_FORK_SAG, maxPsi=120,
    pressure=[linear([(120, 52), (150, 64), (180, 76), (210, 87), (250, 101)])],
    tokens=tok((203, 2, 5), (190, 3, 7)),
    damping=[by_weight("lsr", F40), by_weight("hsr", F40), fixed("lsc", 10), fixed("hsc", 5)])
mfg["fox-podium"] = dict(quality="manufacturer", source=FOXM + "3108/fork--2026-podium-",
    sourceTitle="FOX 2026 Podium owner's manual", sag=FOX_FORK_SAG, maxPsi=130,
    pressure=[steps([55, 61, 67, 73, 78, 84, 90, 96, 102, 108, 113, 119, 125])],
    tokens=tok((170, 2, 8), (160, 3, 8), (150, 4, 8)),
    damping=[by_weight("lsr", [15, 13, 13, 12, 10, 9, 8, 6, 5, 5, 3, 2, 1]),
             by_weight("hsr", [8, 7, 7, 6, 6, 5, 4, 4, 3, 2, 1, 0, 0]),
             fixed("lsc", 8), fixed("hsc", 6)])

# ---------------- Fox shocks ----------------
FLOAT_REB = [[0, 10], [120, 9], [140, 8], [160, 7], [180, 6], [200, 5], [220, 4], [240, 3], [260, 2], [280, 1]]
for mid, num, slug, title in [("fox-float-sl-factory", "3098", "shock--2026-float-sl-and-float-x", "FLOAT SL / FLOAT X"),
                              ("fox-float-x-factory", "3098", "shock--2026-float-sl-and-float-x", "FLOAT SL / FLOAT X"),
                              ("fox-float-factory", "3099", "shock--2026-float", "FLOAT")]:
    mfg[mid] = dict(quality="manufacturer", source=FOXM + f"{num}/{slug}",
        sourceTitle=f"FOX 2026 {title} owner's manual", sag=[25, 30], pressureRule="bodyWeight",
        damping=[{"key": "rebound", "by": "psi", "from": "closed", "rows": FLOAT_REB}])
X2P = [0, 100, 120, 140, 160, 180, 200, 220, 240, 260, 280]
mfg["fox-float-x2-factory"] = dict(quality="manufacturer", source=FOXM + "3023/shock--2026-float-x2",
    sourceTitle="FOX 2026 FLOAT X2 owner's manual", sag=[25, 30], pressureRule="bodyWeight",
    damping=[
        {"key": "lsr", "by": "psi", "from": "closed", "rows": [[p, v] for p, v in zip(X2P, [13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3])]},
        {"key": "hsr", "by": "psi", "from": "closed", "rows": [[p, v] for p, v in zip(X2P, [7, 7, 6, 6, 5, 4, 4, 3, 2, 2, 1])]},
        {"key": "lsc", "by": "psi", "from": "closed", "rows": [[0, 11, 13], [140, 9, 10], [240, 7, 8]]},
        {"key": "hsc", "by": "psi", "from": "closed", "rows": [[0, 6, 7], [140, 4, 5], [240, 2, 3]]}])
DR = list(range(200, 726, 25))
mfg["fox-dhx2-factory"] = dict(quality="manufacturer", source=FOXM + "3090/shock--2026-dhx2",
    sourceTitle="FOX 2026 DHX2 owner's manual", sag=[30, 30],
    damping=[
        {"key": "lsr", "by": "rate", "from": "closed", "rows": [[r, v] for r, v in zip(DR, [14, 14, 13, 13, 12, 11, 11, 10, 10, 9, 8, 8, 7, 6, 6, 5, 4, 4, 4, 3, 2, 2])]},
        {"key": "hsr", "by": "rate", "from": "closed", "rows": [[r, v] for r, v in zip(DR, [8, 8, 7, 7, 7, 6, 6, 5, 5, 5, 4, 4, 3, 3, 2, 2, 2, 1, 1, 1, 1, 0])]},
        {"key": "lsc", "by": "rate", "from": "closed", "rows": [[0, 11, 12], [350, 9, 10], [525, 7, 8]]},
        {"key": "hsc", "by": "rate", "from": "closed", "rows": [[0, 6, 7], [350, 4, 5], [525, 2, 3]]}])
mfg["fox-dhx-factory"] = dict(quality="partial", source=FOXM + "3100/shock--2026-dhx-",
    sourceTitle="FOX 2026 DHX owner's manual", sag=[30, 30])

# ---------------- Marzocchi ----------------
mfg["marzocchi-bomber-z1"] = dict(quality="manufacturer", source=FOXM + "2837/bomber-z1-or-dj",
    sourceTitle="Marzocchi Bomber Z1 owner's manual", sag=FOX_FORK_SAG, maxPsi=120,
    pressure=[steps([55, 59, 63, 67, 72, 76, 80, 85, 89, 93, 97, 102, 106])],
    damping=[by_weight("rebound", GRIP)])
mfg["marzocchi-bomber-z2"] = dict(quality="manufacturer", source=FOXM + "2838/bomber-z2",
    sourceTitle="Marzocchi Bomber Z2 owner's manual", sag=FOX_FORK_SAG, maxPsi=120,
    pressure=[steps([58, 63, 68, 72, 77, 82, 86, 91, 96, 100, 105, 110, 114])],
    damping=[by_weight("rebound", [13, 10, 9, 9, 8, 8, 8, 7, 7, 6, 4, 3, 2])])
mfg["marzocchi-bomber-58"] = dict(quality="manufacturer", source=FOXM + "2839/bomber-58",
    sourceTitle="Marzocchi Bomber 58 owner's manual", sag=FOX_FORK_SAG, maxPsi=120,
    pressure=[steps([49, 53, 57, 61, 65, 69, 73, 76, 80, 84, 88, 92, 96])],
    damping=[by_weight("lsr", GRIP)])
mfg["marzocchi-bomber-air"] = dict(quality="manufacturer", source=FOXM + "2841/bomber-air",
    sourceTitle="Marzocchi Bomber Air owner's manual", sag=[25, 30], pressureRule="bodyWeight", maxPsi=350,
    damping=[{"key": "rebound", "by": "psi", "from": "closed", "rows": FLOAT_REB}])
mfg["marzocchi-bomber-cr"] = dict(quality="partial", source=FOXM + "2840/bomber-cr",
    sourceTitle="Marzocchi Bomber CR owner's manual", sag=[30, 30])

# ---------------- RockShox (SRAM 2025 front suspension specifications) ----------------
def rs(title, pressure, tokens, maxPsi, charger=True):
    d = dict(quality="manufacturer", source=SRAM, sourceTitle=f"SRAM 2025 front suspension specifications — {title}",
             pressure=pressure, tokens=tokens, maxPsi=maxPsi)
    if charger:
        d["damping"] = [middle("lsc"), middle("hsc")]
    return d
E = [120, 140, 160, 180, 200, 220]   # SRAM weight-band edges (lb)
mfg["rockshox-pike-ultimate"] = rs("Pike", [linear(zip(E, [60, 70, 80, 90, 100, 110]), [120, 120]),
                                            linear(zip(E, [50, 60, 70, 80, 90, 100]), [130, 140])],
                                   tok((120, 1, 5), (130, 0, 5), (140, 0, 5)), 163)
mfg["rockshox-lyrik-ultimate"] = rs("Lyrik", [linear(zip(E, [60, 70, 80, 90, 100, 110]), [140, 140]),
                                              linear(zip(E, [50, 60, 70, 80, 90, 100]), [150, 160])],
                                    tok((140, 1, 5), (150, 0, 5), (160, 0, 5)), 163)
mfg["rockshox-zeb-ultimate"] = rs("ZEB", [linear(zip(E, [45, 54, 62, 70, 78, 87]), [150, 160]),
                                          linear(zip(E, [37, 45, 54, 62, 70, 78]), [170, 180]),
                                          linear(zip(E, [29, 37, 46, 54, 62, 70]), [190, 190])],
                                  tok((150, 2, 5), (160, 1, 5), (170, 1, 5), (180, 0, 4), (190, 0, 4)), 148)
mfg["rockshox-boxxer-ultimate"] = rs("BoXXer", [linear(zip(E, [115, 140, 165, 190, 215, 240]), [180, 180]),
                                                linear(zip(E, [90, 110, 130, 150, 170, 190]), [190, 200])],
                                     tok((180, 1, 6), (190, 0, 6), (200, 0, 6)), 300)
mfg["rockshox-sid-ultimate"] = rs("SID", [linear([(100, 39), (120, 51), (140, 64), (160, 76), (180, 87), (200, 99)])],
                                  tok((100, 1, 3), (110, 1, 3), (120, 0, 3)), 150, charger=False)
mfg["rockshox-sid-sl-ultimate"] = rs("SID SL", [linear([(120, 70), (140, 90), (160, 105), (180, 120), (200, 135)])],
                                     tok((100, 0, 3), (110, 0, 3)), 195, charger=False)
RE = [140, 160, 180, 200]
mfg["rockshox-recon-gold-rl"] = rs("Recon Gold", [linear(zip(RE, [70, 85, 100, 120]), [100, 120]),
                                                  linear(zip(RE, [60, 75, 90, 105]), [130, 150])],
                                   tok((100, 0, 2), (120, 0, 2), (130, 0, 2)), 205, charger=False)

# ---------------- Öhlins (main + ramp-up chamber, chart in kg converted to lb) ----------------
def KG(offset):   # Öhlins rows: psi = rider kg + offset, 50–120 kg in 10 kg steps
    return [(round(kg * 2.20462), kg + offset) for kg in range(50, 121, 10)]
OHL = "https://www.ohlins.com/storage/F215D6696D2C9FB948011A69BF9E7FC25CA74A3752EE43B9BBE48C95551E3858/275f5a21f13d4a0c840351a2ba8a0929/pdf/media/76327360c153475fba699581b7331237/OM_07258-04_MI_RXF34_RXF36.pdf"
mfg["ohlins-rxf38-m2"] = dict(quality="partial", source=None,
    sourceTitle="Öhlins RXF38 m.2 owner's manual", sag=[10, 15],
    pressure=[linear(KG(20))], ramp=[linear(KG(110))])
mfg["ohlins-rxf36-m2"] = dict(quality="partial", source=OHL,
    sourceTitle="Öhlins RXF34/RXF36 owner's manual", sag=[10, 15],
    pressure=[linear(KG(30))], ramp=[linear(KG(110))])
mfg["ohlins-dh38-m1"] = dict(quality="partial", source=None,
    sourceTitle="Öhlins DH38 owner's manual", sag=[20, 25])

# ---------------- E-bike charts (FOX "E-Bike+" columns, Marzocchi Z2 E-Bike) ----------------
def ebike(mid, vals, tokens=None, max_psi=None):
    mfg[mid]["ebikePressure"] = [steps(vals)]
    if tokens:
        mfg[mid]["ebikeTokens"] = tok(*tokens)
    if max_psi:
        mfg[mid]["ebikeMaxPsi"] = max_psi
ebike("fox-36-factory", [71, 76, 81, 85, 90, 95, 99, 104, 109, 113, 115, 117, 120],
      [(160, 3, 6), (150, 4, 7), (140, 4, 8)])
ebike("fox-38-factory", [81, 85, 89, 93, 98, 102, 106, 111, 115, 119, 123, 128, 132],
      [(180, 2, 4), (170, 3, 5), (160, 4, 6), (150, 5, 6)])
ebike("fox-podium", [55, 61, 68, 74, 80, 86, 93, 99, 105, 111, 118, 124, 130],
      [(170, 3, 8), (160, 4, 8), (150, 5, 8)])
ebike("marzocchi-bomber-z2", [65, 70, 74, 80, 85, 90, 96, 101, 106, 111, 116, 121, 126], max_psi=140)

for mid, d in mfg.items():
    m = M[mid]
    if "maxPsi" in d:
        m["maxPsi"] = d.pop("maxPsi")
    m["mfg"] = d
for m in cat["models"]:
    m.setdefault("mfg", None)
cat["version"] = 2
cat["disclaimer"] = ("Manufacturer starting points where the maker publishes a chart (marked as such); other values are "
                     "estimates. Always check the max pressure printed on your fork or shock. Brand and model names are "
                     "trademarks of their owners; Suspension Tuner is not affiliated with or endorsed by them.")
json.dump(cat, open(path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
open(path, "a").write("\n")
print(len(mfg), "models with manufacturer data")
