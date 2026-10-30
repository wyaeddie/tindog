// Suspension setup calculator for the web app.
// Mirrored 1:1 from python/suspension_engine.py and apple/Sources/SuspensionKit/Engine.swift —
// change all three together. tools/web_parity.py checks this file against the Python engine (keep web/data/catalog.json in sync with the app's catalog).
// Also holds the trailside tools from RideTools.swift (troubleshooter, sag check, coil springs,
// pre-ride checklist, step by step).

const LB_PER_KG = 2.20462;
const GEAR_KG = 5.0;
const FRAME_SIZES = ["S", "M", "L", "XL"];
const STYLES = ["xc", "trail", "enduro", "park", "dh"];
const STYLE_LABELS = { xc: "XC", trail: "Trail", enduro: "Enduro", park: "Bike Park", dh: "Downhill" };
const STYLE_SHORT = { xc: "XC", trail: "Trail", enduro: "Enduro", park: "Bike Park", dh: "DH" };
const GRAVITY = ["park", "dh"];
const FORK_SAG = { xc: 18, trail: 20, enduro: 22, park: 23, dh: 25 };
const SHOCK_SAG = { xc: 25, trail: 28, enduro: 30, park: 31, dh: 33 };
const LSC_FRACTION = { xc: 0.45, trail: 0.30, enduro: 0.40, park: 0.50, dh: 0.45 };
const HSC_FRACTION = { xc: 0.25, trail: 0.25, enduro: 0.40, park: 0.55, dh: 0.60 };
const CATEGORY_RANK = { xc: 0, trail: 1, enduro: 2, dh: 3 };
const TOKEN_BUMP = { xc: 0, trail: 0, enduro: 1, park: 2, dh: 2 };
const EBIKE_EXTRA_LB = 15.0;
const PUMP_TEMP_F = 70.0;
const PACK_LB = { none: 0, hip: 5, day: 12, big: 20 };
const PACK_TITLES = { none: "No pack", hip: "Hip pack", day: "Day pack", big: "Big pack" };
const TERRAIN_TITLES = { mixed: "Mixed", rough: "Rocky / rooty", flow: "Flow / jumps" };
const PRIORITY_TITLES = { climb: "Climbing", balanced: "Balanced", descend: "Descending" };
const WHEEL_TITLES = { "29": "29″", "27.5": "27.5″", mixed: "Mixed" };
const TIRE_WIDTH_TITLES = { standard: "2.3–2.4″", wide: "2.5–2.6″" };
const STYLE_TIP = {
  xc: "XC: run the firm end of the sag range and use the lockout on climbs.",
  dh: "Downhill: run the plush end of the sag range; add high-speed compression or a spacer if you bottom out.",
  trail: "Trail: the firm end of the sag range pedals best.",
  enduro: "Enduro: aim for the middle of the sag range.",
  park: "Bike Park: run the plush end of the sag range and add a volume spacer if you bottom out.",
};
const QUALITY_TITLES = { manufacturer: "Manufacturer chart", partial: "Partly manufacturer", estimate: "Estimate" };

const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const roundHalfUp = (v) => Math.floor(v + 0.5);
const weightIndex = (lb) => clamp((lb - 120) / 140, 0, 1);
const possessive = (name) => name + (name.endsWith("s") ? "'" : "'s");
const clicksWord = (n) => (n === 1 ? "click" : "clicks");
/** Fixed decimals like Python/Swift (printf): exact halves round to even, e.g. 17.25 → "17.2". */
function fixed(v, d) {
  // A double's exact decimal value has at most ~60 significant digits here, so 100 is exact.
  const exact = Math.abs(v).toPrecision(100);
  const frac = exact.split(".")[1] || "";
  if (/^50*$/.test(frac.slice(d))) {                       // exactly halfway: round half to even
    const x = Math.round(Math.abs(v) * 10 ** d - 0.5);
    const even = x % 2 === 0 ? x : x + 1;
    return (Math.sign(v) * even / 10 ** d).toFixed(d);
  }
  return v.toFixed(d);
}
const num = (v) => (Number.isInteger(v) ? String(v) : fixed(v, 1));
const signed = (n) => (n >= 0 ? "+" : "") + n;
const capitalize = (s) => s.charAt(0).toUpperCase() + s.slice(1).toLowerCase();
const describe = (nudges) => nudges.map((n) => n[0]).join(", ");
const sum = (nudges) => nudges.reduce((a, n) => a + n[1], 0);
const minBy = (arr, f) => arr.reduce((best, x) => (f(x) < f(best) ? x : best), arr[0]);

function recommendedFrameSize(heightCm) {
  if (heightCm < 163) return "S";
  if (heightCm < 175) return "M";
  if (heightCm < 186) return "L";
  return "XL";
}

function specsUrl(catalog, model) {
  if (model.url) return model.url;
  const domain = catalog.brandSites[model.brand];
  return "https://www.google.com/search?q=" + encodeURIComponent(`site:${domain} ${model.name} specs`).replace(/%20/g, "+");
}

function table(tables, travel) {
  if (!tables || !tables.length) return null;
  const dist = (t) => {
    const r = t.travel;
    if (!r) return 0;
    return travel < r[0] ? r[0] - travel : travel > r[1] ? travel - r[1] : 0;
  };
  return minBy(tables, dist);
}

function lookup(kind, rows, x) {
  if (kind === "linear" && rows.length > 1) {
    let i = 0;
    while (i < rows.length - 2 && x > rows[i + 1][0]) i++;
    const a = rows[i], b = rows[i + 1];
    const v = a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0]);
    return { row: a, value: v, x0: a[0], x1: b[0], y0: a[1], y1: b[1], outside: x < rows[0][0] || x > rows[rows.length - 1][0] };
  }
  const width = rows.length > 1 ? rows[1][0] - rows[0][0] : 10;
  let i = 0;
  rows.forEach((r, n) => { if (r[0] <= x) i = n; });
  const x1 = i + 1 < rows.length ? rows[i + 1][0] : rows[i][0] + width;
  return { row: rows[i], value: rows[i][1], x0: rows[i][0], x1, y0: rows[i][1], y1: rows[i][1],
           outside: x < rows[0][0] || x >= rows[rows.length - 1][0] + width };
}

