"""Run: python3 -m unittest test_engine.py   (Swift mirror: apple/Tests/SuspensionKitTests)"""
import unittest

from suspension_engine import RiderInput, calculate, load_catalog, recommended_frame_size, specs_url

CATALOG = load_catalog()
MODELS = {m["id"]: m for m in CATALOG["models"]}
RIDER = dict(weight_kg=84, height_cm=180, frame_size="L")


def values(rec):
    return {s.label: s.value for s in rec.settings}


class EngineTests(unittest.TestCase):
    # These golden values are duplicated in EngineTests.swift to keep both engines in lockstep.
    def test_fox36_reads_fox_chart(self):
        rec = calculate(MODELS["fox-36-factory"], RiderInput(**RIDER, style="enduro", travel_mm=150))
        v = values(rec)
        self.assertEqual(rec.headline_value, "89")      # 84 kg = 185 lb → 180–190 lb row
        self.assertEqual(rec.quality, "manufacturer")
        self.assertEqual(v["Sag"], "18%  ·  27.0 mm")
        self.assertEqual((rec.sag_min, rec.sag_max), (15, 20))
        self.assertEqual(v["Volume spacers"], "2 tokens")
        self.assertEqual(rec.token_max, 7)
        self.assertEqual(v["Low-speed rebound"], "6 clicks out")
        self.assertEqual(v["High-speed rebound"], "4 clicks out")
        self.assertEqual(v["Low-speed compression"], "10 clicks out")
        self.assertEqual(v["High-speed compression"], "5 clicks out")
        self.assertTrue(all(c.from_closed and c.is_manufacturer for c in rec.clicks))

    def test_lyrik_reads_sram_chart(self):
        rec = calculate(MODELS["rockshox-lyrik-ultimate"], RiderInput(**RIDER, style="trail", travel_mm=160))
        v = values(rec)
        self.assertEqual(rec.headline_value, "83")      # 180–200 lb band: 80–90 psi
        self.assertEqual(v["Volume spacers"], "0 tokens")
        self.assertEqual(v["Low-speed compression"], "3 clicks in")
        self.assertEqual(rec.quality, "partial")        # rebound isn't published (TrailHead app only)
        self.assertFalse(next(c for c in rec.clicks if c.key == "rebound").is_manufacturer)

    def test_zeb_picks_table_for_travel(self):
        zeb = MODELS["rockshox-zeb-ultimate"]
        self.assertEqual(calculate(zeb, RiderInput(**RIDER, style="enduro", travel_mm=190)).headline_value, "56")
        self.assertEqual(calculate(zeb, RiderInput(**RIDER, style="enduro", travel_mm=160)).headline_value, "72")

    def test_float_x2_body_weight_and_psi_table(self):
        rec = calculate(MODELS["fox-float-x2-factory"],
                        RiderInput(**RIDER, style="trail", travel_mm=160, stroke_mm=62.5))
        v = values(rec)
        self.assertEqual(rec.headline_value, "185")
        self.assertEqual(v["Low-speed rebound"], "8 clicks out")
        self.assertEqual(v["Low-speed compression"], "9–10 clicks out")
        self.assertEqual(next(c for c in rec.clicks if c.key == "lsc").value, 10)

    def test_dhx2_coil_rate_and_rate_table(self):
        rec = calculate(MODELS["fox-dhx2-factory"], RiderInput(**RIDER, style="park", travel_mm=160, stroke_mm=62.5))
        self.assertEqual(rec.headline_value, "475")
        self.assertEqual(values(rec)["Low-speed rebound"], "8 clicks out")

    def test_kitsuma_coil_estimate(self):
        rec = calculate(MODELS["cane-creek-kitsuma-coil"],
                        RiderInput(**RIDER, style="park", travel_mm=170, stroke_mm=65))
        self.assertEqual((rec.headline_value, rec.headline_unit, rec.quality), ("450", "lb/in", "estimate"))

    def test_outside_chart_warns(self):
        rec = calculate(MODELS["fox-38-factory"],
                        RiderInput(weight_kg=180, height_cm=200, frame_size="XL", style="trail", travel_mm=170))
        self.assertEqual(rec.headline_value, "123")     # last row of the FOX 38 chart
        self.assertTrue(any("outside Fox's chart" in w for w in rec.warnings))

    def test_pressure_capped_at_max(self):
        rec = calculate(MODELS["dvo-onyx-sc-d1"],
                        RiderInput(weight_kg=180, height_cm=200, frame_size="XL", style="trail", travel_mm=170))
        self.assertEqual(rec.headline_value, "140")
        self.assertTrue(any("exceeds" in w for w in rec.warnings))

    def test_xc_fork_in_park_warns(self):
        rec = calculate(MODELS["rockshox-sid-sl-ultimate"], RiderInput(**RIDER, style="park", travel_mm=100))
        self.assertTrue(any("XC product" in w for w in rec.warnings))

    def test_frame_size_from_height(self):
        self.assertEqual([recommended_frame_size(h) for h in (155, 170, 180, 195)], ["S", "M", "L", "XL"])

    def test_every_model_calculates(self):
        for m in CATALOG["models"]:
            r = RiderInput(**RIDER, style="enduro", travel_mm=m["travel"]["default"],
                           stroke_mm=(m["stroke"] or {"default": 0})["default"])
            rec = calculate(m, r)
            self.assertTrue(int(rec.headline_value) > 0, m["id"])


    def test_specs_urls(self):
        self.assertEqual(specs_url(CATALOG, MODELS["fox-36-factory"]), "https://ridefox.com/pages/fox-36")
        self.assertEqual(specs_url(CATALOG, MODELS["dvo-topaz-t3-air"]),
                         "https://www.google.com/search?q=site%3Advosuspension.com+Topaz+T3+Air+specs")
        for m in CATALOG["models"]:
            self.assertTrue(specs_url(CATALOG, m).startswith("https://"), m["id"])


if __name__ == "__main__":
    unittest.main()
