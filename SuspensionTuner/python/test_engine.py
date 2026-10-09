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
    def test_fox36_enduro(self):
        rec = calculate(MODELS["fox-36-factory"], RiderInput(**RIDER, style="enduro", travel_mm=150))
        v = values(rec)
        self.assertEqual(rec.headline_value, "88")
        self.assertEqual(v["Sag"], "22%  ·  33.0 mm")
        self.assertEqual(v["Volume spacers"], "3 tokens")
        self.assertEqual(v["Low-speed compression"], "7 clicks in")

    def test_kitsuma_coil_park(self):
        rec = calculate(MODELS["cane-creek-kitsuma-coil"],
                        RiderInput(**RIDER, style="park", travel_mm=170, stroke_mm=65))
        self.assertEqual((rec.headline_value, rec.headline_unit), ("450", "lb/in"))

    def test_float_x2_trail(self):
        rec = calculate(MODELS["fox-float-x2-factory"],
                        RiderInput(**RIDER, style="trail", travel_mm=160, stroke_mm=62.5))
        self.assertEqual(rec.headline_value, "174")

    def test_pressure_capped_at_max(self):
        rec = calculate(MODELS["fox-38-factory"],
                        RiderInput(weight_kg=180, height_cm=200, frame_size="XL", style="trail", travel_mm=170))
        self.assertEqual(rec.headline_value, "120")
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