function chartSpan(t) {
  const rows = t.rows;
  const end = t.type === "linear" ? rows[rows.length - 1][0]
    : rows[rows.length - 1][0] + (rows.length > 1 ? rows[1][0] - rows[0][0] : 10);
  return `${num(rows[0][0])}–${num(end)} lb`;
}

/** Default rider input; every factor at its neutral value. */
function riderInput(o) {
  return Object.assign({
    weightKg: 80, heightCm: 178, frameSize: "M", style: "trail", travelMm: 150, strokeMm: 0,
    skill: "intermediate", position: "neutral", terrain: "mixed", condition: "dry", temperatureF: 70,
    pack: "none", feel: "balanced", priority: "balanced", eBike: false, wheel: "29", tireWidth: "standard",
    inserts: false, frameRearSag: null, frameProgression: "average", serviceHours: 0,
  }, o);
}

function calculate(model, rider) {
  const isFork = model.kind === "fork";
  const style = rider.style;
  const mfg = model.mfg || null;
  const brand = model.brand;
  const packLb = PACK_LB[rider.pack];
  const riderLb = rider.weightKg * LB_PER_KG;
  const chartLb = riderLb + packLb;
  const systemLb = (rider.weightKg + GEAR_KG) * LB_PER_KG + packLb + (rider.eBike ? EBIKE_EXTRA_LB : 0);
  const w = weightIndex(systemLb);

  const recSize = recommendedFrameSize(rider.heightCm);
  const frameIdx = FRAME_SIZES.indexOf(rider.frameSize);
  const fitDelta = FRAME_SIZES.indexOf(recSize) - frameIdx;
  const forward = rider.position === "forward" ? 0.02 : 0;
  const frontBias = clamp(0.40 + 0.01 * (frameIdx - 1) + 0.01 * fitDelta + forward, 0.36, 0.48);
  const rearBias = 1 - frontBias;

  const warnings = [], tips = [], settings = [], estimated = [];
  const setting = (label, value, detail = "") => settings.push({ label, value, detail });

  // ---- sag
  let sagMin = null, sagMax = null, sagNote = "";
  let styleSag = isFork ? FORK_SAG[style] : SHOCK_SAG[style];
  if (model.category === "xc") styleSag -= isFork ? 3 : 2;
  const makerSag = mfg && mfg.sag && mfg.sag.length === 2 ? mfg.sag : null;
  let base, lo, hi, makerMid;
  if (!isFork && rider.frameRearSag && rider.frameRearSag > 0) {
    const fs = rider.frameRearSag;
    base = fs; lo = fs - 2; hi = fs + 2;
    makerMid = makerSag ? (makerSag[0] + makerSag[1]) / 2 : styleSag;
    sagNote = `Frame maker: ${num(fs)}%. `;
  } else if (makerSag) {
    const [s0, s1] = makerSag;
    sagMin = Math.trunc(s0); sagMax = Math.trunc(s1);
    base = (s0 + s1) / 2;
    lo = s0 === s1 ? s0 - 2 : s0;
    hi = s0 === s1 ? s1 + 2 : s1;
    makerMid = base;
    const rng = s0 === s1 ? `about ${num(s0)}%` : `${num(s0)}–${num(s1)}%`;
    sagNote = `${brand}: ${rng} of ${isFork ? "travel" : "shock stroke"}. `;
  } else {
    base = styleSag; lo = styleSag - 2; hi = styleSag + 2; makerMid = styleSag;
    if (mfg) estimated.push("sag target");
  }
  const rangeFromMaker = makerSag !== null || (!isFork && !!(rider.frameRearSag && rider.frameRearSag > 0));
  const styleTarget = !rangeFromMaker ? base : style === "xc" ? lo : style === "dh" ? hi : base;
  const target = rider.feel === "firm" ? lo : rider.feel === "plush" ? hi : styleTarget;
  const sagPct = roundHalfUp(target);
  const sag = sagPct / 100;
  const sagMm = (isFork ? rider.travelMm : rider.strokeMm) * sag;
  const sagRangeText = `${num(lo)}–${num(hi)}%`;

  // ---- spring
  let trailPsi = null, pressureFromChart = false, leverage = 0, headline, springValue, detail;
  if (model.spring === "air") {
    const maxPsi = (rider.eBike && mfg && mfg.ebikeMaxPsi) || model.maxPsi || 999;
    const ebikeChart = !!(rider.eBike && mfg && mfg.ebikePressure);
    const changes = [];
    const t = table(mfg && (ebikeChart ? mfg.ebikePressure : mfg.pressure), rider.travelMm);
    let psi;
    if (t) {
      const hit = lookup(t.type, t.rows, chartLb);
      psi = hit.value;
      pressureFromChart = true;
      const chart = ebikeChart ? `${brand} E-Bike+ chart` : `${brand} chart`;
      detail = t.type === "linear"
        ? `${chart}: ${num(hit.y0)}–${num(hit.y1)} psi for ${num(hit.x0)}–${num(hit.x1)} lb riders.`
        : `${chart}, ${num(hit.x0)}–${num(hit.x1)} lb row.`;
      if (hit.outside) {
        warnings.push(`At ${roundHalfUp(chartLb)} lb you're outside ${possessive(brand)} chart (${chartSpan(t)}) — `
          + (t.type === "linear" ? "the chart was extended in a straight line." : "the nearest row was used.")
          + " Set sag carefully.");
      }
    } else if (mfg && ["bodyWeight", "bodyWeightWithGear", "fixed"].includes(mfg.pressureRule)) {
      const rule = mfg.pressureRule;
      const factor = mfg.pressureFactor || 1;
      if (rule === "fixed") psi = mfg.pressureStart || 0;
      else if (rule === "bodyWeightWithGear") psi = (chartLb + GEAR_KG * LB_PER_KG) * factor;
      else psi = chartLb * factor;
      pressureFromChart = true;
      detail = `${brand}: ${mfg.ruleText || "start at your body weight in lb"}.`;
    } else {
      if (isFork) {
        psi = model.psiRatio * systemLb * (frontBias / 0.40) * Math.sqrt(20 / sagPct);
      } else {
        leverage = rider.travelMm / rider.strokeMm;
        psi = model.psiRatio * systemLb * (rearBias / 0.60) * Math.sqrt(28 / sagPct) * (leverage / 2.7);
      }
      estimated.push("air pressure");
      detail = "Estimate — set to sag. Adjust ±5 psi per ~2% sag change.";
    }
    if (pressureFromChart) {
      const f = Math.sqrt(makerMid / target);
      if (Math.abs(f - 1) > 1e-9) {
        psi *= f;
        changes.push(`${f > 1 ? "more" : "less"} for ${sagPct}% sag`);
      }
      if (isFork && rider.position === "forward") {
        psi *= 1.04;
        changes.push("+4% for weight over the front");
      }
      if (rider.eBike && !ebikeChart) {
        psi += 10;
        const sram = brand === "RockShox" && isFork;
        changes.push(`+10 psi for an e-bike${sram ? " (SRAM)" : ""}`);
        if (!sram) estimated.push("e-bike pressure");
      }
      if (changes.length) detail += ` Adjusted: ${changes.join(", ")}.`;
      detail += ` Fine-tune ±10 psi to hit ${sagPct}% sag.`;
    }
    let onTrail = roundHalfUp(psi);
    if (onTrail > maxPsi) {
      warnings.push(`${onTrail} psi exceeds the ${maxPsi} psi max — capped. Consider more volume spacers or a firmer spring.`);
      onTrail = maxPsi;
    }
    let pump = onTrail;
    if (rider.temperatureF !== PUMP_TEMP_F) {
      pump = roundHalfUp((onTrail + 14.7) * (PUMP_TEMP_F + 459.67) / (rider.temperatureF + 459.67) - 14.7);
      if (pump > maxPsi) pump = maxPsi;
      if (pump !== onTrail) {
        detail += ` Pump ${pump} psi indoors (${num(PUMP_TEMP_F)}°F) so it's ${onTrail} psi at `
          + `${num(rider.temperatureF)}°F on the trail — set ${onTrail} if you pump at the trailhead.`;
      }
    }
    trailPsi = onTrail;
    headline = ["Air pressure", String(pump), "psi"];
    springValue = pump;
    setting("Air pressure", `${pump} psi`, `${detail} Max ${maxPsi} psi.`);
    const rt = table(mfg && mfg.ramp, rider.travelMm);
    if (rt) {
      const r = roundHalfUp(lookup(rt.type, rt.rows, chartLb).value);
      setting(mfg.rampLabel || "Ramp-up chamber", `${r} psi`, `${brand} chart. More = more progressive (less bottom-out).`);
    }
  } else {
    const stroke = rider.strokeMm;
    leverage = rider.travelMm / stroke;
    const rearStatic = rearBias + 0.10;
    const raw = systemLb * rearStatic * leverage / (sag * (stroke / 25.4));
    const rate = 25 * roundHalfUp(raw / 25);
    springValue = rate;
    headline = ["Spring rate", String(rate), "lb/in"];
    setting("Coil spring", `${rate} lb/in`,
      `Calculated for ${sagPct}% sag at a ${fixed(leverage, 2)}:1 leverage ratio — coil rates `
      + "depend on the frame, so makers don't chart them. Use 1–2 turns of preload at most.");
  }

  let feelText;
  if (rider.feel !== "balanced") feelText = ` ${capitalize(rider.feel)} end of ${sagRangeText}.`;
  else if (styleTarget !== base) feelText = ` ${STYLE_LABELS[style]}: ${style === "xc" ? "firm" : "plush"} end of ${sagRangeText}.`;
  else feelText = "";
  setting("Sag", `${sagPct}%  ·  ${fixed(sagMm, 1)} mm`,
    sagNote + (isFork ? "Measured on the stanchion." : "Measured on the shock shaft, seated in attack position.") + feelText);

  // ---- adjustments for today's ride and the rider
  const reb = [], lsc = [], hsc = [], tok = [];
  if (rider.terrain === "rough") { reb.push(["rocky terrain", -1]); hsc.push(["rocky terrain", -1]); }
  else if (rider.terrain === "flow") {
    reb.push(["flow / jumps", 1]); lsc.push(["flow / jumps", 1]); hsc.push(["flow / jumps", 1]); tok.push(["flow / jumps", 1]);
  }
  if (rider.condition === "wet") { reb.push(["wet", 1]); lsc.push(["wet", -1]); }
  if (rider.temperatureF < 40) reb.push(["cold oil", -1]);
  if (rider.skill === "relaxed") { lsc.push(["relaxed riding", -1]); hsc.push(["relaxed riding", -1]); }
  else if (rider.skill === "aggressive") {
    lsc.push(["aggressive riding", 1]); hsc.push(["aggressive riding", 1]); tok.push(["aggressive riding", 1]);
  }
  if (rider.priority === "climb") lsc.push(["climbing priority", 1]);
  else if (rider.priority === "descend") lsc.push(["descending priority", -1]);
  if (rider.eBike) reb.push(["e-bike", 1]);

  const sReb = [], sLsc = [], sHsc = [], sTok = [];
  const whyStyle = `${STYLE_LABELS[style]} riding`;
  if (style === "xc") sLsc.push([whyStyle, 1]);
  else if (style === "enduro") sHsc.push([whyStyle, 1]);
  else if (style === "park") { sHsc.push([whyStyle, 2]); sLsc.push([whyStyle, 1]); sReb.push([whyStyle, 1]); sTok.push([whyStyle, 1]); }
  else if (style === "dh") { sHsc.push([whyStyle, 2]); sReb.push([whyStyle, -1]); sTok.push([whyStyle, 1]); }

  // ---- progression
  let tokens = null, tokenMax = null;
  const ebikeTokens = !!(rider.eBike && mfg && mfg.ebikeTokens);
  if (rider.eBike && !ebikeTokens) tok.push(["e-bike", 1]);
  if (!isFork && model.spring === "air") {
    if (rider.frameProgression === "linear") tok.push(["linear frame", 1]);
    else if (rider.frameProgression === "progressive") tok.push(["progressive frame", -1]);
  }
  const tokSum = sum(tok);
  let tokText = tok.length ? ` ${signed(tokSum)} for ${describe(tok)}.` : "";
  const tokRows = mfg && (ebikeTokens ? mfg.ebikeTokens : mfg.tokens);
  if (tokRows && tokRows.length) {
    const allTok = tok.concat(sTok);
    const allSum = sum(allTok);
    tokText = allTok.length ? ` ${signed(allSum)} for ${describe(allTok)}.` : "";
    const row = minBy(tokRows, (r) => Math.abs(r.travel - rider.travelMm));
    const n = Math.trunc(clamp(row.installed + allSum, 0, row.max));
    tokens = n; tokenMax = row.max;
    setting("Volume spacers", `${n} token${n !== 1 ? "s" : ""}`,
      `${brand}${ebikeTokens ? " E-Bike+" : ""} stock for ${num(row.travel)} mm travel: `
      + `${row.installed}.${tokText} Max ${row.max}. Add one if you bottom out harshly.`);
  } else if (model.tokens) {
    let t = model.tokens.default + TOKEN_BUMP[style];
    if (systemLb > 210) t += 1;
    else if (systemLb < 140) t -= 1;
    tokens = Math.trunc(clamp(t + tokSum, 0, model.tokens.max)); tokenMax = model.tokens.max;
    estimated.push("volume spacers");
    setting("Volume spacers", `${tokens} token${tokens !== 1 ? "s" : ""}`,
      `Estimate.${tokText} Max ${tokenMax}. Add one if you bottom out harshly.`);
  } else if (model.spring === "air" && !(mfg && mfg.ramp)) {
    setting("Progression", "See brand chart", "Uses a ramp-up chamber / inserts instead of tokens.");
  }

  // ---- damping
  const clicks = [];
  const adj = model.adjusters;
  const rules = {};
  ((mfg && mfg.damping) || []).forEach((r) => { rules[r.key] = r; });
  const adjusters = [
    ["rebound", "Reb", "Rebound", ""],
    ["lsr", "LSR", "Low-speed rebound", ""],
    ["hsr", "HSR", "High-speed rebound", ""],
    ["lsc", "LSC", "Low-speed compression", " Controls brake dive and pedal bob."],
    ["hsc", "HSC", "High-speed compression", " Controls big hits and square edges."],
  ];
  for (const [key, short, label, why] of adjusters) {
    const n = adj[key];
    if (!n) continue;
    const isReb = key === "rebound" || key === "lsr" || key === "hsr";
    const rule = rules[key];
    const nudges = (isReb ? reb : key === "lsc" ? lsc : hsc)
      .concat(rule ? (isReb ? sReb : key === "lsc" ? sLsc : sHsc) : []);
    const firm = sum(nudges);
    let of = n, isMfg = true, fromClosed, baseLo, baseHi, d;
    if (rule) {
      fromClosed = rule.from === "closed";
      if (rule.by === "middle") {
        baseLo = roundHalfUp(n / 2); baseHi = null;
        d = `${brand}: start in the middle (of ${n}), then add or remove to taste.`;
      } else {
        const rows = rule.rows || [[0, 0]];
        let hit, basis;
        if (rule.by === "weight") { hit = lookup("steps", rows, chartLb); basis = ` for ${num(hit.x0)}–${num(hit.x1)} lb riders`; }
        else if (rule.by === "psi") {
          const p = trailPsi !== null ? trailPsi : springValue;
          hit = lookup("steps", rows, p); basis = ` at ${p} psi`;
        } else if (rule.by === "rate") { hit = lookup("steps", rows, springValue); basis = ` for a ${springValue} lb/in spring`; }
        else { hit = lookup("steps", rows, 0); basis = ""; }
        baseLo = Math.trunc(hit.row[1]);
        baseHi = hit.row.length > 2 ? Math.trunc(hit.row[2]) : null;
        of = Math.max(n, baseHi !== null ? baseHi : baseLo);
        d = `${brand} chart${basis}. Counted ${fromClosed ? "out from fully closed" : "in from fully open"}, of ${of}.`;
      }
    } else {
      fromClosed = isReb; isMfg = false;
      if (isReb) {
        const b = key === "hsr" ? 0.55 : 0.65;
        baseLo = Math.trunc(clamp(roundHalfUp(n * (b - 0.35 * w)), 1, Math.max(1, n - 1)));
      } else {
        const frac = key === "lsc" ? LSC_FRACTION[style] : HSC_FRACTION[style];
        baseLo = Math.trunc(clamp(roundHalfUp(n * clamp(frac + 0.1 * w, 0, 1)), 0, n));
      }
      baseHi = null;
      estimated.push(label.toLowerCase());
      d = `Estimate. Counted ${isReb ? "out from fully closed" : "in from fully open"}, of ${n}.`;
    }
    const shift = fromClosed ? -firm : firm;
    const newLo = Math.trunc(clamp(baseLo + shift, 0, of));
    const newHi = baseHi !== null ? Math.trunc(clamp(baseHi + shift, 0, of)) : null;
    const baseText = baseHi !== null ? `${baseLo}–${baseHi}` : `${baseLo}`;
    if (firm !== 0) {
      const dir = isReb ? (firm > 0 ? "slower" : "faster") : (firm > 0 ? "firmer" : "softer");
      d += ` Adjusted ${Math.abs(firm)} ${clicksWord(Math.abs(firm))} ${dir} from ${baseText} for ${describe(nudges)}.`;
    } else if (nudges.length) {
      d += ` (${describe(nudges)} cancel out.)`;
    }
    const rng = newHi !== null && newHi !== newLo ? `${newLo}–${newHi}` : null;
    const value = newHi !== null ? roundHalfUp((newLo + newHi) / 2) : newLo;
    clicks.push({ key, short, label, value, of, fromClosed, rangeText: rng, isManufacturer: isMfg,
                  isRebound: isReb, direction: fromClosed ? "out" : "in",
                  countedFrom: fromClosed ? "out from closed" : "in from open" });
    setting(label, `${rng || value} ${rng === null ? clicksWord(value) : "clicks"} ${fromClosed ? "out" : "in"}`, d + why);
  }

  // ---- lockout / climb
  if (model.climb) {
    let how;
    if (GRAVITY.includes(style)) how = "Leave open for lift laps; use only on long fire-road climbs.";
    else if (rider.priority === "climb") how = "Climbing priority: use the firm / climb mode on every sustained climb.";
    else if (rider.priority === "descend") how = "Descending priority: leave it open except on pavement.";
    else how = "Open on descents, firm for long climbs and pavement.";
    setting("Lockout / climb", model.climb, how);
  } else {
    setting("Lockout / climb", "None", "Use more low-speed compression for climbing support.");
  }

  // ---- tires
  const tireLb = riderLb + GEAR_KG * LB_PER_KG + packLb;
  let rearTire = 0.11 * tireLb + 3.5;
  if (rider.eBike) rearTire += 3;
  if (rider.tireWidth === "wide") rearTire -= 2;
  if (rider.inserts) rearTire -= 2;
  if (rider.condition === "wet") rearTire -= 1;
  let frontTire = rearTire - 3;
  if (rider.wheel === "27.5") { frontTire += 1; rearTire += 1; }
  else if (rider.wheel === "mixed") rearTire += 1;
  const frontPsi = Math.trunc(clamp(roundHalfUp(frontTire), 15, 40));
  const rearPsi = Math.trunc(clamp(roundHalfUp(rearTire), 15, 40));
  const tirePsi = isFork ? frontPsi : rearPsi;
  setting("Tire pressure", `${tirePsi} psi ${isFork ? "front" : "rear"}`,
    `Estimate for tubeless ${WHEEL_TITLES[rider.wheel]} ${TIRE_WIDTH_TITLES[rider.tireWidth]} tires`
    + `${rider.inserts ? " with inserts" : ""}${rider.eBike ? " on an e-bike" : ""}. `
    + `${isFork ? "Rear" : "Front"}: ${isFork ? rearPsi : frontPsi} psi. `
    + "Lower = more grip; add 1–2 psi if you feel rim strikes.");

  // ---- service
  const hours = rider.serviceHours;
  let serviceDue = false;
  if (hours > 0) {
    let interval, full, schedule;
    if (brand === "Fox" || brand === "Marzocchi") { interval = 125; full = 125; schedule = `${brand}: full service every 125 h or once a year`; }
    else if (brand === "RockShox") {
      interval = 50; full = 200;
      schedule = `RockShox: ${isFork ? "lower-leg" : "air-can"} service every 50 h, damper and spring every 200 h`;
    } else { interval = 100; full = 100; schedule = `Typical interval about 100 h — check ${possessive(brand)} schedule`; }
    setting("Service", `${num(hours)} h since service`, `${schedule}.`);
    if (hours >= interval) {
      serviceDue = true;
      const what = hours >= full ? "a full service" : `a ${isFork ? "lower-leg" : "air-can"} service`;
      warnings.push(`${model.name} is due ${what}: ${num(hours)} h since the last one. `
        + "Old oil and dry seals make damping feel slow and harsh.");
    }
  }

  // ---- fit & warnings
  if (fitDelta !== 0) {
    const totalIn = roundHalfUp(rider.heightCm / 2.54);
    warnings.push(`At ${Math.floor(totalIn / 12)}′${totalIn % 12}″ (${roundHalfUp(rider.heightCm)} cm) a size ${recSize} `
      + `frame is typical; you chose ${rider.frameSize}.`
      + (pressureFromChart ? "" : " Weight balance was adjusted for this."));
  }
  if (CATEGORY_RANK[model.category] === 0 && style !== "trail" && style !== "xc") {
    warnings.push(`The ${model.name} is an XC product — not intended for ${STYLE_LABELS[style].toLowerCase()} riding.`);
  }
  if (GRAVITY.includes(style) && CATEGORY_RANK[model.category] < 2) {
    warnings.push(`${style === "park" ? "Bike park" : "Downhill"} riding usually calls for an enduro or DH-rated product.`);
  }
  if (!isFork && model.spring === "coil" && rider.frameProgression === "linear") {
    warnings.push("Linear frame with a coil shock: use a progressive spring or more bottom-out control "
      + "(HBO / HSC) so you don't bottom out harshly.");
  }
  if (rider.temperatureF <= 32) {
    warnings.push("Below freezing: fork and shock oil thickens, so everything feels slower and firmer until it warms up.");
  }

  // ---- source & tips
  let quality = mfg ? mfg.quality : "estimate";
  if (quality === "manufacturer" && estimated.length) quality = "partial";
  if (mfg) {
    tips.push(`Source: ${mfg.sourceTitle}.`);
    if (estimated.length) tips.push(`Not in ${possessive(brand)} published chart, so estimated: ${estimated.join(", ")}.`);
    tips.push(style === "trail" ? `Trail uses the maker's baseline as is. ${STYLE_TIP[style]}`
      : `${STYLE_LABELS[style]} adjusts the maker's baseline — each change is listed on its setting. ${STYLE_TIP[style]}`);
  } else {
    tips.push(`No published ${brand} setup chart was found for this model — all values are calculated estimates.`);
  }
  const today = [];
  if (rider.terrain !== "mixed") today.push(TERRAIN_TITLES[rider.terrain].toLowerCase());
  if (rider.condition === "wet") today.push("wet");
  if (rider.temperatureF !== PUMP_TEMP_F) today.push(`${num(rider.temperatureF)}°F`);
  if (rider.pack !== "none") today.push(PACK_TITLES[rider.pack].toLowerCase());
  if (rider.feel !== "balanced") today.push(`${rider.feel} feel`);
  if (rider.priority !== "balanced") today.push(`${PRIORITY_TITLES[rider.priority].toLowerCase()} priority`);
  if (rider.eBike) today.push("e-bike");
  if (today.length) tips.push(`Adjusted for: ${today.join(", ")}.`);
  if (pressureFromChart) {
    tips.push(`Chart read at ${roundHalfUp(chartLb)} lb`
      + (packLb > 0 ? ` (your ${roundHalfUp(riderLb)} lb + ${num(packLb)} lb ${PACK_TITLES[rider.pack].toLowerCase()}).`
        : " — your body weight."));
  } else {
    tips.push(`Estimates use your weight with gear: ${roundHalfUp(systemLb)} lb `
      + `(${roundHalfUp(rider.weightKg)} kg rider + ${GEAR_KG.toFixed(0)} kg gear`
      + (packLb > 0 ? ` + ${num(packLb)} lb pack` : "")
      + (rider.eBike ? ` + ${num(EBIKE_EXTRA_LB)} lb e-bike` : "") + ").");
  }
  if (model.spring === "air") tips.push("Cycle the suspension 10× after inflating, then re-check sag.");
  tips.push("Change one setting at a time, 2 clicks at a time, on the same test loop.");
  if (model.note) tips.push(model.note);

  const maxOut = model.spring === "air" ? ((rider.eBike && mfg && mfg.ebikeMaxPsi) || model.maxPsi) : null;
  return {
    headlineLabel: headline[0], headlineValue: headline[1], headlineUnit: headline[2],
    settings, tips, warnings, isAir: model.spring === "air", springValue, maxPsi: maxOut || null,
    sagPercent: sagPct, sagMm, sagMin, sagMax, tokens, tokenMax, clicks, quality,
    sourceTitle: mfg ? mfg.sourceTitle : null, sourceUrl: mfg ? mfg.source || null : null,
    trailPsi, tirePsi, serviceDue,
  };
}

