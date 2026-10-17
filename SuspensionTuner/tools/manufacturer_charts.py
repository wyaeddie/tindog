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
mfg["ohlins-rxf38-m2"] = dict(quality="partial",
    source="https://www.ohlins.eu/download/db/Ohlins_Europe_owners-manual-oehlins-mtb-front--00003536.pdf",
    sourceTitle="Öhlins RXF38 m.2 owner's manual", sag=[10, 15],
    pressure=[linear(KG(20))], ramp=[linear(KG(110))])
mfg["ohlins-rxf36-m2"] = dict(quality="manufacturer",
    source="https://www.ohlins.com/storage/548A98090FDA9236730D4C832474A95B0BC169689B71C64D205F44BA3CB5ABE5/4def7de90bca493cb2a999f99d34bdbf/pdf/media/fe3f1b241587489f98caf3f73ccd9139/07258-07_7_OM_MI_RXF36_m.2_AirCoil_TTX18.pdf",
    sourceTitle="Öhlins RXF36 m.2 owner's manual", sag=[10, 15],
    pressure=[linear(KG(20))], ramp=[linear(KG(110))],
    damping=[fixed("rebound", 15), fixed("lsc", 15), fixed("hsc", 3)])
mfg["ohlins-dh38-m1"] = dict(quality="partial", source=None,
    sourceTitle="Öhlins DH38 owner's manual", sag=[20, 25])

# ---------------- Helpers for charts that aren't on FOX's 10 lb rows ----------------
def rows(pairs, travel=None, kind="steps"):
    t = {"type": kind, "rows": [list(p) for p in pairs]}
    if travel: t["travel"] = travel
    return t

def kg(v):                     # kg → lb, rounded like the makers' own conversions
    return round(v * 2.20462)

def mid(a, b):                 # middle of a plush→firm range
    return (a + b) / 2

DVO_FORK = "https://tech.dvosuspension.com/wp-content/uploads/2020/09/DVO-Set-Up-Guide-2020-v4.pdf"
DVO_BANDS = [120, 140, 160, 180, 200, 220, 240]
def dvo_rebound(edges):        # rebound clicks from closed, by psi (rows: from psi, low, high)
    return {"key": "rebound", "by": "psi", "from": "closed", "rows": [list(e) for e in edges]}

mfg["dvo-sapphire-d1"] = dict(quality="partial", source=DVO_FORK, sourceTitle="DVO Fork Set Up Guide 2020 — Sapphire 34 D1",
    sag=[15, 20], maxPsi=150,
    pressure=[rows(zip(DVO_BANDS, [mid(55, 75), 80, 90, 100, 110, 120, 130]))],
    damping=[dvo_rebound([(0, 18, 22), (95, 14, 18), (105, 10, 14), (115, 6, 10), (125, 2, 6)])])
mfg["dvo-diamond-d1"] = dict(quality="partial", source=DVO_FORK, sourceTitle="DVO Fork Set Up Guide 2020 — Diamond D1",
    sag=[15, 20], maxPsi=170,
    pressure=[rows(zip(DVO_BANDS, [90, 105, 120, 125, 130, 135, 140]))],
    damping=[dvo_rebound([(0, 18, 22), (110, 14, 18), (120, 10, 14), (130, 6, 10), (140, 2, 6)])])
mfg["dvo-onyx-sc-d1"] = dict(quality="partial", source=DVO_FORK, sourceTitle="DVO Fork Set Up Guide 2020 — Onyx SC D1",
    sag=[15, 20], maxPsi=130,
    pressure=[rows(zip(DVO_BANDS, [62.5, 72.5, 77.5, 82.5, 87.5, 92.5, 97.5]))],
    damping=[dvo_rebound([(0, 18, 22), (75, 14, 18), (80, 10, 14), (85, 6, 10), (95, 2, 6)])])
mfg["dvo-topaz-t3-air"] = dict(quality="manufacturer",
    source="https://tech.dvosuspension.com/wp-content/uploads/2020/10/DVO-Set-Up-Guide-shock-2020.pdf",
    sourceTitle="DVO Topaz Air set-up guide", sag=[20, 30], maxPsi=300,
    pressure=[rows(zip(DVO_BANDS, [145, 157.5, 170, 182.5, 200, 220, 240]))],
    damping=[{"key": "rebound", "by": "weight", "from": "closed",
              "rows": [[w, a, b] for w, (a, b) in zip(DVO_BANDS, [(8, 9), (6, 7), (5, 6), (4, 5), (3, 4), (2, 3), (1, 2)])]}])
mfg["dvo-jade-x"] = dict(quality="partial",
    source="https://tech.dvosuspension.com/wp-content/uploads/2019/09/Jade-X-Set-Up-Guide-2.pdf",
    sourceTitle="DVO Jade X set-up guide", sag=[25, 30])

