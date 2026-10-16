# Publishing Suspension Tuner (iPhone)

An iPhone app (it also runs on iPad).

| | |
|---|---|
| Bundle ID | `solutions.wholestack.suspensiontuner` |
| Version / build | 1.0 / set automatically by `release.sh` (date-time) |
| Seller / copyright | © 2026 Whole Stack Solutions |
| Category | Sports (secondary: Utilities) |
| Age rating | 4+ (no objectionable content) |
| Price | your choice (Free suggested for v1.0) |
| App Privacy | **Data Not Collected** — no accounts, no analytics, everything stays on the device |
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

## Listing text

**Subtitle** (26/30)
```
Fork & shock setup for MTB
```

**Promotional text** (can change any time without review)
```
Save your bikes, pick Trail, Enduro or Bike Park, and get air pressure, sag, rebound and compression for your fork and shock in one tap.
```

**Description**
```
Suspension Tuner gives you a solid starting setup for your mountain bike fork and rear shock — in seconds.

FOR FOX, ROCKSHOX, MARZOCCHI AND ÖHLINS: THE MAKER'S NUMBERS
Air pressure, rebound and compression clicks, volume spacers and sag are read from the manufacturer's own setup charts for your weight — with a link to the guide. Other models get a calculated estimate, clearly labelled.

SAVE YOUR BIKES
Add each bike once with its fork, shock, your weight, height and frame size. Your garage shows both ends of every bike at a glance.

ONE TAP FOR TODAY'S RIDING
Switch between Trail, Enduro and Bike Park and both ends re-tune instantly.

EVERYTHING YOU NEED AT THE BIKE
• Air pressure or coil spring rate, with the max pressure for your model
• Sag in % and mm, with an O-ring check guide
• Rebound and compression clicks for every adjuster your fork or shock has
• Volume spacer (token) count and lockout / climb switch advice
• Fit check if your height and frame size don't match

RECORD WHAT YOU ACTUALLY RAN
Nudge the pressure dial and drag the damping sliders to what you set on the trail. Save it to History with a note like "harsh on roots — 1 click less LSC" and compare later.

65 FORKS AND SHOCKS
Popular models from 12 suspension brands. Tap any model to open the maker's spec page.

SHARE AND PRINT
Send a setup card to a friend or print it for the workshop.

Works on iPhone and iPad. No account, no ads, no tracking — your data stays on your device.

Settings are starting points. Always check your manufacturer's setup guide and never exceed the maximum pressure printed on your fork or shock. Brand and model names are trademarks of their owners; Suspension Tuner is not affiliated with or endorsed by them.
```

**Keywords** (98/100 — no brand names, which Apple can reject)
```
mtb,suspension,fork,shock,sag,psi,air pressure,rebound,compression,mountain bike,enduro,trail,coil
```

**Support URL**: `https://www.wholestack.solutions`
**Marketing URL** (optional): your Suspension Tuner page on wholestack.solutions
**Privacy Policy URL** (required): host `SuspensionTuner/website/privacy.html` on your site, e.g.
`https://www.wholestack.solutions/suspension-tuner/privacy.html`, and paste that link.

**App Review notes**
```
No login or account is needed. To test: Garage tab → + → enter a name, weight (e.g. 185 lb), height (5 ft 11 in), pick a fork (e.g. Fox → 36 Factory) and shock (e.g. Fox → Float X2 Factory) → Save. Change Trail/Enduro/Bike Park on the Garage tab; open the Tune tab for the dial, sag check and damping sliders (? buttons explain them). Settings → Quick calculator is a single-screen version. All data is stored locally on the device.
```

## Screenshots needed

Take them in the Simulator with **⌘S** (saved to the Desktop) — 3 to 5 per device type:

| Device | Simulator to use | Size |
|---|---|---|
| iPhone 6.9″ (required) | iPhone 16 Pro Max / 17 Pro Max | 1320 × 2868 |
| iPad 13″ (required, the app runs on iPad) | iPad Pro 13-inch (M4) | 2064 × 2752 |

Suggested shots: Garage home · Tune (fork) with sliders · Tune (shock) · Add bike sheet · History.