// ---------------------------------------------------------------- what you ran

/** Lines describing what differs from the recommendation. ran = {springValue, tokens, clicks:{}} */
function differences(rec, ran) {
  const out = [];
  if (ran.springValue != null && ran.springValue !== rec.springValue) {
    out.push(`${rec.headlineLabel}: ${ran.springValue} ${rec.headlineUnit} (recommended ${rec.springValue})`);
  }
  if (ran.tokens != null && rec.tokens != null && ran.tokens !== rec.tokens) {
    out.push(`Volume spacers: ${ran.tokens} (recommended ${rec.tokens})`);
  }
  for (const c of rec.clicks) {
    const v = ran.clicks && ran.clicks[c.key];
    if (v != null && v !== c.value) out.push(`${c.label}: ${v} clicks ${c.direction} (recommended ${c.value})`);
  }
  return out;
}

// ---------------------------------------------------------------- troubleshooter

const SYMPTOMS = [
  ["harshSmallBumps", "Harsh on roots and small bumps"],
  ["harshBigHits", "Harsh on big hits and square edges"],
  ["bottomsOut", "Bottoms out hard"],
  ["notFullTravel", "Never uses full travel"],
  ["divesUnderBraking", "Dives under braking"],
  ["wallowy", "Wallowy in berms and compressions"],
  ["kicksOnJumps", "Kicks or bucks off jumps"],
  ["packsDown", "Packs down in fast, rough sections"],
  ["bobsPedalling", "Bobs when pedalling"],
  ["noTraction", "Skips around, no traction"],
];
const symptomApplies = (s, kind) => (s === "divesUnderBraking" ? kind === "fork" : s === "bobsPedalling" ? kind === "shock" : true);