# Cane Creek: official starting rules (percent of body weight) and sag
CC = "https://cdn.shopify.com/s/files/1/0579/5987/4639/files/"
mfg["cane-creek-helm-mkii-air"] = dict(quality="partial", source=CC + "HelmMKII_UserManual_04_03_2025.pdf",
    sourceTitle="Cane Creek Helm MKII instruction manual", sag=[15, 25], maxPsi=150,
    pressureRule="bodyWeight", pressureFactor=0.35, ruleText="start at 30–40% of your body weight (lb) in psi")
mfg["cane-creek-kitsuma-air"] = dict(quality="partial", source=CC + "Kitsuma_Manual_2025_04_01.pdf",
    sourceTitle="Cane Creek Kitsuma manual", sag=[25, 35], maxPsi=300,
    pressureRule="bodyWeight", pressureFactor=0.875, ruleText="start at 75–100% of your body weight (lb) in psi")
mfg["cane-creek-kitsuma-coil"] = dict(quality="partial", source=CC + "Kitsuma_Manual_2025_04_01.pdf",
    sourceTitle="Cane Creek Kitsuma manual", sag=[25, 35])
mfg["cane-creek-db-air-il"] = dict(quality="partial", source=CC + "DB_IL_G2_Manual_2025_04_01.pdf",
    sourceTitle="Cane Creek DB Air IL G2 manual", sag=[25, 35], maxPsi=350,
    pressureRule="bodyWeight", pressureFactor=1.2, ruleText="start at 120% of your body weight (lb) in psi")

# Manitou (Hayes): main + IRT chambers by rider weight
HAYES = "https://hayesbicycle.zendesk.com/hc/article_attachments/"
MAT_W = [120, 140, 160, 180, 200, 220, 240]
mat_main = [38, 48, 56, 66, 74, 84, 97]          # 140 and 150 mm columns are identical
mat_irt = [51, 65, 78, 88, 107, 123, 138]
mfg["manitou-mattoc-pro"] = dict(quality="partial", source=HAYES + "14639548710935",
    sourceTitle="Manitou Mattoc Pro set-up guide (Gen 3)", sag=[20, 25], maxPsi=120,
    pressure=[rows(zip(MAT_W, mat_main), kind="linear")], ramp=[rows(zip(MAT_W, mat_irt), kind="linear")],
    rampLabel="IRT chamber",
    damping=[{"key": "rebound", "by": "weight", "from": "closed",
              "rows": [[0, 14], [130, 12], [150, 10], [170, 8], [190, 6], [210, 4], [230, 2]]}])
MEZ_W = [120, 140, 160, 180, 200, 220, 240]
mfg["manitou-mezzer-pro"] = dict(quality="partial", source=HAYES + "43742231652503",
    sourceTitle="Manitou Mezzer G2 Pro set-up guide", sag=[20, 25], maxPsi=120,
    pressure=[rows(zip(MEZ_W, [38, 47, 55, 64, 73, 82, 91]), [160, 160]),
              rows(zip(MEZ_W, [37, 45, 54, 62, 71, 80, 88]), [170, 170]),
              rows(zip(MEZ_W, [35, 44, 52, 61, 69, 77, 86]), [180, 180])],
    ramp=[rows(zip(MEZ_W, [57, 70, 83, 96, 109, 122, 135]), [160, 160]),
          rows(zip(MEZ_W, [55, 68, 81, 94, 107, 120, 133]), [170, 170]),
          rows(zip(MEZ_W, [53, 66, 79, 92, 105, 118, 131]), [180, 180])],
    rampLabel="IRT chamber",
    damping=[{"key": "rebound", "by": "weight", "from": "closed",
              "rows": [[w, a, b] for w, (a, b) in zip(MEZ_W, [(9, 10), (8, 9), (7, 8), (6, 7), (4, 5), (3, 4), (2, 3)])]}])
DOR_W = [120, 140, 160, 180, 200, 220]
mfg["manitou-dorado-pro"] = dict(quality="partial", source=HAYES + "4404709083799",
    sourceTitle="Manitou Dorado Pro set-up guide (MY22, mid-progressive)", sag=[20, 30], maxPsi=120,
    pressure=[rows(zip(DOR_W, [45, 50, 55, 60, 65, 75]), kind="linear")],
    ramp=[rows(zip(DOR_W, [70, 77, 84, 91, 98, 110]), kind="linear")], rampLabel="IRT chamber",
    damping=[{"key": "rebound", "by": "fixed", "from": "closed", "rows": [[0, 6, 10]]}])
