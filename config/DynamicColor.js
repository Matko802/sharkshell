function clamp01(v) {
  v = parseFloat(v);
  if (isNaN(v)) return 0;
  return Math.min(1, Math.max(0, v));
}

function toRgb(hex) {
  var h = String(hex || "").trim();
  if (h.charAt(0) === "#") h = h.slice(1);
  if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
  if (!/^[0-9a-fA-F]{6}$/.test(h)) return null;
  return {
    r: parseInt(h.slice(0, 2), 16),
    g: parseInt(h.slice(2, 4), 16),
    b: parseInt(h.slice(4, 6), 16)
  };
}

function toHex(r, g, b) {
  function c(v) {
    v = Math.round(Math.min(255, Math.max(0, v)));
    var s = v.toString(16);
    return s.length === 1 ? "0" + s : s;
  }
  return "#" + c(r) + c(g) + c(b);
}

function isValid(hex) {
  return toRgb(hex) !== null;
}

function validOr(hex, fallback) {
  return isValid(hex) ? String(hex) : fallback;
}

function mix(a, b, t) {
  var ca = toRgb(a), cb = toRgb(b);
  if (!ca) return String(b);
  if (!cb) return String(a);
  t = clamp01(t);
  return toHex(
    ca.r + (cb.r - ca.r) * t,
    ca.g + (cb.g - ca.g) * t,
    ca.b + (cb.b - ca.b) * t
  );
}

function shade(hex, amt) {
  amt = Math.min(1, Math.max(-1, parseFloat(amt) || 0));
  if (amt >= 0) return mix(hex, "#ffffff", amt);
  return mix(hex, "#000000", -amt);
}

function withAlpha(c, a) {
  var rgb = (typeof c === "string") ? toRgb(c) : null;
  if (!rgb && c && typeof c.r === "number")
    rgb = { r: Math.round(c.r * 255), g: Math.round(c.g * 255), b: Math.round(c.b * 255) };
  if (!rgb) return "#000000";
  return "rgba(" + rgb.r + "," + rgb.g + "," + rgb.b + "," + clamp01(a) + ")";
}

