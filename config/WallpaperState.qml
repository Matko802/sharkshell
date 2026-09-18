pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: root

  property string path: ""

  // 0.0 = left/top, 0.5 = center, 1.0 = right/bottom.
  // Used when the wallpaper is bigger than the screen (cover/crop):
  // the overflow is slid so the chosen part stays visible.
  property real positionX: 0.5
  property real positionY: 0.5
  // Preset name: center, top, bottom, left, right,
  // topLeft, topCenter, topRight, centerLeft, centerRight,
  // bottomLeft, bottomCenter, bottomRight, or custom.
  property string position: "center"

  function clamp01(v) {
    v = parseFloat(v);
    if (isNaN(v)) return 0.5;
    return Math.min(1, Math.max(0, v));
  }

  onPositionChanged: {
    var p = String(position).toLowerCase().replace(/[-_ ]/g, "");
    function set(x, y) {
      root.positionX = x;
      root.positionY = y;
    }
    if (p === "center" || p === "middle") set(0.5, 0.5);
    else if (p === "top" || p === "topcenter") set(0.5, 0.0);
    else if (p === "bottom" || p === "bottomcenter") set(0.5, 1.0);
    else if (p === "left" || p === "centerleft") set(0.0, 0.5);
    else if (p === "right" || p === "centerright") set(1.0, 0.5);
    else if (p === "topleft") set(0.0, 0.0);
    else if (p === "topright") set(1.0, 0.0);
    else if (p === "bottomleft") set(0.0, 1.0);
    else if (p === "bottomright") set(1.0, 1.0);
    // "custom" or unknown: leave X/Y alone
  }

  FileView {
    id: stateFile

    path: Quickshell.env("HOME") + "/.cache/quickshell-wallpaper"
    watchChanges: true
    printErrors: false
    onLoaded: {
      const p = text().trim()
      if (p !== "")
        root.path = p
    }
    onFileChanged: reload()
  }

  FileView {
    id: posXFile

    path: Quickshell.env("HOME") + "/.cache/quickshell-wallpaper-posx"
    watchChanges: true
    printErrors: false
    onLoaded: {
      const t = text().trim()
      if (t !== "")
        root.positionX = root.clamp01(t)
    }
    onFileChanged: reload()
  }

  FileView {
    id: posYFile

    path: Quickshell.env("HOME") + "/.cache/quickshell-wallpaper-posy"
    watchChanges: true
    printErrors: false
    onLoaded: {
      const t = text().trim()
      if (t !== "")
        root.positionY = root.clamp01(t)
    }
    onFileChanged: reload()
  }

  function set(p) {
    root.path = p
    stateFile.setText(p)
  }

  function setPosition(x, y) {
    root.position = "custom"
    root.positionX = root.clamp01(x)
    root.positionY = root.clamp01(y)
    posXFile.setText(String(root.positionX))
    posYFile.setText(String(root.positionY))
  }

  function setPreset(name) {
    root.position = name
    // onPositionChanged updates X/Y synchronously above
    posXFile.setText(String(root.positionX))
    posYFile.setText(String(root.positionY))
  }

  // Nearest preset for picker highlight ("custom" if between stops)
  function nearestPreset() {
    var x = root.positionX, y = root.positionY;
    function near(v) {
      if (v < 0.25) return 0;
      if (v > 0.75) return 2;
      return 1;
    }
    var nx = near(x), ny = near(y);
    // only snap when actually close to a stop
    function close(v) {
      return v < 0.05 || (v > 0.45 && v < 0.55) || v > 0.95;
    }
    if (!close(x) || !close(y)) return "custom";
    return [["topLeft", "topCenter", "topRight"], ["centerLeft", "center", "centerRight"], ["bottomLeft", "bottomCenter", "bottomRight"]][ny][nx];
  }
}