mfg["manitou-mara-pro"] = dict(quality="partial", source=HAYES + "28476110600727",
    sourceTitle="Manitou Mara Pro set-up guide", sag=[25, 30], maxPsi=350)

# SR Suntour (MY22 manual, chart in kg → lb band edges)
SUN = "https://www.srsuntour.com/fileadmin/user_upload/Downloads/Consumer/Bike/Owners%20manuals/General_Fork_Manual/EN_MY22_SUS_fork_user_manual-20210820.pdf"
SUN_E = [kg(55), kg(65), kg(75), kg(85), kg(95)]
mfg["sr-suntour-durolux-38"] = dict(quality="partial", source=SUN, sourceTitle="SR Suntour MY22 fork manual — Durolux38",
    sag=[25, 30], maxPsi=105, pressure=[rows(zip(SUN_E, [40, 50, 60, 70, 85]), kind="linear")],
    tokens=tok((180, 2, 6), (170, 3, 6), (160, 4, 6)))
mfg["sr-suntour-auron-35"] = dict(quality="partial", source=SUN, sourceTitle="SR Suntour MY22 fork manual — Auron35",
    sag=[20, 25], maxPsi=120, pressure=[rows(zip(SUN_E, [50, 60, 70, 85, 105]), kind="linear")],
    tokens=tok((160, 7, 10), (150, 8, 10), (140, 9, 10)))
mfg["sr-suntour-zeron-35"] = dict(quality="partial", source=SUN, sourceTitle="SR Suntour MY22 fork manual — Zeron35",
    sag=[20, 25], maxPsi=120, pressure=[rows(zip(SUN_E, [50, 60, 70, 85, 105]), kind="linear")],
    tokens=tok((150, 3, 6), (140, 3, 6), (130, 3, 6)))
mfg["sr-suntour-triair"] = dict(quality="partial",
    source="https://www.srsuntour.com/fileadmin/user_upload/Downloads/Consumer/Bike/Owners%20manuals/MY_26_Rear_Shock_Manuals/MY26_General_Rear_Shock_Manual_English_20250417.pdf",
    sourceTitle="SR Suntour MY26 rear shock manual", sag=[25, 30], maxPsi=300)

# Formula
FOR = "https://www.rideformula.com/wp-content/uploads/"
mfg["formula-belva"] = dict(quality="partial", source=FOR + "2024/03/Manuale-Utente-Belva-ENG.pdf",
    sourceTitle="Formula Belva user manual", maxPsi=85,
    pressure=[rows([(110, 50), (155, 65), (200, 80)], kind="linear")])
mfg["formula-selva-s"] = dict(quality="partial", source=FOR + "2018/10/Manuale_SELVA_S_GB.pdf",
    sourceTitle="Formula Selva S manual", maxPsi=125,
    pressure=[rows([(110, 45), (125, 55), (150, 65), (175, 75), (200, 85), (225, 95), (250, 105), (275, 115)], kind="linear")])
mfg["formula-mod"] = dict(quality="partial", source=FOR + "2020/09/MOD-Owner-Manual.pdf",
    sourceTitle="Formula MOD owner manual", sag=[30, 30],
    damping=[fixed("rebound", 6)])

# EXT
EXT = "https://extremeshox.com/wp-content/uploads/2023/08/"
ERA_W = [kg(60), kg(70), kg(80), kg(90), kg(100)]
mfg["ext-era-v2"] = dict(quality="manufacturer", source=EXT + "quick-manual-Era-v2_20x30.pdf",
    sourceTitle="EXT Era V2 quick manual", sag=[15, 20], maxPsi=200,
    pressure=[rows(zip(ERA_W, [45, 55, 65, 75, 85]), kind="linear")],
    ramp=[rows(zip(ERA_W, [70, 85, 100, 115, 130]), kind="linear")], rampLabel="++ chamber",
    damping=[{"key": k, "by": "weight", "from": "closed", "rows": [[0, a]] + [[w, v] for w, v in zip(ERA_W, vals)]}
             for k, a, vals in [("hsc", 10, [9, 8, 7, 6, 5]), ("lsc", 10, [9, 8, 7, 6, 5]), ("rebound", 18, [16, 14, 12, 10, 8])]])
mfg["ext-storia-v3"] = dict(quality="partial", source="https://extremeshox.com/wp-content/uploads/2023/08/Storia_V3-S_Quick_Manual_1.1.pdf",
    sourceTitle="EXT Storia V3-S quick manual",
    damping=[fixed("hsc", 7), fixed("lsc", 6), fixed("rebound", 7)])

