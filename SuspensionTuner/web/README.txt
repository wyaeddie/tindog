Suspension Tuner — web app
==========================

A copy of the iPhone app that runs in any browser, with every feature free. It is plain HTML, CSS and
JavaScript: no server code, no database, no Python or PHP needed. Bikes and history are saved in each
visitor's own browser on their own device.

UPLOAD TO HOSTINGER
1. hPanel → Websites → your site → Domains → Subdomains, and create the subdomain you want, e.g.
   app.wholestack.solutions (or put it in a folder of an existing one, e.g.
   suspensiontuner.wholestack.solutions/app/ — every link inside is relative, so any folder works).
2. hPanel → File Manager → open that subdomain's folder (public_html/app or similar).
3. Upload everything in this "web" folder, keeping the layout:
     index.html  manifest.webmanifest  sw.js  .htaccess  css/  js/  data/  icons/
   Easiest: upload suspension-tuner-web.zip and use File Manager's "Extract".
   .htaccess is a hidden file; if you don't see it after extracting, turn on "Show hidden files".
4. hPanel → Security → SSL: make sure the subdomain has SSL (free). The app needs https for offline
   mode and "Add to Home Screen".
5. Open the address on your phone. iPhone: Share → Add to Home Screen. Android: menu → Install app.

UPDATING LATER
Upload the changed files over the old ones, and change VERSION in sw.js (e.g. "st-web-2") so phones that
installed the app pick up the new version.

KEEPING IT IN STEP WITH THE iPHONE APP
- data/catalog.json is a copy of apple/Sources/SuspensionKit/Resources/catalog.json. Copy it again when
  the catalog changes.
- js/engine.js mirrors the iPhone app's calculation engine line for line. After changing either, run
  python3 tools/web_parity.py on your computer to confirm both give the same numbers.

PRIVACY
Nothing is sent anywhere. Settings → Download backup saves a file with your bikes and history, and
Restore backup loads it on another phone or browser.