function toHsl(hex) {
  var c = toRgb(hex);
  if (!c) return null;
  var r = c.r / 255, g = c.g / 255, b = c.b / 255;
  var mx = Math.max(r, Math.max(g, b)), mn = Math.min(r, Math.min(g, b));
  var h = 0, s = 0, l = (mx + mn) / 2;
  if (mx !== mn) {
    var d = mx - mn;
    s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
    if (mx === r) h = (g - b) / d + (g < b ? 6 : 0);
    else if (mx === g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
    h /= 6;
  }
  return { h: h, s: s, l: l };
}

function fromHsl(h, s, l) {
  function hue(p, q, t) {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  }
  var r, g, b;
  if (s <= 0) {
    r = g = b = l;
  } else {
    var q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    var p = 2 * l - q;
    r = hue(p, q, h + 1 / 3);
    g = hue(p, q, h);
    b = hue(p, q, h - 1 / 3);
  }
  return toHex(r * 255, g * 255, b * 255);
}

function saturate(hex, amt) {
  var hsl = toHsl(hex);
  if (!hsl) return String(hex);
  amt = parseFloat(amt) || 0;
  hsl.s = clamp01(hsl.s * (1 + amt));
  return fromHsl(hsl.h, hsl.s, hsl.l);
}

function luminance(hex) {
  var c = toRgb(hex);
  if (!c) return 0;
  function lin(v) {
    v = v / 255;
    return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
  }
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

function contrastRatio(a, b) {
  var la = luminance(a), lb = luminance(b);
  var hi = Math.max(la, lb), lo = Math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

function setLightness(hex, targetL) {
  var hsl = toHsl(hex);
  if (!hsl) return String(hex);
  targetL = clamp01(targetL);
  return fromHsl(hsl.h, hsl.s, targetL);
}

function lightnessOf(hex) {
  var hsl = toHsl(hex);
  return hsl ? hsl.l : 0;
}

function saturationOf(hex) {
  var hsl = toHsl(hex);
  return hsl ? hsl.s : 0;
}

function vivid(hex, targetL, satAmt) {
  var hsl = toHsl(hex);
  if (!hsl) return String(hex);
  if (satAmt === undefined) satAmt = 0.8;
  if (targetL === undefined) targetL = 0.65;
  hsl.s = clamp01(hsl.s * (1 + satAmt) + satAmt * 0.15);
  if (saturationOf(hex) > 0.08 && hsl.s < 0.45) hsl.s = 0.45;
  return fromHsl(hsl.h, hsl.s, clamp01(targetL));
}

function ensureContrastOnDark(fg, bg, minRatio) {
  var l = lightnessOf(fg);
  var guard = 0;
  while (contrastRatio(fg, bg) < minRatio && guard < 20) {
    l += 0.05;
    if (l > 0.95) break;
    fg = setLightness(fg, l);
    guard++;
  }
  return fg;
}

function ensureContrastOnLight(fg, bg, minRatio) {
  var l = lightnessOf(fg);
  var guard = 0;
  while (contrastRatio(fg, bg) < minRatio && guard < 20) {
    l -= 0.05;
    if (l < 0.05) break;
    fg = setLightness(fg, l);
    guard++;
  }
  return fg;
}

function redness(hex) {
  var c = toRgb(hex);
  if (!c) return -1;
  return c.r - Math.max(c.g, c.b);
}

function greenness(hex) {
  var c = toRgb(hex);
  if (!c) return -1;
  return c.g - Math.max(c.r, c.b);
}

function blueness(hex) {
  var c = toRgb(hex);
  if (!c) return -1;
  return c.b - Math.max(c.r, c.g);
}

function yellowness(hex) {
  var c = toRgb(hex);
  if (!c) return -1;
  return Math.min(c.r, c.g) - c.b;
}

function magentaness(hex) {
  var c = toRgb(hex);
  if (!c) return -1;
  return Math.min(c.r, c.b) - c.g;
}

function cyanness(hex) {
  var c = toRgb(hex);
  if (!c) return -1;
  return Math.min(c.g, c.b) - c.r;
}

function pickExtreme(candidates, scoreFn) {
  var best = null, bestScore = -1e9;
  for (var i = 0; i < candidates.length; i++) {
    var c = candidates[i];
    if (!isValid(c)) continue;
    var s = scoreFn(c);
    if (s > bestScore) {
      bestScore = s;
      best = String(c);
    }
  }
  return best;
}

function pickDarkest(candidates) {
  var best = null, bestL = 1e9;
  for (var i = 0; i < candidates.length; i++) {
    var c = candidates[i];
    if (!isValid(c)) continue;
    var l = luminance(c);
    if (l < bestL) {
      bestL = l;
      best = String(c);
    }
  }
  return best;
}

function pickLightest(candidates) {
  var best = null, bestL = -1e9;
  for (var i = 0; i < candidates.length; i++) {
    var c = candidates[i];
    if (!isValid(c)) continue;
    var l = luminance(c);
    if (l > bestL) {
      bestL = l;
      best = String(c);
    }
  }
  return best;
}


function hueDeg(hex) {
  var hsl = toHsl(hex);
  if (!hsl) return 0;
  return hsl.h * 360;
}

function hueDist(a, b) {
  var d = Math.abs(a - b) % 360;
  return d > 180 ? 360 - d : d;
}

function closestByHue(candidates, targetHue, minSat) {
  if (minSat === undefined) minSat = 0.12;
  var best = null, bestScore = 1e9;
  for (var pass = 0; pass < 3; pass++) {
    best = null;
    bestScore = 1e9;
    for (var i = 0; i < candidates.length; i++) {
      var c = candidates[i];
      if (!isValid(c)) continue;
      var hsl = toHsl(String(c));
      if (!hsl) continue;
      if (pass === 0) {
        if (hsl.s < minSat || hsl.l < 0.18 || hsl.l > 0.90) continue;
      } else if (pass === 1) {
        if (hsl.l < 0.10 || hsl.l > 0.92) continue;
      }
      var d = hueDist(hsl.h * 360, targetHue);
      var score = d - hsl.s * 15;
      if (score < bestScore) {
        bestScore = score;
        best = String(c);
      }
    }
    if (best) return best;
  }
  return null;
}

function parseHistogramColors(text) {
  var out = [];
  var re = /#([0-9a-fA-F]{6})\b/g;
  var m;
  while ((m = re.exec(String(text || ""))) !== null) {
    var hex = ("#" + m[1]).toLowerCase();
    var dup = false;
    for (var i = 0; i < out.length; i++) {
      if (out[i] === hex) {
        dup = true;
        break;
      }
    }
    if (!dup) out.push(hex);
  }
  return out;
}

function closestByHueExcluding(candidates, targetHue, minSat, used) {
  var filtered = [];
  for (var i = 0; i < candidates.length; i++) {
    var skip = false;
    for (var j = 0; j < (used || []).length; j++) {
      if (String(candidates[i]).toLowerCase() === String(used[j]).toLowerCase()) {
        skip = true;
        break;
      }
    }
    if (!skip) filtered.push(candidates[i]);
  }
  var c = closestByHue(filtered, targetHue, minSat);
  if (c) return c;
  var best = null, bestScore = 1e9;
  for (var k = 0; k < filtered.length; k++) {
    var hsl = toHsl(String(filtered[k]));
    if (!hsl) continue;
    var minUsedDist = 360;
    for (var u = 0; u < (used || []).length; u++) {
      var uh = toHsl(String(used[u]));
      if (!uh) continue;
      var d = hueDist(hsl.h * 360, uh.h * 360);
      if (d < minUsedDist) minUsedDist = d;
    }
    if (minUsedDist < 30) continue;
    var score = hueDist(hsl.h * 360, targetHue) - hsl.s * 15;
    if (score < bestScore) {
      bestScore = score;
      best = String(filtered[k]);
    }
  }
  return best;
}