function troubleshoot(symptom, rec, ran, kind) {
  const spring = ran.springValue != null ? ran.springValue : rec.springValue;
  const step = rec.isAir ? (kind === "fork" ? 5 : 10) : 25;
  const unit = rec.isAir ? "psi" : "lb/in";
  const springName = rec.isAir ? "Air pressure" : "Spring rate";
  const springFix = (dir, why) => {
    let v = spring + dir * step;
    if (rec.isAir && rec.maxPsi) v = Math.min(v, rec.maxPsi);
    v = Math.max(v, rec.isAir ? 10 : 100);
    if (v === spring) return null;
    const what = rec.isAir ? (dir > 0 ? "more air" : "less air") : (dir > 0 ? "one spring firmer" : "one spring softer");
    return { title: `${springName}: ${spring} → ${v} ${unit} (${what})`, why, change: { type: "spring", value: v } };
  };
  const tokenFix = (dir, why) => {
    const base = ran.tokens != null ? ran.tokens : rec.tokens;
    if (base == null || rec.tokenMax == null) return null;
    const v = Math.min(Math.max(base + dir, 0), rec.tokenMax);
    if (v === base) return null;
    return { title: `Volume spacers: ${base} → ${v}`, why, change: { type: "tokens", value: v } };
  };
  const clickFix = (keys, firmer, why) => {
    let c = null;
    for (const k of keys) { c = rec.clicks.find((x) => x.key === k); if (c) break; }
    if (!c) return null;
    const cur = ran.clicks && ran.clicks[c.key] != null ? ran.clicks[c.key] : c.value;
    const v = Math.min(Math.max(c.fromClosed ? cur - firmer : cur + firmer, 0), c.of);
    if (v === cur) return null;
    const dir = c.isRebound ? (firmer > 0 ? "slower" : "faster") : (firmer > 0 ? "firmer" : "softer");
    return { title: `${c.short}: ${cur} → ${v} clicks ${c.direction} (${Math.abs(firmer)} ${dir})`, why,
             change: { type: "clicks", key: c.key, value: v } };
  };
  const rb = ["lsr", "rebound"], ls = ["lsc"], hs = ["hsc"], hr = ["hsr"];
  const end = kind === "fork" ? "fork" : "shock";
  const M = {
    harshSmallBumps: () => [springFix(-1, `More sag lets the ${end} move freely over small stuff.`),
      clickFix(ls, -2, "Less low-speed compression frees up the first part of the travel."),
      clickFix(rb, -2, "Faster rebound gets it back up in time for the next root.")],
    harshBigHits: () => [clickFix(hs, -2, "High-speed compression controls fast, hard hits — open it up."),
      tokenFix(-1, "Fewer spacers make the end of the travel less steep."),
      springFix(-1, "A little less spring if it still feels like hitting a wall.")],
    bottomsOut: () => [tokenFix(1, "A spacer adds ramp-up at the end of the travel without changing sag."),
      clickFix(hs, 2, "More high-speed compression resists big hits and landings."),
      springFix(1, "If it still bottoms, run a bit more spring and re-check sag.")],
    notFullTravel: () => [tokenFix(-1, "Fewer spacers make the last part of the travel easier to reach."),
      springFix(-1, "Slightly less spring so big hits use the travel you paid for."),
      clickFix(hs, -2, "Less high-speed compression lets it go deeper on big hits.")],
    divesUnderBraking: () => [clickFix(ls, 2, "Low-speed compression holds the fork up under braking and on steeps."),
      springFix(1, "A touch more air keeps the front higher."),
      tokenFix(1, "A spacer adds mid-stroke support.")],
    wallowy: () => [clickFix(ls, 2, "Low-speed compression adds support when you pump berms and compressions."),
      springFix(1, "A little more spring sits it higher in the travel.")],
    kicksOnJumps: () => [clickFix(rb, 2, "Slower rebound stops it springing you up off the lip."),
      clickFix(hr, 1, "A little more high-speed rebound calms big hits and drops.")],
    packsDown: () => [clickFix(rb, -2, "Faster rebound lets it recover between hits instead of sinking."),
      clickFix(hr, -2, "Faster high-speed rebound helps on repeated big hits."),
      clickFix(hs, -1, "Slightly less high-speed compression so it doesn't stay deep.")],
    bobsPedalling: () => [clickFix(ls, 2, "Low-speed compression controls pedal bob."),
      { title: "Use the climb switch on climbs", why: "That's what it's for — open it again before the descent.", change: { type: "advice" } },
      springFix(1, "Too much sag makes bob worse — check sag first.")],
    noTraction: () => [clickFix(rb, 2, "Rebound that's too fast bounces the tire off the ground."),
      clickFix(ls, -2, "Less low-speed compression lets the tire follow the ground."),
      springFix(-1, "A little more sag puts more of the tire on the dirt.")],
  };
  const fixes = M[symptom]().filter(Boolean);
  return fixes.length ? fixes : [{ title: "Check sag and tire pressure first",
    why: "This product has no adjuster for that — sag and tires are your tuning tools.", change: { type: "advice" } }];
}

