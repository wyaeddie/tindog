# Suspension Tuner

An iPhone and iPad app by Whole Stack Solutions. Save your bikes (fork, shock, rider), pick your riding style and today's conditions, and get a starting setup for both ends: air pressure or coil spring rate, sag, volume spacers, rebound and compression clicks, lockout use, tire pressure and service reminders. The numbers come from each maker's own setup chart wherever one is published.

## Features (iPhone and iPad app)
- **Design:** "Carbon": black carbon weave with glass cards and condensed racing type in dark mode, brushed
  titanium in light mode. Light / Dark / Automatic in Settings → Appearance
- **My Bike Rack** (Rack tab): save bikes with their fork, shock and rider. Each bike has a drawing in the frame
  colour you pick (12 paints), a hardtail drawing for hardtails, and a rear shock drawn as an air can or a coil to
  match the model. XC / Trail / Enduro / Bike Park / Downhill tabs re-tune both ends in one tap; tap the bike to
  bounce it, tap F or R to open that end in Tune
- **Add / Edit bike:** rider weight, height, frame size, riding habits; Full suspension or Hardtail (hardtails lock
  the rear-shock setup); frame colour with a live preview; e-bike, wheels, tires, inserts; fork and shock models
  and travel; frame maker's sag and leverage curve; hours since service
- **Tune:** tick-ring pressure dial with ± nudges (hold to repeat), source badge (Manufacturer chart / Partly
  manufacturer / Estimate), indoor vs trailside pressure, O-ring sag check, precision sliders for every damping
  adjuster and the spacer count, **Step by step** plain-word instructions, tire and service cards, Share / Print /
  Save to History
