"""Check the web app's engine (web/js/engine.js) against the Python engine, line by line.

Runs every catalog model through the scenarios in parity_scenarios.json in both engines and
diffs the full output. Needs Python 3 and Node.js on your computer (not on the web server).

    python3 tools/web_parity.py
"""
import json, os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "python"))
from suspension_engine import RiderInput, calculate, load_catalog  # noqa: E402

catalog = load_catalog()
scen = json.load(open(os.path.join(HERE, "parity_scenarios.json")))

def dump_py():
    out = []
    for m in catalog["models"]:
        for i, s in enumerate(scen):
            t = (m["travel"]["min"] + m["travel"]["max"]) / 2
            st = (m["stroke"] or {"default": 0})["default"]
            r = calculate(m, RiderInput(weight_kg=s["kg"], height_cm=s["h"], frame_size=s["frame"], style=s["style"], travel_mm=t,
                stroke_mm=st, skill=s["skill"], position=s["position"], terrain=s["terrain"], condition=s["condition"],
                temperature_f=float(s["temp"]), pack=s["pack"], feel=s["feel"], priority=s["priority"], e_bike=s["ebike"],
                wheel=s["wheel"], tire_width=s["width"], inserts=s["inserts"], frame_rear_sag=s["frameSag"],
                frame_progression=s["prog"], service_hours=float(s["hours"])))
            tp = "-" if r.trail_psi is None else str(r.trail_psi)
            tk = "-" if r.tokens is None else str(r.tokens)
            out.append(f"{m['id']} {i} {r.quality} {r.headline_value} {tp} {r.tire_psi} {str(r.service_due).lower()} {tk}")
            out += [f"  {x.label}|{x.value}|{x.detail}" for x in r.settings]
            out += [f"  !{x}" for x in r.warnings] + [f"  -{x}" for x in r.tips]
            out += [f"  c {k.key} {k.value} {k.of} {str(k.from_closed).lower()} {k.range_text or '-'} {str(k.is_manufacturer).lower()}" for k in r.clicks]
    return "\n".join(out) + "\n"

JS = r"""
const E = require(process.argv[2]); const fs = require("fs");
const c = JSON.parse(fs.readFileSync(process.argv[3])); const sc = JSON.parse(fs.readFileSync(process.argv[4]));
let out = "";
for (const m of c.models) sc.forEach((s, i) => {
  const t = (m.travel.min + m.travel.max) / 2, st = (m.stroke || { default: 0 }).default;
  const r = E.calculate(m, E.riderInput({ weightKg: s.kg, heightCm: s.h, frameSize: s.frame, style: s.style, travelMm: t, strokeMm: st,
    skill: s.skill, position: s.position, terrain: s.terrain, condition: s.condition, temperatureF: s.temp, pack: s.pack, feel: s.feel,
    priority: s.priority, eBike: s.ebike, wheel: s.wheel, tireWidth: s.width, inserts: s.inserts, frameRearSag: s.frameSag,
    frameProgression: s.prog, serviceHours: s.hours }));
  out += `${m.id} ${i} ${r.quality} ${r.headlineValue} ${r.trailPsi == null ? "-" : r.trailPsi} ${r.tirePsi} ${r.serviceDue} ${r.tokens == null ? "-" : r.tokens}\n`;
  for (const x of r.settings) out += `  ${x.label}|${x.value}|${x.detail}\n`;
  for (const x of r.warnings) out += `  !${x}\n`;
  for (const x of r.tips) out += `  -${x}\n`;
  for (const k of r.clicks) out += `  c ${k.key} ${k.value} ${k.of} ${k.fromClosed} ${k.rangeText || "-"} ${k.isManufacturer}\n`;
});
process.stdout.write(out);
"""

with tempfile.NamedTemporaryFile("w", suffix=".cjs", delete=False) as f:
    f.write(JS)
js = subprocess.run(["node", f.name, os.path.join(ROOT, "web", "js", "engine.js"), os.path.join(ROOT, "web", "data", "catalog.json"),
                     os.path.join(HERE, "parity_scenarios.json")], capture_output=True, text=True, check=True).stdout
os.unlink(f.name)
py = dump_py()
bad = [(a, b) for a, b in zip(py.splitlines(), js.splitlines()) if a != b]
if bad or len(py.splitlines()) != len(js.splitlines()):
    for a, b in bad[:10]:
        print("python:", a, "\nweb:   ", b)
    sys.exit(f"✗ {len(bad)} lines differ")
print(f"✓ web engine matches Python on {len(py.splitlines())} lines ({len(catalog['models'])} models × {len(scen)} scenarios)")