/** The rider's setup after applying a fix. */
function applyFix(fix, ran, rec) {
  const r = { springValue: ran.springValue, tokens: ran.tokens, clicks: Object.assign({}, ran.clicks) };
  const ch = fix.change;
  if (ch.type === "spring") r.springValue = ch.value === rec.springValue ? null : ch.value;
  else if (ch.type === "tokens") r.tokens = ch.value === rec.tokens ? null : ch.value;
  else if (ch.type === "clicks") {
    const c = rec.clicks.find((x) => x.key === ch.key);
    if (c && ch.value === c.value) delete r.clicks[ch.key]; else r.clicks[ch.key] = ch.value;
  }
  return r;
}

// ---------------------------------------------------------------- sag check

function sagCheck(measuredMm, lengthMm, rec, springValue) {
  const pct = lengthMm > 0 ? measuredMm / lengthMm * 100 : 0;
  const target = rec.sagPercent;
  let lo = target - 2, hi = target + 2;
  if (rec.sagMin != null && rec.sagMax != null && rec.sagMin !== rec.sagMax) { lo = rec.sagMin; hi = rec.sagMax; }
  const shown = fixed(pct, 0);
  if (pct >= lo && pct <= hi) return { percent: pct, status: "good", suggestedSpring: null, message: `${shown}% sag — spot on. Ride it.` };
  if (!(pct > 0)) return { percent: 0, status: "tooLittle", suggestedSpring: null, message: "Enter how far the O-ring moved." };
  let next;
  if (rec.isAir) {
    next = Math.round(springValue * Math.sqrt(pct / target));
    if (rec.maxPsi) next = Math.min(next, rec.maxPsi);
  } else {
    next = 25 * Math.round(springValue * pct / target / 25);
  }
  const tooMuch = pct > hi;
  const action = rec.isAir
    ? `${tooMuch ? "Add" : "Let out"} about ${Math.abs(next - springValue)} psi (to ${next} psi), cycle it 10×, then re-check.`
    : `Try a ${next} lb/in spring${tooMuch ? "" : " (or back off preload)"}, then re-check.`;
  return { percent: pct, status: tooMuch ? "tooMuch" : "tooLittle", suggestedSpring: next,
           message: `${shown}% sag — ${tooMuch ? "too much" : "too little"} (aim for ${Math.trunc(lo)}–${Math.trunc(hi)}%). ${action}` };
}