- **History:** saved setups with date, differences from the recommendation and your notes
- **Settings:** Pro unlock / restore, Appearance, kg / lb, quick calculator, Disclaimer, About, erase data
- Tap the brand badge or model name to open the model's spec page on the maker's website
  (`url` in catalog.json; models without a verified page fall back to a search of the brand's site)
- Brand badges are neutral text monograms (no brand colours or logos), and the app states that it isn't affiliated
  with any manufacturer

## Layout

| Path | What |
|---|---|
| `apple/Sources/SuspensionKit/Resources/catalog.json` | **Single source of truth**: 65 forks and shocks from 12 brands |
| `apple/Sources/SuspensionKit/` | Swift catalog, calculation engine, saved-bike data model |
| `apple/Sources/SuspensionTunerApp/` | SwiftUI iPhone app |
| `apple/AppResources/` | App icon, app logo, privacy manifest |
| `apple/project.yml` | XcodeGen spec for the iOS Xcode project |
| `apple/run.sh` | Build, install and launch in the simulator in one command |
| `apple/release.sh`, `apple/release/` | App Store archive/upload script and listing text |
| `python/suspension_engine.py` | Python port of the engine (kept 1:1 with `Engine.swift`, used for parity tests) |
| `python/app.py` | Optional PySide6 desktop calculator |
| `tools/` | Website image helpers |

## Run the app

Quickest (checks Xcode and XcodeGen, picks a simulator, builds, installs and launches):
```sh
cd apple
bash run.sh
```

Or in Xcode:
```sh
cd apple
brew install xcodegen && xcodegen generate
open SuspensionTuner.xcodeproj
```
- Pick the **SuspensionTuner** scheme (not SuspensionKit or SuspensionTunerWidget, which build but install nothing),
  choose a simulator or your iPhone, and press ⌘R.
- Open `SuspensionTuner.xcodeproj`, not `Package.swift`: the package only holds the calculation library.
- **Xcode 27** no longer has a separate Simulator app. Simulators open in **Device Hub**
  (Window → Devices and Simulators); `run.sh` opens it for you.
- On your own iPhone: set your Team under Signing & Capabilities for both targets, turn on
  Settings → Privacy & Security → Developer Mode, and trust the developer under Settings → General →
  VPN & Device Management.

## Publishing
See `apple/release/APP_STORE.md` — listing text, privacy answers, screenshot sizes and the one-command
`TEAM_ID=… ./release.sh --upload` that archives the iPhone app and uploads it to App Store Connect.

Website image: `python3 tools/web_screenshot.py shot1.png shot2.png -o suspension-tuner.png` turns two
Simulator screenshots into one transparent PNG with phone frames.
Then `python3 tools/update_website_image.py --site "/Volumes/MyDrive/Whole Stack Solutions" --image suspension-tuner.png --apply`
swaps it into the Projects page (dry run without `--apply`; old files are backed up).

## Tests
Both engines are pinned to the same golden values:
```sh
cd apple && swift test
cd python && python3 -m unittest test_engine.py
```

## Free and Pro
Free: one bike, the manufacturer setup, pre-ride check and quick calculator. Light, dark or automatic theme (Settings → Appearance).
**Suspension Tuner Pro** (one-time in-app purchase `solutions.wholestack.suspensiontuner.pro`, StoreKit 2 in
`ProStore.swift`) unlocks riding conditions, the sag-check helper, the troubleshooter, unlimited bikes, Save to History,
share & print and the widget. Xcode runs use `apple/StoreKit/Products.storekit` so you can test the purchase for free; set up
the real product as described in `apple/release/APP_STORE.md`.

## Trailside tools
- **Hardtail or full suspension + frame colour** — set in Add/Edit bike. Hardtails lock out the rear-shock setup and get their own hardtail drawing; the colour you pick (12 factory-style paints) is the colour of your bike everywhere in the app. The rear shock is drawn as an air can or a coil spring to match the chosen model.
- **Step by step** — under the damping sliders on Tune, the same setup written out in plain words (pump to X psi, fit N spacers, turn the red knob fully clockwise then count N clicks out…) for riders who would rather read than read charts. Uses what you have set on the sliders.
- **Feels off? (symptom troubleshooter)** — pick what the fork or shock is doing (harsh, bottoming, diving, kicking, packing down, bobbing…) and get fixes worked out against *your* current clicks, best first; apply them to the dials or log them to History.
- **Sag check** — guided O-ring routine with a hold-still countdown, then type the mm you measured to get your sag % and the pressure (or spring) to try next.
- **Coil spring sizes** — the nearest stock springs with the sag each gives, and the spring size to buy (e.g. 450 × 2.5″).
- **Pre-ride check** — today's pressures, sag, tires, axles, brakes, headset, dropper, drivetrain and kit; ticks reset daily.
- **Home-screen widget** — small, medium and lock-screen widgets show the selected bike's pump numbers. The app and widget share the garage through the App Group `group.solutions.wholestack.suspensiontuner` (Xcode sets it up when you pick your Team under Signing & Capabilities).

## Where the numbers come from
Each model in `catalog.json` can carry an `mfg` block copied from the maker's own setup guide. The app reads it the way you would read the chart, using your body weight:

| Data | Source |
|---|---|
| FOX 32 SC, 34 SL, 36 SL, 36, 38, 40, Podium | FOX 2026 owner's manuals: pressure by 10 lb row, rebound (GRIP / GRIP X / GRIP X2 LSR + HSR) by row, compression clicks, stock/max volume spacers by travel, 15–20% sag |
| FOX FLOAT SL, FLOAT, FLOAT X, FLOAT X2, DHX2, DHX | FOX 2026 owner's manuals: start psi = body weight in lb, 25–30% sag (coil ~30%), rebound and compression by psi (air) or spring rate (DHX2) |
| RockShox Pike, Lyrik, ZEB, BoXXer, SID, SID SL, Recon Gold | SRAM 2025 front suspension specifications: pressure bands by weight and travel (interpolated within the band), stock/max Bottomless Tokens, max psi. Charger 3 LSC/HSC start in the middle (SRAM setup guide) |
| Marzocchi Bomber Z1, Z2, 58, Air, CR | Marzocchi owner's manuals: pressure and rebound by row, body-weight psi for the Bomber Air |
| Öhlins RXF36 m.2, RXF38 m.2, DH38 | Öhlins manuals: main and ramp-up chamber pressure by kg, sag range (partial) |
| DVO Sapphire / Diamond / Onyx SC D1, Topaz T3 Air, Jade X | DVO set-up guides: pressure by weight band, rebound clicks by psi, sag |
| Cane Creek Helm MKII, Kitsuma Air/Coil, DB Air IL | Cane Creek manuals: starting pressure as % of body weight, sag, max psi |
| Manitou Mattoc Pro, Mezzer Pro, Dorado Pro, Mara Pro | Hayes/Manitou set-up guides: main + IRT pressure by weight and travel, rebound, sag |
| SR Suntour Durolux 38, Auron 35, Zeron 35, TriAir | SR Suntour manuals: pressure by rider kg, sag by travel, spacers |
| Formula Belva, Selva S, Mod | Formula manuals: pressure by weight, MOD sag and rebound |
| EXT Era v2, Storia V3 | EXT quick manuals: + / ++ chamber pressures and clicks by weight, Storia starting clicks |
| X-Fusion Trace 36, O2 Pro RCX | X-Fusion pressure chart and setup guide |
| PUSH ElevenSix, Öhlins TTX Air / TTX22m, RockShox rear shocks | Official sag ranges and starting rules (RockShox: psi = total weight with gear) |

Still estimates (no official chart found): Öhlins RXC34 m.1, Öhlins TTX Flow, EXT Aria (EXT charts it by equivalent spring rate, not rider weight).

Anything a maker doesn't publish is calculated and labelled **Estimate** in the app (a badge at the top of each result shows Manufacturer chart / Partly manufacturer / Estimate and links to the guide):
- **Coil spring rate** is always calculated, because it depends on the frame's leverage: weight with 5 kg gear × rear load × leverage ÷ (sag × stroke), rounded to 25 lb/in.
- **Models without a chart** (Öhlins RXC34, TTX Flow, EXT Aria) and anything a maker doesn't publish (often damping clicks) use the older formula: per-model pressure ratio × weight with gear × front/rear split × sag factor, with style-based sag (fork 20/22/23%, shock 28/30/31%) and damping that firms up with weight and riding style.
- **Riding style on top of the maker's numbers.** Trail is the maker's baseline as is. The other styles adjust it, and each change is listed on its setting:

  | Style | Adjustment |
  |---|---|
  | XC | Firm end of the sag range (a few psi more), LSC 1 firmer |
  | Trail | None — maker's baseline |
  | Enduro | HSC 1 firmer |
  | Bike Park | HSC 2 firmer, LSC 1 firmer, rebound 1 slower, +1 volume spacer |
  | Downhill | Plush end of the sag range (a few psi less), HSC 2 firmer, rebound 1 faster, +1 volume spacer |

  A firm or plush feel in Riding conditions overrides the style's sag position. Estimated models already include style in their formula.

### Other factors
Set per bike (bike editor) or per ride (Bike Rack → Riding conditions). With everything at its default the numbers are exactly the maker's chart.

| Factor | What it changes |
|---|---|
| E-bike | FOX 36 / 38 / Podium and Marzocchi Z2 use the maker's E-Bike+ pressure and spacer charts; other charted forks +10 psi (SRAM's rule for RockShox), +1 spacer, rebound 1 click slower |
| Pack (hip / day / big) | Chart read at body weight + 5 / 12 / 20 lb |
| Feel (firm / balanced / plush) | Sag at the firm end / middle / plush end of the maker's range; pressure scaled by √(middle sag ÷ target sag) |
| Temperature | Air follows absolute temperature: pump more indoors for a cold trail (shows both numbers); below 40°F rebound 1 click faster |
| Terrain | Rocky: rebound and HSC 1 click faster/softer. Flow/jumps: rebound, LSC and HSC 1 click slower/firmer, +1 spacer |
| Wet | Rebound 1 slower, LSC 1 softer, tires 1 psi lower |
| Riding (relaxed / aggressive) | LSC and HSC 1 softer / 1 firmer (+1 spacer when aggressive) |
| Body position over the front | Fork pressure +4% |
| Climb / descend priority | LSC 1 firmer / softer, lockout advice |
| Frame maker's rear sag | Replaces the shock maker's range for sag, body-weight psi and coil rate |
| Wheels, tire width, inserts | Tire pressure estimate (0.11 × weight with gear + 3.5 psi rear, front 3 lower; −2 for 2.5–2.6″, −2 for inserts, +1 for 27.5″, +3 for e-bikes) |
| Hours since service | FOX / Marzocchi 125 h; RockShox 50 h lowers or air can, 200 h damper; others ~100 h — a warning when due |

Every adjusted click says why, e.g. "Adjusted 1 click faster from 6 for rocky terrain".

Always check the max-pressure label on the product. The in-app Disclaimer (Settings → Legal) explains the
Manufacturer chart / Partly manufacturer / Estimate labels and the rider's own responsibility.
