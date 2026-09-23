
function shellQuote(value) {
  return "'" + String(value).replace(/'/g, "'\\''") + "'"
}

function fileUrl(path) {
  return "file://" + String(path).split("/").map(encodeURIComponent).join("/")
}

function clamp01(v) {
  return Math.min(1, Math.max(0, v))
}

function clampPct(v) {
  return Math.max(0, Math.min(100, v))
}
