// Bike drawing as SVG — the same geometry as BikeIllustration.swift.
// Six full-suspension looks (picked by the bike's place in the rack) plus a hardtail; the frame is
// painted with the rider's colour and the rear shock is drawn as an air can or a coil to match.

const BIKE_LOOKS = [
  { name: "Enduro", colors: ["#F4F6F8", "#C3C9D2", "#8A929E"], accent: "#FF7A1A", tube: 1, st: [132, 44], tt: [[136, 58], [224, 44]], ht: [[222, 36], [232, 72]], dt: [229, 68], ss: [124, 66], rocker: [[120, 64], [138, 60], [134, 72]], shock: [[134, 70], [176, 97]], style: "coil", inside: false, sp: [127, 24], rb: [196, 78], rp: [[185, 82], [168, 88]], dual: false, ebike: false },
  { name: "Trail", colors: ["#A7F3E9", "#2DD4BF", "#0F766E"], accent: "#FACC15", tube: 1, st: [134, 40], tt: [[137, 54], [224, 44]], ht: [[222, 36], [232, 72]], dt: [229, 68], ss: [128, 60], rocker: [[124, 58], [150, 53], [146, 66]], shock: [[147, 62], [159, 104]], style: "air", inside: true, sp: [129, 20], rb: [192, 68], rp: [[181, 72], [158, 84]], dual: false, ebike: false },
  { name: "Downhill", colors: ["#E4DBFF", "#A78BFA", "#6D28D9"], accent: "#FACC15", tube: 1.1, st: [138, 54], tt: [[140, 64], [222, 50]], ht: [[218, 32], [232, 74]], dt: [228, 70], ss: [138, 84], rocker: [[134, 82], [152, 77], [148, 91]], shock: [[149, 83], [194, 79]], style: "piggy", inside: true, sp: [135, 40], rb: [186, 38], rp: [[182, 50], [176, 76]], dual: true, ebike: false },
  { name: "XC race", colors: ["#FECACA", "#EF4444", "#991B1B"], accent: "#F4F6F8", tube: 0.78, st: [130, 38], tt: [[134, 52], [225, 46]], ht: [[224, 40], [232, 72]], dt: [229, 68], ss: [128, 58], rocker: [[125, 56], [140, 52], [137, 62]], shock: [[139, 58], [178, 66]], style: "air", inside: true, sp: [125, 14], rb: [180, 30], rp: [[177, 42], [162, 60]], dual: false, ebike: false },
  { name: "e-MTB", colors: ["#E2E8F0", "#64748B", "#334155"], accent: "#A3E635", tube: 1.15, st: [134, 42], tt: [[137, 56], [224, 44]], ht: [[222, 36], [232, 72]], dt: [229, 68], ss: [128, 60], rocker: [[124, 58], [150, 53], [146, 66]], shock: [[147, 62], [156, 100]], style: "air", inside: true, sp: [129, 22], rb: [190, 62], rp: [[180, 68], [155, 82]], dual: false, ebike: true },
  { name: "Freeride", colors: ["#BAE6FD", "#38BDF8", "#0369A1"], accent: "#FACC15", tube: 1.05, st: [136, 50], tt: [[140, 62], [224, 46]], ht: [[220, 34], [232, 72]], dt: [228, 69], ss: [136, 80], rocker: [[132, 78], [150, 72], [146, 86]], shock: [[147, 80], [192, 76]], style: "piggy", inside: true, sp: [132, 34], rb: [186, 34], rp: [[182, 46], [172, 74]], dual: false, ebike: false },
];
const HARDTAIL = { name: "Hardtail", colors: ["#F4F6F8", "#C3C9D2", "#8A929E"], accent: "#FF7A1A", tube: 0.92, st: [133, 40], tt: [[136, 52], [224, 44]], ht: [[222, 36], [232, 72]], dt: [229, 68], ss: [137, 56], sp: [128, 18], hardtail: true, dual: false, ebike: false };

