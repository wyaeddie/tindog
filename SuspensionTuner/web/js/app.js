// Suspension Tuner web app: My Bike Rack, Tune, History and Settings, with the bike editor and
// trailside tools as sheets. Everything is stored in this browser (localStorage); nothing is sent anywhere.
(() => {
  "use strict";
  const E = window.Engine, B = window.Bike;
  const STORE_KEY = "suspensionTuner.v1";
  const PRIVACY_URL = "https://suspensiontuner.wholestack.solutions/privacy.html";
  const MONOGRAMS = { Fox: "FOX", RockShox: "RS", "Öhlins": "Ö", Marzocchi: "MZ", "Cane Creek": "CC", DVO: "DVO", Formula: "F",
    Manitou: "M", EXT: "EXT", "PUSH Industries": "PUSH", "SR Suntour": "SR", "X-Fusion": "XF" };
  const STYLE_ICONS = {
    xc: '<circle cx="12" cy="13" r="7.5" fill="none" stroke="currentColor" stroke-width="2"/><path d="M12 13V9M10 3h4M12 3v2.5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    trail: '<path d="M12 2 5 12h4l-4 6h14l-4-6h4z"/><rect x="11" y="18" width="2" height="4"/>',
    enduro: '<path d="M2 20 9 7l4 7 3-4 6 10z"/>',
    park: '<circle cx="15" cy="4.5" r="2.2"/><path d="M6 17a3.5 3.5 0 1 0 0 .01M18 17a3.5 3.5 0 1 0 0 .01M6 17l5-6 3 3h4M11 11l3-3" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>',
    dh: '<path d="M12 2c1 4 6 6 6 12a6 6 0 0 1-12 0c0-3 2-4 2-7 2 1 3 3 3 5 1-2 1-6 1-10z"/>',
  };

  let catalog = null, models = {}, state = load();

  // ------------------------------------------------------------------ storage

  function blankBike() {
    return {
      id: uid(), name: "", style: "trail", frameType: "fullSuspension", color: null,
      rider: { weightLb: 0, heightIn: 0, frameSize: "M", skill: "intermediate", position: "neutral" },
      fork: null, shock: null, forkRan: { clicks: {} }, shockRan: { clicks: {} },
      setup: { eBike: false, wheel: "29", tireWidth: "standard", inserts: false, frameRearSag: null, frameProgression: "average", forkHours: 0, shockHours: 0 },
      ride: { terrain: "mixed", condition: "dry", temperatureF: 70, pack: "none", feel: "balanced", priority: "balanced" },
    };
  }
  function load() {
    let s = null;
    try { s = JSON.parse(localStorage.getItem(STORE_KEY) || "null"); } catch (e) { s = null; }
    return Object.assign({ bikes: [], selectedBikeID: null, history: [], useKilograms: false, appearance: "system",
      tab: "rack", tuneEnd: "fork", checklist: { date: "", done: [] } }, s || {});
  }
  function save() {
    try { localStorage.setItem(STORE_KEY, JSON.stringify(state)); }
    catch (e) { toast("Couldn't save: this browser's storage is full or turned off."); }
  }
  function uid() { return (crypto.randomUUID ? crypto.randomUUID() : Date.now().toString(36) + Math.random().toString(36).slice(2)); }

  // ------------------------------------------------------------------ helpers

  const $ = (sel, root = document) => root.querySelector(sel);
  const esc = (s) => String(s == null ? "" : s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const selected = () => state.bikes.find((b) => b.id === state.selectedBikeID) || state.bikes[0] || null;
  const variantOf = (bike) => Math.max(0, state.bikes.findIndex((b) => b.id === bike.id)) % 6;
  const paintOf = (bike) => bike.color || B.DEFAULT_PAINT[variantOf(bike)];
  const isDark = () => document.documentElement.dataset.theme === "dark"
    || (document.documentElement.dataset.theme !== "light" && matchMedia("(prefers-color-scheme: dark)").matches);
  const weightText = (lb) => state.useKilograms ? `${Math.round(lb / 2.20462)} kg` : `${Math.round(lb)} lb`;
  const heightText = (inch) => { const t = Math.round(inch); return `${Math.floor(t / 12)}′${t % 12}″`; };
  const ends = (bike) => [bike.fork && "fork", bike.shock && "shock"].filter(Boolean);
  const modelFor = (bike, end) => { const s = bike[end]; return s ? models[s.modelID] : null; };
  const ranFor = (bike, end) => bike[end === "fork" ? "forkRan" : "shockRan"] || { clicks: {} };
  const hardtail = (bike) => bike.frameType === "hardtail";
  const shockSpring = (bike) => { const m = modelFor(bike, "shock"); return m ? m.spring : null; };
  const brands = (kind) => [...new Set(catalog.models.filter((m) => m.kind === kind).map((m) => m.brand))];
  const mono = (brand) => MONOGRAMS[brand] || brand.slice(0, 2).toUpperCase();

  function rec(bike, end) {
    const slot = bike[end], m = modelFor(bike, end);
    if (!slot || !m) return null;
    return E.calculate(m, E.riderInput({
      weightKg: bike.rider.weightLb / 2.20462, heightCm: bike.rider.heightIn * 2.54, frameSize: bike.rider.frameSize, style: bike.style,
      travelMm: slot.travelMm, strokeMm: slot.strokeMm || 0, skill: bike.rider.skill, position: bike.rider.position,
      terrain: bike.ride.terrain, condition: bike.ride.condition, temperatureF: bike.ride.temperatureF, pack: bike.ride.pack,
      feel: bike.ride.feel, priority: bike.ride.priority, eBike: bike.setup.eBike, wheel: bike.setup.wheel, tireWidth: bike.setup.tireWidth,
      inserts: bike.setup.inserts, frameRearSag: bike.setup.frameRearSag, frameProgression: bike.setup.frameProgression,
      serviceHours: end === "fork" ? bike.setup.forkHours : bike.setup.shockHours,
    }));
  }
  function setRan(bike, end, ran) { bike[end === "fork" ? "forkRan" : "shockRan"] = ran; save(); }
  function cleanRan(ran) { return { springValue: ran.springValue ?? null, tokens: ran.tokens ?? null, clicks: Object.assign({}, ran.clicks || {}) }; }

  let toastTimer = null;
  function toast(msg) {
    const t = $("#toast"); t.textContent = msg; t.hidden = false;
    clearTimeout(toastTimer); toastTimer = setTimeout(() => { t.hidden = true; }, 2400);
  }
  function applyTheme() {
    const root = document.documentElement;
    if (state.appearance === "system") delete root.dataset.theme; else root.dataset.theme = state.appearance;
    $('meta[name="theme-color"]').setAttribute("content", isDark() ? "#060607" : "#ECEDEF");
  }
  function greeting() {
    const h = new Date().getHours();
    if (h >= 4 && h < 11) return "Dawn patrol. Let's get rowdy.";
    if (h >= 11 && h < 17) return "Trails are calling. Send it.";
    if (h >= 17 && h < 21) return "Golden-hour laps. Drop in.";
    return "Night laps. Lights on, full send.";
  }
  const seg = (name, options, value) =>
    `<div class="seg" role="group">${options.map(([v, t]) => `<button type="button" data-seg="${name}" data-value="${esc(v)}" aria-pressed="${String(v) === String(value)}">${esc(t)}</button>`).join("")}</div>`;
  const step = (n, title, sub) => `<div class="step"><span class="n">${String(n).padStart(2, "0")}</span><div><b>${title}</b><span>${sub}</span></div></div>`;
  const toolBtn = (action, icon, color, title, sub) =>
    `<button class="glass tool" data-action="${action}"><span class="ico" style="color:${color};background:color-mix(in srgb, ${color} 16%, transparent)">${icon}</span><span class="grow"><b>${title}</b><span>${sub}</span></span></button>`;

  // ------------------------------------------------------------------ render

  function render() {
    applyTheme();
    document.querySelectorAll(".tabbar button").forEach((b) => b.setAttribute("aria-current", b.dataset.tab === state.tab ? "page" : "false"));
    const v = $("#view");
    v.innerHTML = state.tab === "tune" ? tuneView() : state.tab === "history" ? historyView() : state.tab === "settings" ? settingsView() : rackView();
  }
  function go(tab, end) {
    if (end) state.tuneEnd = end;
    state.tab = tab; save(); render(); window.scrollTo(0, 0);
  }

  // ---- My Bike Rack
  function rackView() {
    const bike = selected();
    let h = `<header class="row between" style="align-items:flex-end">
      <div class="grow"><div class="greet">${greeting()}</div>
        <div class="row" style="gap:8px"><h1 class="title">My Bike Rack</h1><button class="help" data-action="help" aria-label="How to dial it in">?</button></div></div>
      <button class="icon-btn" data-action="add-bike" aria-label="Add bike"><svg viewBox="0 0 16 16"><path d="M8 2v12M2 8h12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg></button></header>`;
    if (!bike) {
      return h + `<section class="glass empty"><h2>Build your bike rack</h2>
        <p>Add your bike once: fork, shock and rider. Then pick today's riding and get both ends dialed from the maker's own charts.</p>
        <button class="btn primary" data-action="add-bike">Add bike</button></section>` + trustNote();
    }
    const subtitle = [`Size ${bike.rider.frameSize}`, bike.fork && `F: ${Math.round(bike.fork.travelMm)} mm`,
      hardtail(bike) ? "Hardtail" : bike.shock && `R: ${Math.round(bike.shock.travelMm)} mm`, weightText(bike.rider.weightLb),
      bike.setup.eBike && "E-bike"].filter(Boolean).join(" · ");
    h += step(1, "Today's ride", "Riding style and conditions");
    h += `<div class="styles" role="group" aria-label="Riding style">${E.STYLES.map((s) =>
      `<button data-style="${s}" aria-pressed="${bike.style === s}"><svg viewBox="0 0 24 24">${STYLE_ICONS[s]}</svg><b>${E.STYLE_SHORT[s]}</b><i></i></button>`).join("")}</div>`;
    h += `<button class="glass row pad" data-action="conditions" style="border-radius:16px;text-align:left;width:100%;padding:10px 13px">
      <svg width="18" height="16" viewBox="0 0 24 22" aria-hidden="true"><path d="M5 5 C 16 5, 6 17, 19 17" fill="none" stroke="currentColor" stroke-width="2" stroke-dasharray="3 2.4"/><circle cx="5" cy="5" r="3.2" fill="#FF7A1A"/><circle cx="19" cy="17" r="3.2" fill="#FF7A1A"/></svg>
      <span class="grow"><b class="c" style="font-size:14px;letter-spacing:.1em;display:block">Riding conditions</b><span class="small muted">${esc(rideSummary(bike.ride))}</span></span><span class="muted">›</span></button>`;
    h += step(2, "Your bike", "Tap F or R to dial it in · tap the bike to bounce it");
    h += `<section class="stack" style="gap:6px">
      <div class="row between" style="align-items:flex-start"><div class="grow">
        <div class="lbl acc">${E.STYLE_LABELS[bike.style]}</div>
        <div class="hero-name">${esc(bike.name)}</div><div class="small muted">${esc(subtitle)}</div></div>
        <button class="btn" data-action="edit-bike" data-id="${bike.id}">Edit</button></div>
      <div class="bike-wrap" id="hero-bike">${B.bikeSVG({ variant: variantOf(bike), hardtail: hardtail(bike), paint: paintOf(bike),
        shockSpring: shockSpring(bike), hasFork: !!bike.fork, hasShock: !!bike.shock, dark: isDark() })}</div>
      <div class="hair" style="margin:4px 0 8px"></div>
      <div class="ends">${hardtail(bike) ? hardtailCard() : endCard(bike, "shock")}${endCard(bike, "fork")}</div></section>`;
    h += toolBtn("checklist", "✓", "var(--go)", "Pre-ride check", "Pressures, sag, bolts, brakes — 60 seconds");
    h += trustNote();
    const others = state.bikes.filter((b) => b.id !== bike.id);
    if (others.length) {
      h += step("··", "Other bikes", "Tap to switch") + `<div class="stack" style="gap:8px">${others.map((o) => {
        const end = o.fork ? "fork" : "shock", m = modelFor(o, end), r = rec(o, end);
        const sub = [m && `${m.brand} ${m.name}`, r && `${(ranFor(o, end).springValue ?? r.springValue)} ${r.headlineUnit}`].filter(Boolean).join(" · ");
        return `<button class="glass list-row" data-action="select-bike" data-id="${o.id}"><span class="thumb">${B.bikeSVG({ variant: variantOf(o), hardtail: hardtail(o),
          paint: paintOf(o), shockSpring: shockSpring(o), hasFork: !!o.fork, hasShock: !!o.shock, badges: false, dark: isDark() })}</span>
          <span class="grow"><b>${esc(o.name)}</b><span class="small muted">${esc(sub)}</span></span><span class="muted">›</span></button>`;
      }).join("")}</div>`;
    }
    return h;
  }
  function rideSummary(r) {
    const p = [E.TERRAIN_TITLES[r.terrain], r.condition === "wet" ? "Wet" : "Dry", `${Math.round(r.temperatureF)}°F`];
    if (r.pack !== "none") p.push(E.PACK_TITLES[r.pack]);
    if (r.feel !== "balanced") p.push(r.feel[0].toUpperCase() + r.feel.slice(1));
    if (r.priority !== "balanced") p.push(E.PRIORITY_TITLES[r.priority]);
    return p.join(" · ");
  }
  function endCard(bike, end) {
    const m = modelFor(bike, end), r = rec(bike, end);
    if (!m || !r) return `<button class="glass end add" data-action="edit-bike" data-id="${bike.id}">＋ ${end === "fork" ? "Add fork" : "Add rear shock"}</button>`;
    const ran = ranFor(bike, end), shown = ran.springValue ?? r.springValue;
    const parts = [`Sag ${r.sagPercent}%`];
    const t = ran.tokens ?? r.tokens; if (t != null) parts.push(`Tok ${t}`);
    if (E.differences(r, ran).length) parts.push("custom");
    const front = end === "fork";
    return `<button class="glass end${front ? " glow-acc" : ""}" data-action="tune" data-end="${end}">
      <span class="lbl" style="${front ? "color:var(--accent)" : ""}">${front ? "Front" : "Rear"} · ${esc(m.name)}</span>
      <span class="big">${shown}</span><span class="unit">${r.headlineUnit.toUpperCase()}</span>
      <span class="sub" style="display:block">${parts.join(" · ")}</span></button>`;
  }
  const hardtailCard = () => `<div class="glass end" aria-label="Hardtail, no rear shock to set up"><span class="lbl">Rear · Hardtail</span>
    <span class="big muted" style="font-size:36px">RIGID</span><span class="sub faint" style="display:block">No shock to set</span></div>`;
  const trustNote = () => `<section class="glass glow-go pad row" style="align-items:flex-start;gap:12px">
    <span style="color:var(--go);font-size:20px" aria-hidden="true">✔</span><div class="grow">
    <b class="c" style="font-size:15px;letter-spacing:.06em">Built on the manufacturers' numbers</b>
    <p class="small muted" style="margin:4px 0 0">Air pressure, sag, volume spacers and damping clicks come from each maker's official setup charts for your weight. Set your riding style and riding conditions to fine-tune that baseline. Models with no published chart are clearly marked as estimates.</p></div></section>`;

  // ---- Tune
  function tuneView() {
    const bike = selected();
    if (!bike || !ends(bike).length) {
      return `<h1 class="title">Tune</h1><section class="glass empty"><h2>No bike to tune yet</h2><p>Add a bike in My Bike Rack with its fork and/or shock, then come back here.</p>
        <button class="btn primary" data-action="go-rack">Go to Bike Rack</button></section>`;
    }
    const list = ends(bike), end = list.includes(state.tuneEnd) ? state.tuneEnd : list[0];
    const m = modelFor(bike, end), r = rec(bike, end), ran = ranFor(bike, end), isFork = end === "fork";
    let h = `<div class="endtabs">${list.map((e) => `<button data-action="end" data-end="${e}" aria-pressed="${e === end}">${e === "fork" ? "Front" : "Rear"}</button>`).join("")}
      ${state.bikes.length > 1 ? `<select class="bike-select" id="bike-select" aria-label="Bike">${state.bikes.map((b) => `<option value="${b.id}"${b.id === bike.id ? " selected" : ""}>${esc(b.name)}</option>`).join("")}</select>`
        : `<span class="bike-select">${esc(bike.name)}</span>`}</div>`;
    const url = E.specsUrl(catalog, m);
    h += `<div class="row" style="gap:12px"><span class="mono" aria-hidden="true">${esc(mono(m.brand))}</span><div class="grow">
      <div class="lbl">${esc(m.brand)} · ${esc(m.damper)}</div>
      <a class="model-name" href="${esc(url)}" target="_blank" rel="noopener">${esc(m.name)} <span class="muted" style="font-size:15px">↗</span></a>
      <div class="chips"><span class="chip-tag" style="color:var(--gold);background:color-mix(in srgb,var(--gold) 15%,transparent)">${m.spring === "air" ? "Air" : "Coil"} spring</span>
      <span class="chip-tag" style="color:var(--go);background:color-mix(in srgb,var(--go) 15%,transparent)">${E.STYLE_LABELS[bike.style]}</span></div></div></div>`;
    const qColor = r.quality === "manufacturer" ? "var(--go)" : r.quality === "partial" ? "var(--gold)" : "var(--muted)";
    const qSub = r.quality === "manufacturer" ? (r.sourceTitle || "") : r.quality === "partial" ? `${r.sourceTitle || "Maker's guide"} · rest estimated` : "No published setup chart for this model";
    const srcInner = `<span class="dot" style="background:${qColor}"></span><span class="grow"><b class="small" style="color:${qColor}">${E.QUALITY_TITLES[r.quality]}</b><span class="tiny muted" style="display:block">${esc(qSub)}</span></span>`;
    h += r.sourceUrl ? `<a class="glass source" href="${esc(r.sourceUrl)}" target="_blank" rel="noopener" style="border-color:color-mix(in srgb, ${qColor} 45%, var(--stroke))">${srcInner}<span class="muted">↗</span></a>`
      : `<div class="glass source">${srcInner}</div>`;
    h += dial(r, ran);
    if (r.trailPsi != null && r.trailPsi !== r.springValue) {
      h += info("🌡", "var(--sky)", `Pump ${r.springValue} psi indoors → ${r.trailPsi} psi on the trail`,
        `Air loses pressure as it cools (${Math.round(bike.ride.temperatureF)}°F today). Pumping at the trailhead? Set ${r.trailPsi} psi.`);
    }
    if (!r.isAir && !isFork && bike.shock) {
      const opts = E.coilOptions(r.springValue, r.sagPercent);
      h += `<section class="glass pad stack" style="gap:8px;border-color:color-mix(in srgb,var(--gold) 40%,var(--stroke))"><div class="lbl" style="color:var(--gold)">Coil springs · buy ${esc(E.coilLabel(r.springValue, bike.shock.strokeMm))}</div>
        <div class="seg">${opts.map((o) => `<span class="btn" style="flex:1;text-align:center;${o.isRecommended ? "background:var(--gold);color:#000;border-color:var(--gold)" : ""}"><b>${o.rate}</b><br><span class="tiny">${o.sagPercent.toFixed(0)}% sag</span></span>`).join("")}</div>
        <p class="tiny muted" style="margin:0">Stock springs come in 25 lb/in steps. Pick the one closest to your target sag.</p></section>`;
    }
    const sagTop = clamp01(r.sagPercent / 100 * 2.4) * 70;
    h += `<section class="glass pad row" style="gap:14px;align-items:center"><div class="stanchion" aria-hidden="true"><i></i><em style="top:${sagTop.toFixed(0)}px"></em></div>
      <div class="grow"><div class="row between"><span class="lbl">Sag · O-ring check</span><button class="help" data-action="sag-help" aria-label="How to check sag">?</button></div>
      <div class="row" style="gap:8px;align-items:baseline;flex-wrap:wrap"><span class="c" style="font-size:30px;font-weight:700">${r.sagPercent}%</span>
      <span class="c muted" style="font-size:15px;font-weight:600">${fixed1(r.sagMm)} MM</span>
      ${r.sagMin != null && r.sagMax != null && r.sagMin !== r.sagMax ? `<span class="tiny" style="color:var(--go);font-weight:600">(maker: ${r.sagMin}–${r.sagMax}%)</span>` : ""}</div>
      <p class="tiny muted" style="margin:0">${isFork ? "Push the O-ring down to the seal, sit on the bike in attack position, step off and measure." : "Push the O-ring to the seal, sit in attack position, step off gently and measure on the shaft."}</p></div></section>`;
    h += `<div class="tools">${toolBtn("sag-helper", "📏", "var(--go)", "Check my sag", "Guided + calculator")}${toolBtn("trouble", "🩺", "var(--accent)", "Feels off?", "Fix by symptom")}</div>`;
    const diffs = E.differences(r, ran);
    if (r.clicks.length || r.tokens != null) {
      h += `<div class="hair"></div><div class="row"><span class="lbl">Damping · drag to match</span><button class="help" data-action="damping-help" aria-label="How to use the damping sliders">?</button>
        <span class="grow"></span>${diffs.length ? '<button class="link" data-action="reset-ran">Reset</button>' : ""}</div>
        <section class="glass sliders">${r.clicks.map((c) => slider(c.key, c.short, ran.clicks[c.key] ?? c.value, c.value, c.of, c.direction.toUpperCase(), c.isRebound ? "var(--sky)" : "var(--accent)", c.label)).join("")}
        ${r.tokens != null && r.tokenMax != null ? slider("tokens", "TOK", ran.tokens ?? r.tokens, r.tokens, r.tokenMax, `/ ${r.tokenMax}`, "var(--gold)", "Volume spacers") : ""}</section>`;
    }
    const steps = E.setupSteps(r, isFork, ran);
    h += `<details class="glass pad card" open><summary class="row"><span style="color:var(--accent)" aria-hidden="true">☰</span><span class="grow"><b class="c" style="font-size:15px;letter-spacing:.14em;display:block">Step by step</b>
      <span class="small muted">The same setup in plain words — no chart reading</span></span><span class="muted">⌄</span></summary>
      <div class="steps"><ol>${steps.map((s, i) => `<li><span class="no">${String(i + 1).padStart(2, "0")}</span><div><b>${esc(s.title)}</b><p>${esc(s.text)}</p></div></li>`).join("")}</ol>
      <p class="tiny muted" style="margin:0">Count clicks gently and never force a knob past its stop. Knob colours and spots vary by model; your owner's manual has the exact layout.</p></div></details>`;
    const find = (label) => r.settings.find((s) => s.label === label);
    const lock = find("Lockout / climb"), tire = find("Tire pressure"), service = find("Service");
    if (lock) h += info(lock.value === "None" ? "🔓" : "🔒", "var(--teal)", lock.value, lock.detail);
    if (tire) h += info("◎", "var(--gold)", `Tires · ${tire.value}`, tire.detail);
    if (service) h += info("🔧", r.serviceDue ? "var(--warn)" : "var(--muted)", `Service · ${service.value}`, service.detail);
    h += r.warnings.map((w) => `<div class="warn">⚠ ${esc(w)}</div>`).join("");
    h += `<details class="glass pad card"><summary class="lbl" style="color:var(--go)">Setup notes ⌄</summary>
      <ul class="notes">${r.tips.map((t) => `<li>${esc(t)}</li>`).join("")}</ul>
      <ul class="notes">${r.settings.map((s) => `<li><b style="color:var(--fg)">${esc(s.label)}: ${esc(s.value)}.</b> ${esc(s.detail)}</li>`).join("")}</ul>
      <p class="tiny muted">${esc(catalog.disclaimer)}</p></details>`;
    h += `<div class="actions"><button class="btn" data-action="share">Share</button><button class="btn" data-action="print">Print</button>
      <button class="btn primary" data-action="save-history">Save to History</button></div>`;
    return h;
  }
  const clamp01 = (v) => Math.max(0, Math.min(1, v));
  function fixed1(v) { return (Math.round(v * 10) / 10).toFixed(1); }
  function info(icon, color, title, detail) {
    return `<section class="glass info" style="border-color:color-mix(in srgb, ${color} 40%, var(--stroke))"><span style="color:${color};width:20px;text-align:center" aria-hidden="true">${icon}</span>
      <div class="grow"><b>${esc(title)}</b><p>${esc(detail)}</p></div></section>`;
  }
  function dial(r, ran) {
    const size = 214, rad = size / 2 - 4, c = size / 2;
    const value = ran.springValue ?? r.springValue;
    const max = r.isAir ? (r.maxPsi || 150) : r.springValue * 1.6;
    const frac = (v) => Math.max(0, Math.min(1, v / Math.max(max, 1)));
    let t = "";
    for (let i = 0; i <= 60; i++) {
      const f = i / 60, a = (135 + 270 * f) * Math.PI / 180, maj = i % 5 === 0, inner = rad - (maj ? 16 : 9);
      const col = f <= frac(value) + 1e-4 ? "var(--accent)" : "var(--faint)";
      t += `<line x1="${(c + inner * Math.cos(a)).toFixed(1)}" y1="${(c + inner * Math.sin(a)).toFixed(1)}" x2="${(c + rad * Math.cos(a)).toFixed(1)}" y2="${(c + rad * Math.sin(a)).toFixed(1)}" style="stroke:${col};opacity:${f <= frac(value) + 1e-4 ? 1 : .5}" stroke-width="${maj ? 2.4 : 1.4}"/>`;
    }
    const ra = (135 + 270 * frac(r.springValue)) * Math.PI / 180;
    t += `<circle cx="${(c + (rad + 1) * Math.cos(ra)).toFixed(1)}" cy="${(c + (rad + 1) * Math.sin(ra)).toFixed(1)}" r="4" style="fill:var(--fg)"/>`;
    return `<div class="dial"><button class="nudge" data-action="spring" data-dir="-1" aria-label="Decrease">−</button>
      <div class="dial-face" role="group" aria-label="${r.isAir ? "Air pressure" : "Spring rate"}: ${value} ${r.headlineUnit}, recommended ${r.springValue}">
      <svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" aria-hidden="true">${t}</svg><div class="core"></div>
      <div class="read"><span class="num">${value}</span><span class="lbl">${r.isAir ? "PSI · PUMP" : "LB/IN"}</span>
      ${value !== r.springValue ? `<button class="link tiny" data-action="spring-reset" style="margin-top:4px">Rec. ${r.springValue}</button>` : ""}</div></div>
      <button class="nudge" data-action="spring" data-dir="1" aria-label="Increase">+</button></div>`;
  }
  function slider(key, short, value, recd, of, unit, color, label) {
    const pct = of > 0 ? value / of * 100 : 0, rp = of > 0 ? recd / of * 100 : 0;
    const tick = encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="100%" height="9">${Array.from({ length: of + 1 }, (_, k) =>
      `<rect x="${(k / of * 100).toFixed(2)}%" width="1" height="${k % 4 === 0 ? 9 : 6}" fill="#8E929A" opacity="${k % 4 === 0 ? .7 : .45}"/>`).join("")}</svg>`);
    return `<div class="slider"><span class="k" style="color:${color}">${short}</span>
      <div class="track"><div class="ticks" style="background-image:url(&quot;data:image/svg+xml,${tick}&quot;)"></div>
      <span class="rec" style="left:calc(8px + (100% - 16px) * ${(rp / 100).toFixed(4)})"></span>
      <input type="range" id="sl-${key}" min="0" max="${of}" step="1" value="${value}" data-key="${key}" data-rec="${recd}" aria-label="${esc(label)}"
        aria-valuetext="${value}, recommended ${recd}" style="--pct:${pct.toFixed(1)}%;--fill:${color}"></div>
      <span class="v" id="v-${key}" style="${value !== recd ? `color:${color}` : ""}">${value}<small> ${unit}</small></span></div>`;
  }

  // ---- History
  function historyView() {
    let h = `<h1 class="title">History</h1>`;
    if (!state.history.length) {
      return h + `<section class="glass empty"><h2>No saved setups yet</h2><p>On Tune, set the dial and sliders to what you actually ran, then tap Save to History with a note.</p></section>`;
    }
    h += [...state.history].reverse().map((e) => `<article class="glass hist">
      <div class="row between"><b>${esc(e.bikeName)} · ${e.end === "fork" ? "Front" : "Rear"}</b><span class="tiny muted m">${new Date(e.date).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" })}</span></div>
      <div class="small muted">${esc(e.brand)} ${esc(e.modelName)} · ${E.STYLE_LABELS[e.style] || ""}</div>
      ${e.note ? `<div>“${esc(e.note)}”</div>` : ""}
      <div class="small">${e.ran.length ? e.ran.map(esc).join("<br>") : "Ran as recommended."}</div>
      <details><summary class="tiny muted">Recommended at the time</summary><div class="tiny muted">${e.recommended.map(esc).join("<br>")}</div></details>
      <div><button class="btn danger" data-action="delete-history" data-id="${e.id}">Delete</button></div></article>`).join("");
    return h;
  }

  // ---- Settings
  function settingsView() {
    return `<h1 class="title">Settings</h1>
      <section class="glass pad stack"><span class="lbl">Appearance</span>${seg("appearance", [["system", "Automatic"], ["light", "Light"], ["dark", "Dark"]], state.appearance)}</section>
      <section class="glass pad stack"><span class="lbl">Units</span>${seg("units", [["lb", "lb"], ["kg", "kg"]], state.useKilograms ? "kg" : "lb")}</section>
      <section class="glass pad stack"><span class="lbl">Your data</span>
        <p class="small muted" style="margin:0">Your bikes and history are saved in this browser on this device only. Make a backup to move them to another phone or browser.</p>
        <div class="actions"><button class="btn" data-action="export">Download backup</button><label class="btn" for="import-file">Restore backup</label>
        <input type="file" id="import-file" accept="application/json,.json" hidden></div>
        <button class="btn danger" data-action="erase">Erase all bikes and history</button></section>
      <section class="glass pad stack"><span class="lbl">Install</span>
        <p class="small muted" style="margin:0">Add Suspension Tuner to your home screen to use it like an app, even with no signal at the trailhead. On iPhone: Share → Add to Home Screen. On Android: menu → Install app.</p></section>
      <section class="glass pad stack"><span class="lbl">Legal</span>
        <div class="actions"><button class="btn" data-action="disclaimer">Disclaimer</button><a class="btn" href="${PRIVACY_URL}" target="_blank" rel="noopener" style="text-decoration:none;color:inherit">Privacy policy</a></div></section>
      <p class="tiny faint" style="text-align:center">Suspension Tuner for the web · ${catalog.models.length} forks and shocks · © 2026 Whole Stack Solutions</p>`;
  }

  // ------------------------------------------------------------------ sheets

  const sheet = $("#sheet");
  let sheetState = null;
  function openSheet(title, body, opts = {}) {
    sheetState = opts;
    sheet.querySelector(".sheet-inner").innerHTML = `<div class="sheet-head">${opts.cancel ? '<button data-sheet="cancel">Cancel</button>' : "<span></span>"}
      <h2 id="sheet-title">${esc(title)}</h2>${opts.save ? `<button class="save" data-sheet="save">${opts.save}</button>` : '<button data-sheet="close">Done</button>'}</div><div class="sheet-body">${body}</div>`;
    if (!sheet.open) sheet.showModal();
  }
  function closeSheet() { if (sheet.open) sheet.close(); sheetState = null; render(); }

  function helpSheet() {
    openSheet("How to dial it in", `<div class="steps"><ol>${[
      ["Pick your riding style", "XC, Trail, Enduro, Bike Park or Downhill. Trail uses the maker's numbers as is; the others fine-tune sag, compression, rebound and spacers."],
      ["Set riding conditions", "Terrain, wet or dry, temperature, pack, firm or plush feel, and climbing or descending priority."],
      ["Set up your bike", "Tap + or Edit: your weight and height, frame size, fork and shock, travel, hardtail or full suspension, colour, e-bike and tires."],
      ["Dial it in", "Tap F or R on the bike to open Tune: pressure, sag and clicks from the maker's chart. Set your bike to match and check sag."],
      ["Log what you ran", "Drag the sliders to what you actually set and Save to History, so next ride you know what worked."],
    ].map(([t, x], i) => `<li><span class="no">${String(i + 1).padStart(2, "0")}</span><div><b>${t}</b><p>${x}</p></div></li>`).join("")}</ol></div>`);
  }
  function textSheet(title, paragraphs) { openSheet(title, `<div class="stack legal">${paragraphs.map((p) => `<p>${p}</p>`).join("")}</div>`); }
  function disclaimerSheet() {
    openSheet("Disclaimer", `<div class="stack legal">${[
      ["Starting points, not guarantees", "Recommendations come from manufacturers' published setup charts and specifications where available, and from calculated estimates where they aren't. They are starting points, not a substitute for your product's owner's manual, the manufacturer's instructions or a qualified bicycle mechanic."],
      ["Estimates are labelled", "Every setup shows where its numbers come from. \"Manufacturer chart\" means the maker's published guide. \"Partly manufacturer\" means some values come from the guide and the rest are calculated. \"Estimate\" means the maker publishes no setup chart for that model. Treat estimates with extra care and confirm them against your manual and your own sag check."],
      ["Never exceed the product's limits", "Always follow the maximum air pressure, volume spacer count, spring rate and preload limits printed on your fork or shock or in its manual."],
      ["Check before you ride", "Check sag and every setting yourself and test changes gradually in a safe, controlled area before riding hard."],
      ["Service and repairs", "Service intervals shown are general guidance. Have suspension serviced by a qualified technician."],
      ["Ride at your own risk", "Mountain biking is dangerous and can lead to serious injury or death. You are responsible for your bike, your equipment and how you ride. To the fullest extent permitted by law, Whole Stack Solutions is not liable for any injury, loss or damage arising from the use of this app or its recommendations."],
      ["Trademarks", "Brand and model names are trademarks of their respective owners. Suspension Tuner is not affiliated with, sponsored by or endorsed by any suspension manufacturer."],
    ].map(([t, x]) => `<div><h3>${t}</h3><p>${x}</p></div>`).join("")}</div>`);
  }

  // ---- Riding conditions
  function conditionsSheet() {
    const bike = selected(); if (!bike) return;
    const r = bike.ride;
    openSheet("Riding conditions", `
      <div class="field"><span>Terrain</span>${seg("ride.terrain", [["mixed", "Mixed"], ["rough", "Rocky / rooty"], ["flow", "Flow / jumps"]], r.terrain)}</div>
      <div class="field"><span>Trail</span>${seg("ride.condition", [["dry", "Dry"], ["wet", "Wet"]], r.condition)}</div>
      <div class="field"><span>Temperature</span><div class="inline"><button class="nudge" data-action="temp" data-dir="-5" aria-label="Colder">−</button>
        <b class="c" style="font-size:26px;min-width:80px;text-align:center" id="temp-v">${Math.round(r.temperatureF)}°F</b><button class="nudge" data-action="temp" data-dir="5" aria-label="Warmer">+</button></div></div>
      <div class="field"><span>Pack</span>${seg("ride.pack", Object.entries(E.PACK_TITLES), r.pack)}</div>
      <div class="field"><span>Feel — where in the sag range</span>${seg("ride.feel", [["firm", "Firm"], ["balanced", "Balanced"], ["plush", "Plush"]], r.feel)}</div>
      <div class="field"><span>Priority</span>${seg("ride.priority", Object.entries(E.PRIORITY_TITLES), r.priority)}</div>
      <p class="tiny muted">These tune the maker's numbers for today's ride on ${esc(bike.name)}. Leave everything at the defaults for the maker's chart as is.</p>`, { kind: "conditions" });
  }

  // ---- Pre-ride checklist
  function checklistSheet() {
    const bike = selected(); if (!bike) return;
    const today = new Date().toDateString();
    if (state.checklist.date !== today) state.checklist = { date: today, done: [] };
    const items = E.checklist(rec(bike, "fork"), hardtail(bike) ? null : rec(bike, "shock"));
    openSheet("Pre-ride check", `<p class="small muted" style="margin:0">${esc(bike.name)} · ticks reset every day.</p>
      ${items.map((i) => { const done = state.checklist.done.includes(i.id); return `<label class="glass check${done ? " done" : ""}"><input type="checkbox" data-check="${i.id}"${done ? " checked" : ""}>
      <span><b>${esc(i.title)}</b><span>${esc(i.detail)}</span></span></label>`; }).join("")}`, { kind: "checklist" });
  }

  // ---- Sag helper
  function sagHelperSheet() {
    const bike = selected(); if (!bike) return;
    const end = currentEnd(bike), r = rec(bike, end), isFork = end === "fork";
    const length = isFork ? bike.fork.travelMm : (bike.shock.strokeMm || 0);
    openSheet("Check my sag", `
      <div class="steps"><ol>${[
        ["Set the pressure", `${r.isAir ? `Pump to ${ranFor(bike, end).springValue ?? r.springValue} psi` : `Fit the ${r.springValue} lb/in spring`} and cycle the ${isFork ? "fork" : "shock"} a few times.`],
        ["Push the O-ring", `Slide the O-ring down to the ${isFork ? "dust seal" : "air can seal"}.`],
        ["Get on, hold still", "Lean on a wall, stand in attack position with your riding kit on, then sit for 10 seconds."],
        ["Step off gently", "Without bouncing, then measure from the seal to the O-ring."],
      ].map(([t, x], i) => `<li><span class="no">${String(i + 1).padStart(2, "0")}</span><div><b>${t}</b><p>${x}</p></div></li>`).join("")}</ol></div>
      <div class="glass pad stack" style="align-items:center"><div class="countdown" id="cd">10</div><button class="btn" data-action="countdown">Start 10-second hold</button></div>
      <div class="field"><label for="sag-mm">Measured (mm)</label><div class="inline"><input class="input" id="sag-mm" type="number" inputmode="decimal" min="0" step="0.5" placeholder="${fixed1(r.sagMm)}">
        <span class="muted small">of ${length} mm ${isFork ? "travel" : "stroke"} · target ${r.sagPercent}% (${fixed1(r.sagMm)} mm)</span></div></div>
      <div id="sag-result"></div>`, { kind: "sag", end });
  }
  function sagResult() {
    const bike = selected(), end = sheetState.end, r = rec(bike, end), isFork = end === "fork";
    const mm = parseFloat(($("#sag-mm").value || "").replace(",", "."));
    const length = isFork ? bike.fork.travelMm : (bike.shock.strokeMm || 0);
    const spring = ranFor(bike, end).springValue ?? r.springValue;
    const res = E.sagCheck(isNaN(mm) ? 0 : mm, length, r, spring);
    $("#sag-result").innerHTML = `<div class="result ${res.status === "good" ? "good" : "off"}">${esc(res.message)}</div>
      ${res.suggestedSpring != null ? `<button class="btn primary" data-action="use-spring" data-value="${res.suggestedSpring}">Set dial to ${res.suggestedSpring} ${r.headlineUnit}</button>` : ""}`;
  }

  // ---- Troubleshooter
  function troubleSheet(symptom) {
    const bike = selected(); if (!bike) return;
    const end = currentEnd(bike), r = rec(bike, end), ran = ranFor(bike, end);
    const list = E.SYMPTOMS.filter(([k]) => E.symptomApplies(k, end));
    let body = `<p class="small muted" style="margin:0">What is the ${end === "fork" ? "fork" : "shock"} doing? Fixes start from what you're running now, best first. Try one, ride the same section, then the next.</p>
      <div class="symptoms">${list.map(([k, t]) => `<button data-symptom="${k}" aria-pressed="${k === symptom}">${t}</button>`).join("")}</div>`;
    if (symptom) {
      const fixes = E.troubleshoot(symptom, r, ran, end);
      body += `<div class="lbl">Try in this order</div>${fixes.map((f, i) => `<article class="glass fix"><b>${i + 1}. ${esc(f.title)}</b><span class="small muted">${esc(f.why)}</span>
        ${f.change.type !== "advice" ? `<div><button class="btn" data-action="apply-fix" data-fix="${i}">Apply to my setup</button></div>` : ""}</article>`).join("")}`;
    }
    openSheet("Feels off?", body, { kind: "trouble", end, symptom });
  }

  // ---- Bike editor
  let draft = null;
  function editBike(bike) {
    const isNew = !state.bikes.some((b) => b.id === bike.id);
    const w = bike.rider.weightLb;
    const h = Math.round(bike.rider.heightIn);
    const forkSlot = bike.fork, shockSlot = bike.shock;
    draft = {
      isNew, id: bike.id, name: bike.name,
      weight: w > 0 ? String(Math.round(state.useKilograms ? w / 2.20462 : w)) : "", feet: h > 0 ? String(Math.floor(h / 12)) : "", inches: h > 0 ? String(h % 12) : "",
      frameSize: bike.rider.frameSize, style: bike.style, skill: bike.rider.skill, position: bike.rider.position,
      setup: Object.assign({}, bike.setup), frameType: bike.frameType || "fullSuspension",
      color: bike.color || B.DEFAULT_PAINT[isNew ? state.bikes.length % 6 : variantOf(bike)],
      variant: isNew ? state.bikes.length % 6 : variantOf(bike),
      fork: { on: !!forkSlot || isNew, brand: forkSlot ? (models[forkSlot.modelID] || {}).brand : null, modelID: forkSlot ? forkSlot.modelID : null, travel: forkSlot ? forkSlot.travelMm : 150 },
      shock: { brand: shockSlot ? (models[shockSlot.modelID] || {}).brand : null, modelID: shockSlot ? shockSlot.modelID : null, travel: shockSlot ? shockSlot.travelMm : 150, stroke: shockSlot ? shockSlot.strokeMm : 60 },
    };
    renderEditor();
  }
  function draftProblem() {
    const d = draft;
    if (!d.name.trim()) return "Give the bike a name.";
    const wv = parseFloat(d.weight.replace(",", "."));
    const lb = state.useKilograms ? wv * 2.20462 : wv;
    if (!(lb >= 66 && lb <= 396)) return "Enter the rider's weight.";
    const ft = parseFloat(d.feet), inch = d.inches === "" ? 0 : parseFloat(d.inches.replace(",", "."));
    const total = ft * 12 + inch;
    if (isNaN(ft) || isNaN(inch) || inch < 0 || inch >= 12 || !(total >= 48 && total <= 90)) return "Enter the rider's height in feet and inches.";
    const ht = d.frameType === "hardtail";
    if (ht && !d.fork.on) return "Add a fork — it's the only suspension on a hardtail.";
    if (d.fork.on && !d.fork.modelID) return "Choose a fork model, or switch the fork off.";
    if (!ht && !d.shock.modelID) return "Choose a rear shock model, or pick Hardtail.";
    return null;
  }
  function partEditor(kind) {
    const d = draft[kind], m = d.modelID ? models[d.modelID] : null;
    let h = `<div class="grid3" role="group" aria-label="${kind === "fork" ? "Fork" : "Shock"} brand">${brands(kind).map((b) => `<button type="button" data-brand="${kind}" data-value="${esc(b)}" aria-pressed="${d.brand === b}">${esc(b)}</button>`).join("")}</div>`;
    if (d.brand) {
      h += `<select class="input" id="model-${kind}" aria-label="Model"><option value="">Choose a model…</option>${catalog.models.filter((x) => x.kind === kind && x.brand === d.brand)
        .map((x) => `<option value="${x.id}"${x.id === d.modelID ? " selected" : ""}>${esc(x.name)}${kind === "shock" ? ` (${x.spring})` : ""}</option>`).join("")}</select>`;
    }
    if (m) {
      h += rangeField(`${kind}-travel`, kind === "fork" ? "Fork travel" : "Rear wheel travel", d.travel, m.travel.min, m.travel.max, 5, "mm");
      if (m.stroke) h += rangeField(`${kind}-stroke`, "Shock stroke", d.stroke, m.stroke.min, m.stroke.max, 2.5, "mm");
    }
    return h;
  }
  const rangeField = (id, label, v, min, max, stepv, unit) =>
    `<div class="field"><label for="${id}">${label}: <b id="${id}-v" style="color:var(--fg)">${v} ${unit}</b></label>
     <input type="range" id="${id}" min="${min}" max="${max}" step="${stepv}" value="${Math.min(max, Math.max(min, v))}" style="--pct:${((v - min) / Math.max(1, max - min) * 100).toFixed(1)}%;--fill:var(--accent)"></div>`;
  function renderEditor() {
    const d = draft, ht = d.frameType === "hardtail";
    const shockModel = d.shock.modelID ? models[d.shock.modelID] : null;
    const problem = draftProblem();
    const body = `
      <section class="glass pad stack"><span class="lbl acc">Bike</span>
        <input class="input" id="ed-name" placeholder="Name — e.g. Enduro Rig" value="${esc(d.name)}" autocomplete="off" style="font-weight:700">
        <span class="lbl" style="color:var(--sky)">Rider</span>
        <div class="inline"><span class="small muted" style="width:56px">Weight</span><input class="input" id="ed-weight" inputmode="decimal" placeholder="${state.useKilograms ? "84" : "185"}" value="${esc(d.weight)}"><b style="color:var(--sky)">${state.useKilograms ? "kg" : "lb"}</b></div>
        <div class="inline"><span class="small muted" style="width:56px">Height</span><input class="input" id="ed-feet" inputmode="numeric" placeholder="5" value="${esc(d.feet)}"><b style="color:var(--sky)">ft</b>
          <input class="input" id="ed-inches" inputmode="decimal" placeholder="10" value="${esc(d.inches)}"><b style="color:var(--sky)">in</b></div>
        <div class="field"><span>Frame size</span>${seg("ed.frameSize", E.FRAME_SIZES.map((s) => [s, s]), d.frameSize)}</div>
        <div class="field"><span>Riding style</span>${seg("ed.style", E.STYLES.map((s) => [s, E.STYLE_SHORT[s]]), d.style)}</div>
        <div class="field"><span>Riding</span>${seg("ed.skill", [["relaxed", "Relaxed"], ["intermediate", "Intermediate"], ["aggressive", "Aggressive"]], d.skill)}</div>
        <div class="field"><span>Body position</span>${seg("ed.position", [["neutral", "Centred"], ["forward", "Over the front"]], d.position)}</div></section>
      <section class="glass pad stack"><span class="lbl" style="color:var(--teal)">Bike details</span>
        <div class="preview">${B.bikeSVG({ variant: d.variant, hardtail: ht, paint: d.color, shockSpring: shockModel ? shockModel.spring : null, hasFork: d.fork.on, hasShock: !ht, badges: false, dark: isDark() })}</div>
        <div class="field"><span>Frame</span>${seg("ed.frameType", [["fullSuspension", "Full suspension"], ["hardtail", "Hardtail"]], d.frameType)}</div>
        <div class="field"><span class="row between">Colour <b style="color:var(--fg)">${B.PAINT_TITLES[d.color]}</b></span>
          <div class="swatches" role="group" aria-label="Frame colour">${Object.entries(B.PAINTS).map(([k, c]) => `<button type="button" data-paint="${k}" aria-pressed="${d.color === k}" aria-label="${B.PAINT_TITLES[k]}"><i style="background:linear-gradient(135deg,${c[0]},${c[1]},${c[2]})"></i></button>`).join("")}</div></div>
        <label class="switch"><span>⚡ E-bike</span><input type="checkbox" id="ed-ebike"${d.setup.eBike ? " checked" : ""}></label>
        <div class="field"><span>Wheels</span>${seg("ed.wheel", Object.entries(E.WHEEL_TITLES), d.setup.wheel)}</div>
        <div class="field"><span>Tire width</span>${seg("ed.tireWidth", Object.entries(E.TIRE_WIDTH_TITLES), d.setup.tireWidth)}</div>
        <label class="switch"><span>Tire inserts (CushCore, Rimpact…)</span><input type="checkbox" id="ed-inserts"${d.setup.inserts ? " checked" : ""}></label></section>
      <section class="glass pad stack"><label class="switch"><span class="lbl acc">Front · Fork</span><input type="checkbox" id="ed-fork-on"${d.fork.on ? " checked" : ""}></label>
        ${d.fork.on ? partEditor("fork") : '<span class="small muted">Rigid fork</span>'}</section>
      ${ht ? `<section class="glass pad row locked"><span aria-hidden="true">🔒</span><div><span class="lbl">Rear · Shock</span><p class="small muted" style="margin:2px 0 0">Hardtail — no rear shock to set up. Switch Frame to Full suspension to add one.</p></div></section>`
        : `<section class="glass pad stack"><span class="lbl" style="color:var(--gold)">Rear · Shock</span>${partEditor("shock")}</section>
           <section class="glass pad stack"><label class="switch"><span><b>Frame maker's recommended sag</b><br><span class="tiny muted">Check your frame's manual; it beats the shock maker's general range.</span></span><input type="checkbox" id="ed-framesag"${d.setup.frameRearSag != null ? " checked" : ""}></label>
           ${d.setup.frameRearSag != null ? `<div class="inline"><button class="nudge" data-action="framesag" data-dir="-1" aria-label="Less sag">−</button><b class="c" style="font-size:24px;min-width:70px;text-align:center">${d.setup.frameRearSag}%</b><button class="nudge" data-action="framesag" data-dir="1" aria-label="More sag">+</button></div>` : ""}
           <div class="field"><span>Frame leverage curve</span>${seg("ed.frameProgression", [["linear", "Linear"], ["average", "Average"], ["progressive", "Progressive"]], d.setup.frameProgression)}
           <span class="tiny muted">Linear frames need more volume spacers, progressive frames fewer. Not sure? Leave Average.</span></div></section>`}
      <section class="glass pad stack"><span class="lbl" style="color:var(--warn)">Hours since last service</span>
        ${d.fork.on ? `<div class="inline"><span class="grow">Fork</span><input class="input" id="ed-forkhours" inputmode="decimal" value="${d.setup.forkHours || 0}"><b>h</b></div>` : ""}
        ${!ht ? `<div class="inline"><span class="grow">Shock</span><input class="input" id="ed-shockhours" inputmode="decimal" value="${d.setup.shockHours || 0}"><b>h</b></div>` : ""}
        <span class="tiny muted">Leave at 0 if you don't know. You'll get a reminder when a service is due.</span></section>
      ${!d.isNew ? '<button class="btn danger" data-action="delete-bike">Delete bike</button>' : ""}
      <p class="problem" id="ed-problem">${problem ? "ⓘ " + esc(problem) : ""}</p>`;
    const scroll = sheet.open ? sheet.querySelector(".sheet-inner").scrollTop : 0;
    openSheet(d.isNew ? "Add bike" : "Edit bike", body, { kind: "editor", cancel: true, save: "Save" });
    sheet.querySelector(".sheet-inner").scrollTop = scroll;
    $('[data-sheet="save"]').disabled = !!problem;
  }
  function readDraftInputs() {
    if (!draft) return;
    const v = (id) => { const el = $("#" + id); return el ? el.value : null; };
    if (v("ed-name") != null) draft.name = v("ed-name");
    if (v("ed-weight") != null) draft.weight = v("ed-weight");
    if (v("ed-feet") != null) draft.feet = v("ed-feet");
    if (v("ed-inches") != null) draft.inches = v("ed-inches");
    if (v("ed-forkhours") != null) draft.setup.forkHours = parseFloat(v("ed-forkhours")) || 0;
    if (v("ed-shockhours") != null) draft.setup.shockHours = parseFloat(v("ed-shockhours")) || 0;
  }
  function refreshProblem() {
    const p = draftProblem();
    $("#ed-problem").textContent = p ? "ⓘ " + p : "";
    $('[data-sheet="save"]').disabled = !!p;
  }
  function saveDraft() {
    readDraftInputs();
    if (draftProblem()) return;
    const d = draft;
    const existing = state.bikes.find((b) => b.id === d.id);
    const bike = existing || blankBike();
    bike.id = d.id;
    bike.name = d.name.trim();
    const wv = parseFloat(d.weight.replace(",", "."));
    bike.rider = { weightLb: state.useKilograms ? wv * 2.20462 : wv, heightIn: parseFloat(d.feet) * 12 + (d.inches === "" ? 0 : parseFloat(d.inches.replace(",", "."))),
      frameSize: d.frameSize, skill: d.skill, position: d.position };
    bike.style = d.style;
    bike.setup = Object.assign({}, d.setup, { forkHours: Math.max(0, d.setup.forkHours || 0), shockHours: Math.max(0, d.setup.shockHours || 0) });
    bike.frameType = d.frameType;
    bike.color = d.color;
    const newFork = d.fork.on && d.fork.modelID ? { modelID: d.fork.modelID, travelMm: d.fork.travel, strokeMm: 0 } : null;
    const newShock = d.frameType !== "hardtail" && d.shock.modelID ? { modelID: d.shock.modelID, travelMm: d.shock.travel, strokeMm: d.shock.stroke } : null;
    if ((newFork && newFork.modelID) !== (bike.fork && bike.fork.modelID)) bike.forkRan = { clicks: {} };
    if ((newShock && newShock.modelID) !== (bike.shock && bike.shock.modelID)) bike.shockRan = { clicks: {} };
    bike.fork = newFork; bike.shock = newShock;
    if (!existing) state.bikes.push(bike);
    state.selectedBikeID = bike.id;
    state.tuneEnd = newFork ? "fork" : "shock";
    draft = null; save(); closeSheet(); toast(existing ? "Bike saved" : "Bike added to your rack");
  }

  function currentEnd(bike) { const l = ends(bike); return l.includes(state.tuneEnd) ? state.tuneEnd : l[0]; }

  // ------------------------------------------------------------------ share, print, history

  function setupText(bike, end) {
    const m = modelFor(bike, end), r = rec(bike, end), ran = ranFor(bike, end), diffs = E.differences(r, ran);
    const lines = [`Suspension Tuner — ${bike.name}: ${m.brand} ${m.name}`,
      `Rider: ${weightText(bike.rider.weightLb)} · ${heightText(bike.rider.heightIn)} · Frame ${bike.rider.frameSize} · ${E.STYLE_LABELS[bike.style]}`,
      r.quality === "estimate" ? "Source: estimate (no published setup chart)" : `Source: ${r.sourceTitle || ""} (${E.QUALITY_TITLES[r.quality].toLowerCase()})`, ""];
    r.settings.forEach((s) => lines.push(`${s.label}: ${s.value}`));
    if (diffs.length) lines.push("", "Running:", ...diffs.map((x) => "• " + x));
    lines.push("", catalog.disclaimer);
    return lines.join("\n");
  }
  async function share() {
    const bike = selected(), end = currentEnd(bike), text = setupText(bike, end);
    if (navigator.share) { try { await navigator.share({ title: "Suspension setup", text }); return; } catch (e) { if (e.name === "AbortError") return; } }
    try { await navigator.clipboard.writeText(text); toast("Setup copied — paste it anywhere"); }
    catch (e) { openSheet("Copy setup", `<textarea class="input" rows="14" readonly id="copy-text">${esc(text)}</textarea>`); $("#copy-text").select(); }
  }
  function print() {
    const bike = selected(), end = currentEnd(bike), m = modelFor(bike, end), r = rec(bike, end);
    $("#print").innerHTML = `<h1>${esc(bike.name)} — ${end === "fork" ? "Front" : "Rear"}: ${esc(m.brand)} ${esc(m.name)}</h1>
      <div>${esc(weightText(bike.rider.weightLb))} · ${esc(heightText(bike.rider.heightIn))} · Frame ${bike.rider.frameSize} · ${E.STYLE_LABELS[bike.style]} · ${esc(E.QUALITY_TITLES[r.quality])}</div>
      <table>${r.settings.map((s) => `<tr><td>${esc(s.label)}</td><td><b>${esc(s.value)}</b><br>${esc(s.detail)}</td></tr>`).join("")}</table>
      <p style="font-size:9pt;margin-top:12pt">${esc(catalog.disclaimer)}</p>`;
    window.print();
  }
  function saveHistory() {
    const bike = selected(), end = currentEnd(bike);
    openSheet("Save this setup", `<p class="small muted" style="margin:0">${esc(bike.name)} · ${end === "fork" ? "Front" : "Rear"} · ${E.STYLE_LABELS[bike.style]}</p>
      <div class="field"><label for="hist-note">Note (optional)</label><input class="input" id="hist-note" placeholder="e.g. felt harsh on roots" maxlength="200"></div>`,
      { kind: "history", cancel: true, save: "Save", end });
    setTimeout(() => { const n = $("#hist-note"); if (n) n.focus(); }, 50);
  }
  function commitHistory() {
    const bike = selected(), end = sheetState.end, m = modelFor(bike, end), r = rec(bike, end);
    state.history.push({ id: uid(), date: new Date().toISOString(), bikeID: bike.id, bikeName: bike.name, end, brand: m.brand, modelName: m.name,
      style: bike.style, recommended: r.settings.map((s) => `${s.label}: ${s.value}`), ran: E.differences(r, ranFor(bike, end)),
      note: ($("#hist-note").value || "").trim() });
    save(); closeSheet(); toast("Saved to History");
  }

  // ------------------------------------------------------------------ events

  document.addEventListener("click", (ev) => {
    const t = ev.target.closest("button, [data-end].badge, .badge");
    const bikeTap = ev.target.closest("#hero-bike");
    if (bikeTap && !ev.target.closest(".badge")) {
      bikeTap.classList.remove("bounce"); void bikeTap.offsetWidth; bikeTap.classList.add("bounce");
    }
    if (!t) return;
    if (t.classList && t.classList.contains("badge")) { go("tune", t.dataset.end); return; }
    const d = t.dataset;
    if (d.tab) { go(d.tab); return; }
    if (d.style) {
      const bike = selected(); bike.style = d.style; save(); render();
      const hb = $("#hero-bike"); if (hb) hb.classList.add("bounce");
      return;
    }
    if (d.sheet) {
      if (d.sheet === "save") { if (sheetState.kind === "editor") saveDraft(); else if (sheetState.kind === "history") commitHistory(); }
      else { draft = null; closeSheet(); }
      return;
    }
    if (d.seg) { onSeg(d.seg, d.value); return; }
    if (d.brand) {
      readDraftInputs();
      const p = draft[d.brand];
      if (p.brand !== d.value) { p.brand = d.value; p.modelID = null; }
      renderEditor(); return;
    }
    if (d.paint) { readDraftInputs(); draft.color = d.paint; renderEditor(); return; }
    if (d.symptom) { troubleSheet(d.symptom); return; }
    const bike = selected();
    switch (d.action) {
      case "add-bike": editBike(blankBike()); break;
      case "edit-bike": editBike(state.bikes.find((b) => b.id === d.id) || bike); break;
      case "select-bike": state.selectedBikeID = d.id; save(); render(); window.scrollTo(0, 0); break;
      case "help": helpSheet(); break;
      case "conditions": conditionsSheet(); break;
      case "checklist": checklistSheet(); break;
      case "tune": go("tune", d.end); break;
      case "go-rack": go("rack"); break;
      case "end": state.tuneEnd = d.end; save(); render(); break;
      case "spring": {
        const end = currentEnd(bike), r = rec(bike, end), ran = cleanRan(ranFor(bike, end));
        const stepv = r.isAir ? 1 : 25, v = Math.max(0, (ran.springValue ?? r.springValue) + Number(d.dir) * stepv);
        ran.springValue = v === r.springValue ? null : v; setRan(bike, end, ran); render(); break;
      }
      case "spring-reset": { const end = currentEnd(bike), ran = cleanRan(ranFor(bike, end)); ran.springValue = null; setRan(bike, end, ran); render(); break; }
      case "reset-ran": setRan(bike, currentEnd(bike), { clicks: {} }); render(); break;
      case "sag-help": textSheet("How to check sag", [
        "Sag is how far the suspension sinks under your weight in your riding position.",
        "1. Push the O-ring down to the seal. 2. Get on the bike in your riding kit, standing in attack position, then sit. 3. Step off gently without bouncing. 4. Measure from the seal to the O-ring.",
        `Divide by the ${"fork travel or shock stroke"} for your sag %. Too much sag? Add air. Too little? Let some out. Use Check my sag to work it out for you.`]); break;
      case "damping-help": textSheet("Damping sliders", [
        "Each slider is one adjuster on your fork or shock. The small mark above the track is the recommended setting.",
        "Count clicks from fully closed (turn clockwise until it gently stops) or fully open, as each slider's unit says: OUT means counted out from closed, IN means counted in from open.",
        "Drag a slider to what you actually run. The step-by-step instructions and Save to History follow your sliders."]); break;
      case "sag-helper": sagHelperSheet(); break;
      case "trouble": troubleSheet(null); break;
      case "countdown": runCountdown(t); break;
      case "use-spring": {
        const end = sheetState.end, r = rec(bike, end), ran = cleanRan(ranFor(bike, end)), v = Number(d.value);
        ran.springValue = v === r.springValue ? null : v; setRan(bike, end, ran); closeSheet(); toast(`Dial set to ${v} ${r.headlineUnit}`); break;
      }
      case "apply-fix": {
        const end = sheetState.end, r = rec(bike, end), fix = E.troubleshoot(sheetState.symptom, r, ranFor(bike, end), end)[Number(d.fix)];
        setRan(bike, end, cleanRan(E.applyFix(fix, ranFor(bike, end), r))); toast("Applied to your setup"); troubleSheet(sheetState.symptom); break;
      }
      case "temp": {
        bike.ride.temperatureF = Math.max(0, Math.min(110, bike.ride.temperatureF + Number(d.dir))); save();
        $("#temp-v").textContent = `${Math.round(bike.ride.temperatureF)}°F`; break;
      }
      case "framesag": readDraftInputs(); draft.setup.frameRearSag = Math.max(20, Math.min(40, draft.setup.frameRearSag + Number(d.dir))); renderEditor(); break;
      case "delete-bike": {
        const id = draft.id;
        openSheet("Delete bike?", `<p class="muted" style="margin:0">Delete ${esc(draft.name || "this bike")}? Its saved setups stay in History.</p>
          <button class="btn danger" data-action="confirm-delete" data-id="${id}">Delete bike</button>`, { kind: "confirm" });
        break;
      }
      case "confirm-delete": {
        state.bikes = state.bikes.filter((b) => b.id !== d.id);
        if (state.selectedBikeID === d.id) state.selectedBikeID = state.bikes[0] ? state.bikes[0].id : null;
        draft = null; save(); closeSheet(); toast("Bike deleted"); break;
      }
      case "share": share(); break;
      case "print": print(); break;
      case "save-history": saveHistory(); break;
      case "delete-history": state.history = state.history.filter((h) => h.id !== d.id); save(); render(); break;
      case "disclaimer": disclaimerSheet(); break;
      case "export": exportData(); break;
      case "erase": openSheet("Erase everything?", `<p class="muted" style="margin:0">This deletes every bike and all history saved in this browser. It can't be undone. Download a backup first if you might want them back.</p>
        <button class="btn danger" data-action="confirm-erase">Erase all bikes and history</button>`, { kind: "confirm" }); break;
      case "confirm-erase": state.bikes = []; state.history = []; state.selectedBikeID = null; save(); closeSheet(); toast("Everything erased"); break;
    }
  });

  function onSeg(name, value) {
    if (name === "appearance") { state.appearance = value; save(); render(); return; }
    if (name === "units") { state.useKilograms = value === "kg"; save(); render(); return; }
    if (name.startsWith("ride.")) {
      const bike = selected(); bike.ride[name.slice(5)] = value; save();
      document.querySelectorAll(`[data-seg="${name}"]`).forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.value === value)));
      return;
    }
    if (name.startsWith("ed.")) {
      readDraftInputs();
      const k = name.slice(3);
      if (["wheel", "tireWidth", "frameProgression"].includes(k)) draft.setup[k] = value; else draft[k] = value;
      renderEditor();
    }
  }

  document.addEventListener("input", (ev) => {
    const el = ev.target;
    if (el.matches('input[type=range][data-key]')) {
      const v = Number(el.value), rec0 = Number(el.dataset.rec), key = el.dataset.key;
      el.style.setProperty("--pct", (v / Number(el.max) * 100).toFixed(1) + "%");
      const out = $("#v-" + key);
      out.firstChild.nodeValue = String(v);
      out.style.color = v !== rec0 ? getComputedStyle(el).getPropertyValue("--fill") : "";
      return;
    }
    if (draft && el.id && el.id.startsWith("ed-") && el.type !== "checkbox") { readDraftInputs(); refreshProblem(); return; }
    if (draft && el.type === "range" && /^(fork|shock)-(travel|stroke)$/.test(el.id)) {
      const [kind, what] = el.id.split("-");
      draft[kind][what] = Number(el.value);
      el.style.setProperty("--pct", ((el.value - el.min) / Math.max(1, el.max - el.min) * 100).toFixed(1) + "%");
      $("#" + el.id + "-v").textContent = `${el.value} mm`;
      return;
    }
    if (el.id === "sag-mm") sagResult();
  });

  document.addEventListener("change", (ev) => {
    const el = ev.target;
    if (el.matches('input[type=range][data-key]')) {
      const bike = selected(), end = currentEnd(bike), r = rec(bike, end), ran = cleanRan(ranFor(bike, end)), v = Number(el.value), key = el.dataset.key;
      if (key === "tokens") ran.tokens = v === r.tokens ? null : v;
      else { const c = r.clicks.find((x) => x.key === key); if (v === c.value) delete ran.clicks[key]; else ran.clicks[key] = v; }
      const y = window.scrollY; setRan(bike, end, ran); render(); window.scrollTo(0, y);
      return;
    }
    if (el.id === "bike-select") { state.selectedBikeID = el.value; save(); render(); return; }
    if (el.dataset.check) {
      const id = el.dataset.check, done = state.checklist.done;
      if (el.checked && !done.includes(id)) done.push(id);
      if (!el.checked) state.checklist.done = done.filter((x) => x !== id);
      el.closest(".check").classList.toggle("done", el.checked); save();
      if (state.checklist.done.length === E.checklist(rec(selected(), "fork"), rec(selected(), "shock")).length) toast("All checked. Send it.");
      return;
    }
    if (el.id === "import-file") { importData(el.files[0]); el.value = ""; return; }
    if (!draft) return;
    readDraftInputs();
    if (el.id === "model-fork" || el.id === "model-shock") {
      const kind = el.id.slice(6), m = models[el.value];
      draft[kind].modelID = el.value || null;
      if (m) { draft[kind].travel = m.travel.default; draft[kind].stroke = m.stroke ? m.stroke.default : 0; }
      renderEditor(); return;
    }
    if (el.id === "ed-ebike") { draft.setup.eBike = el.checked; renderEditor(); return; }
    if (el.id === "ed-inserts") { draft.setup.inserts = el.checked; return; }
    if (el.id === "ed-fork-on") { draft.fork.on = el.checked; renderEditor(); return; }
    if (el.id === "ed-framesag") { draft.setup.frameRearSag = el.checked ? (draft.setup.frameRearSag || 30) : null; renderEditor(); }
  });

  sheet.addEventListener("close", () => { if (sheetState) { draft = null; sheetState = null; render(); } });
  sheet.addEventListener("click", (ev) => { if (ev.target === sheet) { draft = null; closeSheet(); } });
  document.addEventListener("keydown", (ev) => {
    const b = ev.target.closest && ev.target.closest(".badge");
    if (b && (ev.key === "Enter" || ev.key === " ")) { ev.preventDefault(); go("tune", b.dataset.end); }
  });
  matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => { if (state.appearance === "system") render(); });

  let cdTimer = null;
  function runCountdown(btn) {
    clearInterval(cdTimer);
    let n = 10; const el = $("#cd"); el.textContent = n; btn.disabled = true;
    cdTimer = setInterval(() => {
      n -= 1; if (!$("#cd")) { clearInterval(cdTimer); return; }
      $("#cd").textContent = n > 0 ? n : "Step off";
      if (n <= 0) { clearInterval(cdTimer); btn.disabled = false; if (navigator.vibrate) navigator.vibrate(200); $("#sag-mm").focus(); }
    }, 1000);
  }

  function exportData() {
    const data = JSON.stringify({ app: "Suspension Tuner", version: 1, exported: new Date().toISOString(), bikes: state.bikes, history: state.history, useKilograms: state.useKilograms }, null, 2);
    const a = document.createElement("a");
    a.href = URL.createObjectURL(new Blob([data], { type: "application/json" }));
    a.download = `suspension-tuner-backup-${new Date().toISOString().slice(0, 10)}.json`;
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 2000);
  }
  function importData(file) {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const d = JSON.parse(reader.result);
        if (!Array.isArray(d.bikes)) throw new Error("no bikes");
        const fresh = blankBike();
        state.bikes = d.bikes.map((b) => Object.assign(blankBike(), b, { rider: Object.assign({}, fresh.rider, b.rider),
          setup: Object.assign({}, fresh.setup, b.setup), ride: Object.assign({}, fresh.ride, b.ride) }));
        state.history = Array.isArray(d.history) ? d.history : [];
        if (typeof d.useKilograms === "boolean") state.useKilograms = d.useKilograms;
        state.selectedBikeID = state.bikes[0] ? state.bikes[0].id : null;
        save(); render(); toast(`Restored ${state.bikes.length} bike${state.bikes.length === 1 ? "" : "s"}`);
      } catch (e) { toast("That file isn't a Suspension Tuner backup."); }
    };
    reader.readAsText(file);
  }

  // ------------------------------------------------------------------ start

  fetch("data/catalog.json").then((r) => { if (!r.ok) throw new Error(r.status); return r.json(); }).then((c) => {
    catalog = c; c.models.forEach((m) => { models[m.id] = m; });
    render();
  }).catch(() => { $("#view").innerHTML = '<p class="loading">Couldn\'t load the suspension catalog. Check your connection and reload.</p>'; });

  if ("serviceWorker" in navigator && location.protocol === "https:") {
    window.addEventListener("load", () => navigator.serviceWorker.register("sw.js").catch(() => {}));
  }
})();
