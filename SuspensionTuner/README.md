# Suspension Tuner

Pick a fork or rear shock, choose the brand and model, then enter your weight, height, frame size and riding style. The app returns a starting setup: air pressure or coil spring rate, sag, volume spacers, rebound, low- and high-speed compression and rebound, lockout use, fit warnings and setup notes.

![Fork](docs/screenshot-fork.png)
![Shock](docs/screenshot-shock.png)

## Features (iPhone app)
- **Garage:** save bikes with their fork, shock and rider. The home screen shows the bike with front and rear
  setups; a Trail / Enduro / Bike Park switch re-tunes both ends in one tap
- **Tune:** pressure / spring-rate dial with ± nudges (hold to repeat), O-ring sag check, damping sliders and
  token blocks to record what you actually ran, (?) help for sag and damping, Share / Print / Save to History
- **History:** saved setups with date, differences from the recommendation and your notes
- **Settings:** kg / lb, quick calculator (single-screen version), About, erase data
- Tap the brand badge or model name to open the model's spec page on the maker's website
  (`url` in catalog.json; models without a verified page fall back to a search of the brand's site)
- Real brand logos: add images named `logo-<brand>` (`logo-fox`, `logo-rockshox`, `logo-cane-creek`, …) to the
  Assets catalog and they replace the coloured monogram badges

## Layout

| Path | What |
|---|---|
| `apple/Sources/SuspensionKit/Resources/catalog.json` | **Single source of truth**: 65 forks and shocks from 12 brands |
| `apple/Sources/SuspensionKit/` | Swift catalog, calculation engine, saved-bike data model |
| `apple/Sources/SuspensionTunerApp/` | SwiftUI iPhone app |
| `apple/AppResources/` | App icon, `logo-<brand>` images, privacy manifest |
| `apple/project.yml` | XcodeGen spec for the iOS Xcode project |
| `apple/release.sh`, `apple/release/` | App Store archive/upload script and listing text |
| `python/suspension_engine.py` | Python port of the engine (kept 1:1 with `Engine.swift`, used for parity tests) |
| `python/app.py` | Optional PySide6 desktop calculator |
| `tools/` | Website image helpers |

## Run the iPhone app

```sh
cd apple
brew install xcodegen && xcodegen generate
open SuspensionTuner.xcodeproj      # pick an iPhone simulator (or your iPhone) and press ⌘R
```
Open `SuspensionTuner.xcodeproj`, not `Package.swift`: the package only holds the calculation library.

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

## How the numbers are calculated
- **System weight** = rider + 5 kg of gear. Front/rear weight split starts at 40/60 and shifts forward for larger frames, or when the rider is big for the chosen frame. The recommended frame size comes from height.
- **Sag target** by style. Fork: trail 20%, enduro 22%, bike park 23%. Shock: 28, 30 and 31%. XC products run 2–3% less.
- **Air pressure** = model pressure ratio × system weight × weight-split factor × sag factor (× leverage ratio for shocks). Capped at the model's maximum psi, with a warning.
- **Coil rate** = rear load × leverage ratio ÷ (sag × stroke), rounded to 25 lb/in.
- **Damping**: rebound slows as weight goes up. Low- and high-speed compression firm up from trail to enduro to bike park and with weight. Every value is given in clicks for that model's adjuster range.

These are starting points. Per-model ratios and click counts are approximations, so always check the manufacturer's setup chart and the max-pressure label on the product.
