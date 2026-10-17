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
        rec = calculate(MODELS["fox-36-factory"], RiderInput(**RIDER, style="trail", travel_mm=150))   # trail = maker's baseline
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
        self.assertEqual(values(rec)["Low-speed rebound"], "7 clicks out")   # chart 8, 1 slower for bike park

    def test_kitsuma_coil_estimate(self):
        rec = calculate(MODELS["cane-creek-kitsuma-coil"],
                        RiderInput(**RIDER, style="park", travel_mm=170, stroke_mm=65))
        self.assertEqual((rec.headline_value, rec.headline_unit, rec.quality), ("450", "lb/in", "partial"))  # Cane Creek sag 25–35%

    def test_outside_chart_warns(self):
        rec = calculate(MODELS["fox-38-factory"],
                        RiderInput(weight_kg=180, height_cm=200, frame_size="XL", style="trail", travel_mm=170))
        self.assertEqual(rec.headline_value, "123")     # last row of the FOX 38 chart
        self.assertTrue(any("outside Fox's chart" in w for w in rec.warnings))

    def test_pressure_capped_at_max(self):
        rec = calculate(MODELS["ohlins-rxc34-m1"],          # no published chart → estimate, capped at 170
                        RiderInput(weight_kg=180, height_cm=200, frame_size="XL", style="trail", travel_mm=110))
        self.assertEqual((rec.headline_value, rec.quality), ("170", "estimate"))
        self.assertTrue(any("exceeds" in w for w in rec.warnings))

    # ---- ride, rider and bike factors (same values as EngineTests.swift)
    def _fox36(self, **kw):
        return calculate(MODELS["fox-36-factory"], RiderInput(**RIDER, style="enduro", travel_mm=150, **kw))

    def test_ebike_uses_fox_ebike_chart(self):
        rec = self._fox36(e_bike=True)
        v = values(rec)
        self.assertEqual(rec.headline_value, "99")
        self.assertEqual(v["Volume spacers"], "4 tokens")
        self.assertEqual(v["Low-speed rebound"], "5 clicks out")

    def test_ebike_adds_ten_psi_on_rockshox(self):
        rec = calculate(MODELS["rockshox-lyrik-ultimate"], RiderInput(**RIDER, style="trail", travel_mm=160, e_bike=True))
        self.assertEqual(rec.headline_value, "93")

    def test_pack_reads_heavier_row(self):
        self.assertEqual(self._fox36(pack="day").headline_value, "94")

    def test_feel_picks_end_of_sag_range(self):
        firm = self._fox36(feel="firm")
        self.assertEqual((firm.sag_percent, firm.headline_value), (15, "96"))
        self.assertEqual(self._fox36(feel="plush").sag_percent, 20)

    def test_cold_trail_means_pump_more_indoors(self):
        rec = self._fox36(temperature_f=40.0)
        self.assertEqual((rec.trail_psi, rec.headline_value), (89, "95"))

    def test_terrain_and_skill_nudge_clicks(self):
        v = values(calculate(MODELS["fox-36-factory"], RiderInput(**RIDER, style="trail", travel_mm=150, terrain="rough")))
        self.assertEqual(v["Low-speed rebound"], "7 clicks out")
        self.assertEqual(v["High-speed compression"], "6 clicks out")
        v = values(self._fox36(skill="aggressive"))
        self.assertEqual(v["Low-speed compression"], "9 clicks out")
        self.assertEqual(v["Volume spacers"], "3 tokens")
        rec = calculate(MODELS["rockshox-lyrik-ultimate"], RiderInput(**RIDER, style="enduro", travel_mm=150, priority="climb"))
        self.assertEqual(values(rec)["Low-speed compression"], "4 clicks in")

    def test_forward_position_adds_front_pressure(self):
        self.assertEqual(self._fox36(position="forward").headline_value, "93")

    def test_frame_sag_overrides_shock_sag(self):
        rec = calculate(MODELS["fox-float-x2-factory"],
                        RiderInput(**RIDER, style="trail", travel_mm=160, stroke_mm=62.5, frame_rear_sag=32))
        self.assertEqual((rec.sag_percent, rec.headline_value), (32, "172"))

    def test_tire_pressure_and_service(self):
        self.assertEqual(values(self._fox36())["Tire pressure"], "22 psi front")
        rec = self._fox36(inserts=True, tire_width="wide", service_hours=130)
        self.assertEqual(rec.tire_psi, 18)
        self.assertTrue(rec.service_due)
        rec = calculate(MODELS["rockshox-lyrik-ultimate"], RiderInput(**RIDER, style="enduro", travel_mm=150, service_hours=60))
        self.assertTrue(rec.service_due)

    def test_riding_style_adjusts_maker_baseline(self):
        def fox(style):
            r = calculate(MODELS["fox-36-factory"], RiderInput(**RIDER, style=style, travel_mm=150))
            return r, values(r)
        r, v = fox("enduro")
        self.assertEqual((r.headline_value, v["High-speed compression"]), ("89", "4 clicks out"))
        r, v = fox("park")
        self.assertEqual((v["High-speed compression"], v["Low-speed compression"], v["Low-speed rebound"], r.tokens),
                         ("3 clicks out", "9 clicks out", "5 clicks out", 3))
        r, v = fox("dh")
        self.assertEqual((r.sag_percent, r.headline_value, v["High-speed compression"], v["Low-speed rebound"], r.tokens),
                         (20, "83", "3 clicks out", "7 clicks out", 3))
        r, v = fox("xc")
        self.assertEqual((r.sag_percent, r.headline_value, v["Low-speed compression"]), (15, "96", "9 clicks out"))

    def test_xc_and_downhill_styles(self):
        self.assertEqual(calculate(MODELS["ext-aria"], RiderInput(**RIDER, style="dh", travel_mm=150, stroke_mm=57.5)).sag_percent, 33)
        sid = MODELS["rockshox-sid-sl-ultimate"]
        self.assertFalse(any("XC product" in w for w in calculate(sid, RiderInput(**RIDER, style="xc", travel_mm=100)).warnings))
        self.assertTrue(any("Downhill riding" in w for w in calculate(sid, RiderInput(**RIDER, style="dh", travel_mm=100)).warnings))

    def test_frame_leverage_curve_moves_shock_spacers(self):
        x2 = MODELS["fox-float-x2-factory"]
        kw = dict(**RIDER, style="trail", travel_mm=160, stroke_mm=62.5)
        self.assertEqual(values(calculate(x2, RiderInput(**kw, frame_progression="linear")))["Volume spacers"], "2 tokens")
        self.assertEqual(values(calculate(x2, RiderInput(**kw, frame_progression="progressive")))["Volume spacers"], "0 tokens")

    def test_new_brand_charts(self):
        mez = calculate(MODELS["manitou-mezzer-pro"], RiderInput(**RIDER, style="enduro", travel_mm=170))
        v = values(mez)
        self.assertEqual((mez.headline_value, v["IRT chamber"], v["Rebound"]), ("62", "94 psi", "6–7 clicks out"))
        helm = calculate(MODELS["cane-creek-helm-mkii-air"], RiderInput(**RIDER, style="enduro", travel_mm=160))
        self.assertEqual(helm.headline_value, "65")             # 35% of 185 lb
        selva = calculate(MODELS["formula-selva-s"], RiderInput(**RIDER, style="enduro", travel_mm=170))
        self.assertEqual(selva.headline_value, "79")            # 175 lb → 75, 200 lb → 85
        rs = calculate(MODELS["rockshox-super-deluxe-ultimate-air"], RiderInput(**RIDER, style="enduro", travel_mm=150, stroke_mm=60))
        self.assertEqual(rs.headline_value, "196")              # RockShox: weight with gear

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
