.pragma library


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