// ---------------------------------------------------------------- coil springs

function coilOptions(rate, targetSag) {
  return [-50, -25, 0, 25, 50].map((d) => ({ rate: rate + d, sagPercent: targetSag * rate / (rate + d), isRecommended: d === 0 }))
    .filter((o) => o.rate > 0);
}
function coilLabel(rate, strokeMm) {
  const inches = strokeMm / 25.4;
  const s = [1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.25, 3.5].find((x) => x + 0.001 >= inches) || Math.ceil(inches * 4) / 4;
  return `${rate} × ${Number.isInteger(s) ? s.toFixed(1) : String(s)}″`;
}

// ---------------------------------------------------------------- pre-ride check

function checklist(fork, shock) {
  const out = [];
  if (fork) out.push({ id: "fork", title: fork.isAir ? `Fork at ${fork.springValue} psi` : `Fork spring ${fork.springValue} lb/in`,
                       detail: "Check with a shock pump; wipe the stanchions and dust seals." });
  if (shock) out.push({ id: "shock", title: shock.isAir ? `Shock at ${shock.springValue} psi` : `Shock spring ${shock.springValue} lb/in`,
                        detail: "Check pressure (or preload) and wipe the shaft." });
  if (fork || shock) out.push({ id: "sag", title: "Sag checked", detail: "Push the O-rings down, get on in your riding position, measure." });
  const tires = [fork && `${fork.tirePsi} psi front`, shock && `${shock.tirePsi} psi rear`].filter(Boolean).join(" · ");
  return out.concat([
    { id: "tires", title: tires ? `Tires: ${tires}` : "Tire pressure", detail: "Check cold, before the ride. Look for cuts and sealant leaks." },
    { id: "axles", title: "Axles and thru-bolts tight", detail: "Front and rear axles, levers closed." },
    { id: "brakes", title: "Brakes bite", detail: "Firm levers, pads not worn to the metal, rotors clean." },
    { id: "headset", title: "No headset play", detail: "Front brake on, rock the bike — no clunk." },
    { id: "cockpit", title: "Stem and bars tight", detail: "Bars straight, no slipping or creaks." },
    { id: "dropper", title: "Dropper works", detail: "Full drop and full return." },
    { id: "drivetrain", title: "Chain lubed, shifting clean", detail: "Run through the gears." },
    { id: "kit", title: "Kit packed", detail: "Helmet, pump, tube or plugs, multi-tool, water." },
  ]);
}