# X-Fusion
mfg["x-fusion-trace-36"] = dict(quality="manufacturer",
    source="https://www.xfusionshox.com/upload/files/Air%20%26%20Coil%20Spring%20Rate-v2.pdf",
    sourceTitle="X-Fusion fork pressure and spring rate chart (36 mm)", sag=[25, 30], maxPsi=120,
    pressure=[rows([(100, 45), (110, 47.5), (120, 50), (130, 52.5), (140, 55), (150, 57.5), (160, 60),
                    (170, 65), (180, 70), (190, 75), (200, 80), (220, 85)], kind="linear")],
    damping=[fixed("rebound", 8)])
mfg["x-fusion-o2-pro-rcx"] = dict(quality="partial",
    source="https://www.xfusionshox.com/upload/files/2012O2Setupguide1.pdf",
    sourceTitle="X-Fusion O2 setup guide", sag=[20, 25], maxPsi=300,
    pressureRule="bodyWeight", pressureFactor=0.8, ruleText="start at 80% of your body weight (lb) in psi")

# PUSH
mfg["push-industries-elevensix"] = dict(quality="partial",
    source="https://cdn.shopify.com/s/files/1/0519/4441/files/11.6_Manual.pdf",
    sourceTitle="PUSH ElevenSix manual", sag=[25, 33])

# Öhlins shocks
mfg["ohlins-ttx-air"] = dict(quality="partial",
    source="https://www.ohlins.eu/download/db/Ohlins_Europe_owners-manual-oehlins-mtb-ttx--00004276.pdf",
    sourceTitle="Öhlins TTX Air m.2 owner's manual", sag=[25, 35], maxPsi=300,
    pressureRule="fixed", pressureStart=170, ruleText="start at 170 psi")
mfg["ohlins-ttx22m"] = dict(quality="partial",
    source="https://www.ohlins.eu/download/db/Ohlins_Europe_owners-manual-oehlins-mtb-ttx22m--00002998.pdf",
    sourceTitle="Öhlins TTX22M owner's manual", sag=[25, 35])

# RockShox rear shocks (RockShox suspension user manual): psi = total weight incl. gear; DebonAir ≈30% ±5, Solo Air ≈25%
RSUM = "https://docs.sram.com/en-US/publications/5ODr3E6BhL1uWDnWhq4ATB"
for mid_, sag_ in [("rockshox-sidluxe-ultimate", [20, 30]), ("rockshox-deluxe-ultimate", [25, 35]),
                   ("rockshox-super-deluxe-ultimate-air", [25, 35]), ("rockshox-vivid-ultimate-air", [25, 35])]:
    mfg[mid_] = dict(quality="partial", source=RSUM, sourceTitle="RockShox suspension user manual", sag=sag_,
                     pressureRule="bodyWeightWithGear", ruleText="start at your total weight with gear (lb) in psi")
mfg["rockshox-vivid-ultimate-air"]["damping"] = [middle("lsc"), middle("hsc")]
for mid_ in ["rockshox-super-deluxe-ultimate-coil", "rockshox-vivid-ultimate-coil"]:
    mfg[mid_] = dict(quality="partial", source=RSUM, sourceTitle="RockShox suspension user manual", sag=[25, 35])

# RockShox 35 Gold RL (SRAM 2023 front suspension specifications)
mfg["rockshox-35-gold-rl"] = rs("35 Gold RL", [linear(zip(E, [75, 85, 95, 105, 115, 125]), [100, 120]),
                                              linear(zip(E, [55, 65, 75, 85, 95, 105]), [130, 160])],
                                tok((120, 1, 2), (130, 0, 2), (140, 0, 2), (160, 0, 2)), 163, charger=False)
mfg["rockshox-35-gold-rl"]["source"] = "https://www.sram.com/globalassets/document-hierarchy/service-manuals/rockshox/front-suspension/2023-front-suspension-oil-air-coil-token-specifications-english.pdf"
mfg["rockshox-35-gold-rl"]["sourceTitle"] = "SRAM 2023 front suspension specifications — 35 Gold RL"
mfg["rockshox-35-gold-rl"]["sag"] = [20, 30]

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
# Official manuals: Formula MOD is a coil shock, Manitou Mara Pro an air shock.
M["formula-mod"].update(spring="coil", psiRatio=None, maxPsi=None, tokens=None)
M["manitou-mara-pro"].update(spring="air", psiRatio=1.0, maxPsi=350, tokens={"default": 1, "max": 4})
cat["version"] = 2
cat["disclaimer"] = ("Manufacturer starting points where the maker publishes a chart (marked as such); other values are "
                     "estimates. Always check the max pressure printed on your fork or shock. Brand and model names are "
                     "trademarks of their owners; Suspension Tuner is not affiliated with or endorsed by them.")
json.dump(cat, open(path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
open(path, "a").write("\n")
print(len(mfg), "models with manufacturer data")