/** Twelve factory-style paints: highlight, body, shadow. */
const PAINTS = {
  black: ["#6B7280", "#2A2D33", "#0E0F12"], raw: ["#F4F6F8", "#C3C9D2", "#8A929E"], white: ["#FFFFFF", "#EDEFF2", "#BFC4CC"],
  red: ["#FECACA", "#EF4444", "#991B1B"], orange: ["#FED7AA", "#F97316", "#9A3412"], yellow: ["#FEF08A", "#FACC15", "#A16207"],
  lime: ["#D9F99D", "#84CC16", "#3F6212"], green: ["#BBF7D0", "#22C55E", "#166534"], teal: ["#A7F3E9", "#2DD4BF", "#0F766E"],
  blue: ["#BAE6FD", "#3B82F6", "#1E3A8A"], purple: ["#E4DBFF", "#A78BFA", "#6D28D9"], pink: ["#FBCFE8", "#EC4899", "#9D174D"],
};
const PAINT_TITLES = { black: "Black", raw: "Raw silver", white: "White", red: "Red", orange: "Orange", yellow: "Yellow",
  lime: "Lime", green: "Green", teal: "Teal", blue: "Blue", purple: "Purple", pink: "Pink" };
/** The colour each look comes in, so an unpainted bike keeps its look. */
const DEFAULT_PAINT = ["raw", "teal", "purple", "red", "black", "blue"];

let uidCounter = 0;

/**
 * opts: { variant, hardtail, paint, shockSpring: "air"|"coil"|null, hasFork, hasShock, badges, dark }
 * Returns an SVG string. Frame, fork and shock sit in <g class="sprung"> so CSS can bounce them.
 */