// ---------------------------------------------------------------- step by step

function adjusterLocation(click, isFork) {
  let ring = "";
  if (click.key === "hsr" || click.key === "hsc") ring = " It's usually the outer, larger dial.";
  else if (click.key === "lsr" || click.key === "lsc") ring = " It's usually the inner, smaller knob.";
  if (click.isRebound) {
    return (isFork ? "Find the rebound adjuster (usually red) at the bottom of the right fork leg."
                   : "Find the rebound adjuster (usually red) on the shock body or eyelet.") + ring;
  }
  return (isFork ? "Find the compression adjuster (usually blue) on top of the right fork leg."
                 : "Find the compression adjuster (usually blue) on the shock's body or reservoir.") + ring;
}

function setupSteps(rec, isFork, ran) {
  ran = ran || { clicks: {} };
  const out = [];
  const spring = ran.springValue != null ? ran.springValue : rec.springValue;
  if (rec.isAir) {
    out.push({ title: "Air pressure", text: `Screw a shock pump onto the ${isFork ? "air valve on top of the left fork leg" : "shock's air valve"} and pump to ${spring} psi. Compress the ${isFork ? "fork" : "bike"} 10–20 times to even out the chambers, then re-check and top up to ${spring} psi.` });
  } else {
    out.push({ title: "Spring", text: `Fit a ${spring} lb/in coil spring. Wind the preload collar on until the spring just stops rattling, then add no more than 1–2 turns.` });
  }
  const tokens = ran.tokens != null ? ran.tokens : rec.tokens;
  if (tokens != null) {
    const fit = tokens === 0 ? "remove all volume spacers" : `fit ${tokens} volume spacer${tokens === 1 ? "" : "s"}`;
    out.push({ title: "Volume spacers", text: isFork
      ? `Let all the air out first. Unscrew the top cap on the left leg, ${fit} under the cap, screw it back in and re-pump to ${spring} psi.`
      : `Let all the air out first. Remove the air can as your shock's manual shows, ${fit}, refit it and re-pump to ${spring} psi.` });
  }
  for (const c of rec.clicks) {
    const n = ran.clicks && ran.clicks[c.key] != null ? ran.clicks[c.key] : c.value;
    const start = c.fromClosed
      ? `Turn it clockwise until it gently stops (fully closed), then count ${n} click${n === 1 ? "" : "s"} back out, anti-clockwise.`
      : `Turn it anti-clockwise until it stops (fully open), then count ${n} click${n === 1 ? "" : "s"} in, clockwise.`;
    const range = c.rangeText ? ` The maker's range is ${c.rangeText}.` : "";
    out.push({ title: `${c.label} · ${n} ${c.direction}`, text: `${adjusterLocation(c, isFork)} ${start}${range}` });
  }
  out.push({ title: "Check sag", text: `Sit on the bike in your riding position. Sag should be about ${fixed(rec.sagMm, 0)} mm (${rec.sagPercent}%). Too much? Add pressure. Too little? Let some out.` });
  return out;
}

const Engine = {
  LB_PER_KG, FRAME_SIZES, STYLES, STYLE_LABELS, STYLE_SHORT, QUALITY_TITLES, PACK_TITLES, TERRAIN_TITLES,
  PRIORITY_TITLES, WHEEL_TITLES, TIRE_WIDTH_TITLES, SYMPTOMS,
  riderInput, calculate, recommendedFrameSize, specsUrl, differences, troubleshoot, symptomApplies, applyFix,
  sagCheck, coilOptions, coilLabel, checklist, setupSteps,
};
if (typeof module !== "undefined") module.exports = Engine;
if (typeof window !== "undefined") window.Engine = Engine;
