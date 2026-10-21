# Publishing Suspension Tuner (iPhone)

An iPhone and iPad app. The iPad version is aimed at bike techs and shops as well as riders, so test it and
supply iPad screenshots too.

| | |
|---|---|
| Bundle ID | `solutions.wholestack.suspensiontuner` |
| Version / build | 1.0 / set automatically by `release.sh` (date-time) |
| Seller / copyright | © 2026 Whole Stack Solutions |
| Category | Sports (secondary: Utilities) |
| Age rating | 4+ (no objectionable content) |
| Price | Free, with the **Suspension Tuner Pro** in-app purchase (one-time, non-consumable) |
| App Privacy | **Data Not Collected** — no accounts, no analytics, everything stays on the device |
| Support email | eddie@wholestack.solutions |
| Encryption | No (already set in Info.plist, so no export question) |

## Steps

1. **Developer account** — enrolled in the Apple Developer Program ($99/yr). Note your **Team ID**
   (developer.apple.com → Account → Membership details).
2. **Xcode** — Xcode → Settings → Accounts → add your Apple ID.
3. **App record** — appstoreconnect.apple.com → Apps → **+ New App**
   - Platforms: **iOS**
   - Name: `Suspension Tuner` (if taken: `Suspension Tuner: MTB Setup`)
   - Primary language: English (U.S.)
   - Bundle ID: `solutions.wholestack.suspensiontuner` (register it first under
     Certificates, IDs & Profiles → Identifiers if it isn't in the list; Xcode can also create it
     automatically during step 4)
   - SKU: `suspension-tuner-1`
4. **Build & upload** — in Terminal:
   ```sh
   cd SuspensionTuner/apple
   TEAM_ID=ABCDE12345 ./release.sh --upload
   ```
   This regenerates the project, runs the unit tests, archives the app with your signing team
   and uploads it. (Without `--upload` it exports signed files to `build/release/`
   for the Transporter app.) If anything fails, open `SuspensionTuner.xcodeproj`, pick
   **Any iOS Device** → **Product → Archive** to see the error in Xcode.
5. **TestFlight** — after 10–30 min the builds appear under TestFlight. Install on your iPhone/iPad
   and run through the app once.
6. **Listing** — fill in the text below, add screenshots, pick the build for each platform.
7. **Submit for Review** — usually 1–3 days.

## In-app purchase: Suspension Tuner Pro

