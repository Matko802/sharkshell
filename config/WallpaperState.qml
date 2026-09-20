pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: root

  property string path: ""
  property string lockPath: ""

  readonly property string effectiveLockPath: lockPath !== "" ? lockPath : path

  property real positionX: 0.5
  property real positionY: 0.5
  property string position: "center"

  property real lockPositionX: 0.5
  property real lockPositionY: 0.5
  property string lockPosition: "center"

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
  }

  onLockPositionChanged: {
    var p = String(lockPosition).toLowerCase().replace(/[-_ ]/g, "");
    function setL(x, y) {
      root.lockPositionX = x;
      root.lockPositionY = y;
    }
    if (p === "center" || p === "middle") setL(0.5, 0.5);
    else if (p === "top" || p === "topcenter") setL(0.5, 0.0);
    else if (p === "bottom" || p === "bottomcenter") setL(0.5, 1.0);
    else if (p === "left" || p === "centerleft") setL(0.0, 0.5);
    else if (p === "right" || p === "centerright") setL(1.0, 0.5);
    else if (p === "topleft") setL(0.0, 0.0);
    else if (p === "topright") setL(1.0, 0.0);
    else if (p === "bottomleft") setL(0.0, 1.0);
    else if (p === "bottomright") setL(1.0, 1.0);
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

  FileView {
    id: lockFile

    path: Quickshell.env("HOME") + "/.cache/quickshell-lock-wallpaper"
    watchChanges: true
    printErrors: false
    onLoaded: {
      const p = text().trim()
      root.lockPath = p
    }
    onFileChanged: reload()
  }

  FileView {
    id: lockPosXFile

    path: Quickshell.env("HOME") + "/.cache/quickshell-lock-wallpaper-posx"
    watchChanges: true
    printErrors: false
    onLoaded: {
      const t = text().trim()
      if (t !== "")
        root.lockPositionX = root.clamp01(t)
    }
    onFileChanged: reload()
  }

  FileView {
    id: lockPosYFile

    path: Quickshell.env("HOME") + "/.cache/quickshell-lock-wallpaper-posy"
    watchChanges: true
    printErrors: false
    onLoaded: {
      const t = text().trim()
      if (t !== "")
        root.lockPositionY = root.clamp01(t)
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
    posXFile.setText(String(root.positionX))
    posYFile.setText(String(root.positionY))
  }

  function setLock(p) {
    root.lockPath = p
    lockFile.setText(p)
  }

  function clearLock() {
    root.lockPath = ""
    lockFile.setText("")
  }

  function setLockPosition(x, y) {
    root.lockPosition = "custom"
    root.lockPositionX = root.clamp01(x)
    root.lockPositionY = root.clamp01(y)
    lockPosXFile.setText(String(root.lockPositionX))
    lockPosYFile.setText(String(root.lockPositionY))
  }

  function setLockPreset(name) {
    root.lockPosition = name
    lockPosXFile.setText(String(root.lockPositionX))
    lockPosYFile.setText(String(root.lockPositionY))
  }

  function nearestPreset() {
    var x = root.positionX, y = root.positionY;
    function near(v) {
      if (v < 0.25) return 0;
      if (v > 0.75) return 2;
      return 1;
    }
    var nx = near(x), ny = near(y);
    function close(v) {
      return v < 0.05 || (v > 0.45 && v < 0.55) || v > 0.95;
    }
    if (!close(x) || !close(y)) return "custom";
    return [["topLeft", "topCenter", "topRight"], ["centerLeft", "center", "centerRight"], ["bottomLeft", "bottomCenter", "bottomRight"]][ny][nx];
  }

  function nearestLockPreset() {
    var x = root.lockPositionX, y = root.lockPositionY;
    function near(v) {
      if (v < 0.25) return 0;
      if (v > 0.75) return 2;
      return 1;
    }
    var nx = near(x), ny = near(y);
    function close(v) {
      return v < 0.05 || (v > 0.45 && v < 0.55) || v > 0.95;
    }
    if (!close(x) || !close(y)) return "custom";
    return [["topLeft", "topCenter", "topRight"], ["centerLeft", "center", "centerRight"], ["bottomLeft", "bottomCenter", "bottomRight"]][ny][nx];
  }
}