function bikeSVG(opts) {
  const o = Object.assign({ variant: 0, hardtail: false, paint: null, shockSpring: null, hasFork: true, hasShock: true, badges: true, dark: true }, opts);
  const look = o.hardtail ? HARDTAIL : BIKE_LOOKS[((o.variant % 6) + 6) % 6];
  const g = Object.assign({}, look);
  if (o.paint && PAINTS[o.paint]) {
    g.colors = PAINTS[o.paint];
    g.accent = ["yellow", "orange", "lime", "white"].includes(o.paint) ? "#1F242C" : "#F4F6F8";
  }
  let style = g.style;
  if (o.shockSpring === "air") style = "air";
  else if (o.shockSpring === "coil") style = g.style === "air" ? "coil" : g.style;
  const showShock = o.hasShock && !g.hardtail;
  const uid = "b" + (++uidCounter);
  const dark = o.dark;
  const out = [];
  const f2 = (n) => n.toFixed(2);
  const L = (pts, color, w, dash, op = 1) =>
    `<path d="M${pts.map((p) => f2(p[0]) + " " + f2(p[1])).join(" L")}" fill="none" stroke="${color}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"${dash ? ` stroke-dasharray="${dash}"` : ""} opacity="${op}"/>`;
  const C = (x, y, r, color, w, dash, op = 1) =>
    `<circle cx="${f2(x)}" cy="${f2(y)}" r="${r}" fill="none" stroke="${color}" stroke-width="${w}"${dash ? ` stroke-dasharray="${dash}"` : ""} opacity="${op}"/>`;
  const F = (x, y, r, color) => `<circle cx="${f2(x)}" cy="${f2(y)}" r="${r}" fill="${color}"/>`;

  const stops = dark ? g.colors : [g.colors[1], g.colors[1], g.colors[2]];
  out.push(`<defs><linearGradient id="fr${uid}" gradientUnits="userSpaceOnUse" x1="110" y1="20" x2="240" y2="130"><stop offset="0" stop-color="${stops[0]}"/><stop offset=".5" stop-color="${stops[1]}"/><stop offset="1" stop-color="${stops[2]}"/></linearGradient>`
    + `<linearGradient id="gd${uid}" gradientUnits="userSpaceOnUse" x1="231" y1="70" x2="250" y2="96"><stop offset="0" stop-color="#F7D774"/><stop offset="1" stop-color="#C8941F"/></linearGradient>`
    + `<linearGradient id="lw${uid}" gradientUnits="userSpaceOnUse" x1="244" y1="88" x2="270" y2="112"><stop offset="0" stop-color="#FF8A3D"/><stop offset="1" stop-color="#E8541E"/></linearGradient>`
    + `<filter id="gl${uid}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="4"/></filter>`
    + `<filter id="sh${uid}" x="-20%" y="-200%" width="140%" height="500%"><feGaussianBlur stdDeviation="4"/></filter></defs>`);
  const FR = `url(#fr${uid})`, GD = `url(#gd${uid})`, LW = `url(#lw${uid})`;
  out.push(`<ellipse cx="170" cy="166" rx="140" ry="6" fill="black" opacity="${dark ? 0.45 : 0.18}" filter="url(#sh${uid})"/>`);

  const tube = (a, b, shade, w) => {
    out.push(L([a, b], "black", w + 1.6, null, dark ? 0.45 : 0.28));
    out.push(L([a, b], shade, w));
    out.push(L([[a[0], a[1] - w * 0.22], [b[0], b[1] - w * 0.22]], "white", Math.max(0.8, w * 0.18), null, 0.35));
  };
  const wheel = (cx, cy, ang) => {
    out.push('<g class="wheel">');
    out.push(C(cx, cy, 49, "#0E1014", 11), C(cx, cy, 52.6, "#2B3039", 4, "3.2 3.4"), C(cx, cy, 49, "#262B33", 7),
      C(cx, cy, 45.5, "#3A404B", 0.8), C(cx, cy, 43, "#5B6370", 3.2), C(cx, cy, 41.2, "#2E333C", 1));
    for (let i = 0; i < 28; i++) {
      const a = i * Math.PI / 14, h = i % 2 === 0 ? 4 : -4;
      out.push(L([[cx + h * Math.cos(a + 1.2), cy + h * Math.sin(a + 1.2)], [cx + 40.5 * Math.cos(a), cy + 40.5 * Math.sin(a)]], "#7A828E", 0.7, null, 0.7));
    }
    out.push(C(cx, cy, 15, "#B9C0CA", 2.6), C(cx, cy, 13.2, "#6B7280", 1.2, "1.4 2.2"), C(cx, cy, 9.5, "#8A929E", 1.2, "3 3"),
      F(cx, cy, 5.5, "#1F242C"), F(cx, cy, 3.2, "#D6DBE2"));
    const px = cx + 15 * Math.cos(ang), py = cy + 15 * Math.sin(ang), deg = (ang + Math.PI / 2) * 180 / Math.PI;
    out.push(`<g transform="translate(${f2(px)} ${f2(py)}) rotate(${deg.toFixed(1)})"><rect x="-5" y="-2.6" width="10" height="5.2" rx="1.8" fill="#2A3039"/><rect x="-3.6" y="-1.2" width="7.2" height="2.4" rx="1" fill="#8A929E"/></g>`);
    out.push("</g>");
  };
  const rear = [70, 112], front = [270, 112], bb = [152, 122];
  wheel(70, 112, -0.9); wheel(270, 112, -2.3);
  out.push(C(70, 112, 9, "#8A929E", 2.2, "1.6 1"), C(70, 112, 5.5, "#6B7280", 1.6, "1.2 1"), L([[72, 116], [76, 130], [71, 136]], "#2A3039", 3),
    F(76, 129, 2.4, "#8A929E"), F(71, 136, 2.4, "#8A929E"),
    L([[152, 110], [70, 103]], "#4B525D", 1.7, "2 1.4"), L([[152, 134], [71, 136]], "#4B525D", 1.7, "2 1.4"));

  out.push(`<g class="sprung${g.hardtail ? " pivot" : ""}">`);
  const t = g.tube;
  tube(rear, [146, 120], FR, 7 * t); tube(rear, g.ss, FR, 5.5 * t);
  out.push(L([g.ss, [84, 98]], "#111318", 1.1));

  const shock = () => {
    const a = g.shock[0], b = g.shock[1];
    const dx = b[0] - a[0], dy = b[1] - a[1], ln = Math.hypot(dx, dy), nx = -dy / ln, ny = dx / ln;
    const at = (u, off = 0) => [a[0] + dx * u + nx * off, a[1] + dy * u + ny * off];
    out.push(L([at(0.05), at(0.95)], "#3A404B", 9), L([at(0.55), at(0.95)], "#D6DBE2", 3.2));
    if (style === "air") {
      out.push(L([at(0.08), at(0.58)], "#1F242C", 10), L([at(0.1), at(0.56)], "#FACC15", 7.4), L([at(0.12, -2.2), at(0.54, -2.2)], "white", 1.2, null, 0.45));
    } else {
      out.push(L([at(0.06), at(0.5)], "#2A3039", 7));
      const coil = []; for (let i = 0; i <= 10; i++) coil.push(at(0.14 + i * 0.075, i % 2 === 0 ? 5 : -5));
      out.push(L(coil, "#FACC15", 2.6), L([at(0.12, -5.5), at(0.12, 5.5)], "#8A929E", 2.2));
      if (style === "piggy") {
        const r1 = at(0.12, -9), r2 = at(0.42, -9);
        out.push(L([r1, r2], "#1F242C", 6.5), L([r1, r2], "#8A929E", 4), F(r1[0], r1[1], 2.4, "#FF7A1A"));
      }
    }
    for (const p of [a, b]) out.push(`<circle cx="${p[0]}" cy="${p[1]}" r="3.8" fill="#1A1E25" stroke="#FACC15" stroke-width="2"/>`);
  };
  const tri = () => {
    tube(bb, g.st, FR, 8 * t);
    if (g.ebike) {
      tube(bb, g.dt, FR, 17);
      const a = [bb[0] + 14, bb[1] - 10], b = [g.dt[0] - 12, g.dt[1] + 9];
      out.push(L([a, b], "#1F242C", 8), L([a, b], g.accent, 2.2, null, 0.85));
    } else {
      tube(bb, g.dt, FR, 11 * t);
      out.push(L([[bb[0] + 26, bb[1] - 18], [bb[0] + 46, bb[1] - 32]], g.accent, 2.4 * t, null, 0.9));
    }
    tube(g.tt[0], g.tt[1], FR, 7.5 * t); tube(g.ht[0], g.ht[1], FR, 11);
    out.push(F((g.ht[0][0] + g.ht[1][0]) / 2, (g.ht[0][1] + g.ht[1][1]) / 2, 2.6, g.accent));
    const h0 = g.ht[0];
    out.push(`<path d="M${h0[0] + 2} ${h0[1] - 6} Q${h0[0] - 14} ${h0[1] - 6} ${h0[0] - 8} ${h0[1] + 10}" fill="none" stroke="#111318" stroke-width="1.1"/>`);
  };
  if (g.hardtail) tri();
  else {
    if (!g.inside && showShock) shock();
    tri();
    if (g.inside && showShock) shock();
    const r = g.rocker;
    out.push(`<path d="M${r[0][0]} ${r[0][1]} L${r[1][0]} ${r[1][1]} L${r[2][0]} ${r[2][1]} Z" fill="#2A3039" stroke="${FR}" stroke-width="3.2" stroke-linejoin="round"/>`);
    r.forEach((p) => out.push(F(p[0], p[1], 1.6, "#C3C9D2")));
  }
  if (g.ebike) out.push(`<rect x="${bb[0] - 16}" y="${bb[1] - 14}" width="30" height="24" rx="7" fill="#1F242C" stroke="${g.accent}" stroke-opacity=".7" stroke-width="1.2"/>`);
  const crown = [231, 70];
  if (o.hasFork) {
    if (g.dual) {
      const top = g.ht[0];
      out.push(L([[top[0] + 6, top[1] - 2], crown], GD, 5), L([[top[0] - 4, top[1] + 1], [top[0] + 12, top[1] - 3]], "#1F242C", 5));
    }
    out.push(L([crown, [249, 94]], GD, 7), L([[228, 68], [236, 72]], "#1F242C", 6), L([[244, 88], front], "#1F242C", 12), L([[244, 88], front], LW, 8),
      L([[242, 86], [247, 92]], "#111318", 3), F(270, 112, 4.2, "#111318"), F(270, 112, 2, "#C3C9D2"));
  } else {
    tube(crown, front, FR, 6);
  }
  const ht = g.ht[0];
  out.push(L([ht, [ht[0] - 4, ht[1] - 8], [ht[0] + 10, ht[1] - 11]], "#2A3039", 5), L([[ht[0] + 6, ht[1] - 11], [ht[0] + 24, ht[1] - 14]], "#C3C9D2", 4),
    L([[ht[0] + 19, ht[1] - 13], [ht[0] + 27, ht[1] - 14]], "#111111", 5.5), L([[ht[0] + 15, ht[1] - 12], [ht[0] + 21, ht[1] - 6]], "#3A404B", 1.6));
  const st = g.st, sp = g.sp;
  out.push(L([st, sp], "#1F242C", 6), L([[st[0] - 0.8, st[1] - 3], [st[0] - 3.8, st[1] - 15]], "#9AA1AC", 3), L([[st[0] + 3.5, st[1] + 1], [st[0] - 3.5, st[1] - 1]], g.accent, 2.4));
  out.push(`<path d="M${sp[0] - 19} ${sp[1] - 2} Q${sp[0] - 1} ${sp[1] - 9} ${sp[0] + 15} ${sp[1] - 2} L${sp[0] + 5} ${sp[1] + 1} Q${sp[0] - 7} ${sp[1] - 2} ${sp[0] - 17} ${sp[1] + 1} Z" fill="#0E1014"/>`);
  const pa = 1.05, pdl = [bb[0] + 22 * Math.cos(pa), bb[1] + 22 * Math.sin(pa)];
  out.push(C(152, 122, 12, "#7A828E", 2.6, "1.4 1"), C(152, 122, 9.5, "#3A404B", 2), F(152, 122, 4.6, "#C3C9D2"), L([bb, pdl], "#1F242C", 5),
    `<rect x="${f2(pdl[0] - 7)}" y="${f2(pdl[1] - 2)}" width="14" height="4.5" rx="1.5" fill="#3A404B"/>`);
  out.push("</g>");

  if (o.badges) {
    const badge = (x, y, color, label, end) =>
      `<g class="badge" data-end="${end}" role="button" tabindex="0" aria-label="Tune the ${end === "fork" ? "fork" : "rear shock"}">`
      + `<circle cx="${x}" cy="${y}" r="13" fill="${color}" filter="url(#gl${uid})" opacity=".7"/><circle cx="${x}" cy="${y}" r="13" fill="${color}" stroke="white" stroke-opacity=".55"/>`
      + `<text x="${x}" y="${y + 4.6}" font-size="13" font-weight="900" text-anchor="middle" font-family="system-ui,sans-serif" fill="black">${label}</text>`
      + `<circle cx="${x}" cy="${y}" r="20" fill="transparent"/></g>`;
    if (o.hasFork) out.push(L([[276, 60], [252, 84]], "#FF7A1A", 1.5, "2 2"), badge(286, 54, "#FF7A1A", "F", "fork"));
    if (showShock) out.push(L(g.rp, "#FACC15", 1.5, "2 2"), badge(g.rb[0], g.rb[1], "#FACC15", "R", "shock"));
  }
  const what = g.hardtail ? "hardtail" : `${g.name} full-suspension`;
  const label = `${o.paint ? PAINT_TITLES[o.paint] + " " : ""}${what} mountain bike`;
  return `<svg class="bike-svg" viewBox="0 0 340 176" role="img" aria-label="${label}">${out.join("")}</svg>`;
}

window.Bike = { bikeSVG, PAINTS, PAINT_TITLES, DEFAULT_PAINT };