1. App Store Connect → your app → **Monetization → In-App Purchases → +**
   - Type: **Non-Consumable**
   - Reference name: `Suspension Tuner Pro`
   - Product ID: `solutions.wholestack.suspensiontuner.pro` (must match exactly — it's in `ProStore.swift`)
2. Price: pick a tier (suggested **$7.99**). Turn on **Family Sharing**.
3. Localization: display name `Suspension Tuner Pro`, description
   `Riding conditions, sag check, troubleshooter, unlimited bikes, ride log, share & print and the widget.`
4. Review information: a screenshot of the paywall (Rack tab → + with one bike saved) and the note
   `On the Rack tab, tap + with one bike saved, or tap Riding conditions, to see the purchase.`
5. When you submit the app version, tick the in-app purchase under **In-App Purchases and Subscriptions**
   so both are reviewed together.
6. Agreements, Tax and Banking must be complete (the Paid Apps agreement) before purchases work.

**Testing without paying:** running from Xcode uses `apple/StoreKit/Products.storekit`, so the purchase
sheet works in the Simulator with no real money. In Xcode, **Debug → StoreKit → Manage Transactions** lets
you refund or delete the test purchase to see the free version again. TestFlight builds use Apple's
sandbox (also free).

**Free vs Pro**

| Free | Pro |
|---|---|
| One bike, manufacturer-chart setup, pre-ride check, quick calculator, light / dark / automatic theme | Riding conditions, sag-check helper, symptom troubleshooter, unlimited bikes, Save to History, share & print, home-screen widget |

## Listing text

**Subtitle** (26/30)
```
Fork & shock setup for MTB
```

**Promotional text** (can change any time without review)
```
Pressure, sag, spacers and every damping click for your fork and shock, from the maker's own chart. Now with step-by-step instructions, hardtails and frame colours.
```

**Description**
```
Suspension Tuner gives you a solid starting setup for your mountain bike fork and rear shock, in seconds.

THE MAKER'S NUMBERS, CLEARLY LABELLED
Air pressure, sag, volume spacers, and rebound and compression clicks are read from the manufacturer's own setup charts for your weight wherever the maker publishes one, with a link to the guide. Every result carries a badge: Manufacturer chart, Partly manufacturer (some values estimated) or Estimate (no published chart), so you always know where a number came from.

YOUR BIKE RACK
Add each bike once: fork, shock, your weight, height and frame size, full suspension or hardtail, and the frame colour. Every bike gets its own drawing in its real colour, with an air or coil shock to match. Tap F or R on the bike to jump straight to that end.

ONE TAP FOR TODAY'S RIDING
Switch between XC, Trail, Enduro, Bike Park and Downhill and both ends re-tune instantly. Trail is the maker's baseline; the other styles adjust it and tell you what changed.

EVERY CLICK, SPELLED OUT
Drag the precision sliders to match your fork or shock, or follow Step by step: the same setup in plain words. Pump to this pressure, fit this many spacers, turn the red knob in until it stops, then count the clicks back out.

EVERYTHING YOU NEED AT THE BIKE
• Air pressure or coil spring rate, with the max pressure for your model
• Pressure to pump indoors vs. at a cold trailhead
• Sag in % and mm, with an O-ring check guide
• Rebound and compression clicks for every adjuster your fork or shock has
• Volume spacer count and lockout / climb advice
• Tire pressure starting point and service reminders
• Pre-ride check: pressures, sag, bolts, brakes in 60 seconds

RECORD WHAT YOU ACTUALLY RAN
Nudge the dial and drag the sliders to what you set on the trail. Save it to History with a note like "harsh on roots, 1 click less LSC" and compare later.

65 FORKS AND SHOCKS FROM 12 BRANDS
Popular models with the maker's setup data where it's published. Tap any model to open the maker's spec page.

FOR RIDERS AND BIKE TECHS
Works on iPhone and iPad. Keep a rack of bikes, and with Pro share or print a setup card for the workshop or a customer.

DARK OR LIGHT
A carbon-black dark theme and a titanium light theme, or let it follow your phone.

FREE AND PRO
Your first bike, the manufacturer setup, step-by-step instructions and the pre-ride check are free. Suspension Tuner Pro is a one-time unlock, no subscription, that dials it in deeper: riding conditions (terrain, weather, temperature, pack and feel), the guided sag-check helper and the symptom troubleshooter, plus unlimited bikes, the ride log, share & print and the home-screen widget.

No account, no ads, no tracking. Your data stays on your device.

Settings are starting points. Always check your manufacturer's setup guide and never exceed the maximum pressure printed on your fork or shock. Brand and model names are trademarks of their owners; Suspension Tuner is not affiliated with or endorsed by them.
```

**Keywords** (98/100 — no brand names, which Apple can reject)
```
mtb,suspension,fork,shock,sag,psi,air pressure,rebound,compression,mountain bike,enduro,trail,coil
```

**Support URL**: `https://www.wholestack.solutions` (support email: eddie@wholestack.solutions)
**Marketing URL** (optional): your Suspension Tuner page on wholestack.solutions
**Privacy Policy URL** (required): host `SuspensionTuner/website/privacy.html` on your site, e.g.
`https://suspensiontuner.wholestack.solutions/privacy.html`, and paste that link.

**App Review notes**
```
No login or account is needed. To test: Rack tab → + → enter a name, weight (e.g. 185 lb), height (5 ft 11 in), choose Full suspension, pick a fork (e.g. Fox → 36 Factory) and a rear shock (e.g. Fox → Float X2 Factory) → Save. Switch XC / Trail / Enduro / Bike Park / DH on the Rack tab; tap F or R on the bike, or the Tune tab, for the pressure dial, sag check, damping sliders and step-by-step instructions (? buttons explain them). Settings → Quick calculator is a single-screen version; Settings → Legal → Disclaimer explains the data sources. To see the in-app purchase, tap + again with one bike saved, or tap Riding conditions. All data is stored locally on the device.
```

## Screenshots needed

Apple expects real captures of the app (mockups and marketing images can't replace them). 3 to 10 per device:

| Device | Simulator to use | Size |
|---|---|---|
| iPhone 6.9″ (required) | iPhone 17 Pro Max / 18 Pro Max | 1320 × 2868 |
| iPad 13″ (required, the app runs on iPad) | iPad Pro 13-inch | 2064 × 2752 |

On Xcode 27 simulators open in Device Hub (Window → Devices and Simulators); take a screenshot there, or run
`xcrun simctl io booted screenshot ~/Desktop/shot.png`.

Suggested shots: My Bike Rack · Tune (dial + sag) · damping sliders + Step by step · Add bike (hardtail + colour) ·
Light theme · History.
