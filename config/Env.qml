pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: root

  property string compositor: Quickshell.env("SHARKSHELL_COMPOSITOR") || ""
  readonly property bool hasNiri: root.compositor === "niri"
  readonly property bool hasMango: root.compositor === "mango"
  readonly property string soundRelPath: "sounds/freedesktop/stereo/audio-volume-change.oga"
  readonly property string logoutScript:
    "if command -v niri >/dev/null 2>&1; then niri msg action quit --skip-confirmation; "
    + "elif command -v mmsg >/dev/null 2>&1; then mmsg dispatch quit 2>/dev/null; "
    + "elif command -v loginctl >/dev/null 2>&1; then loginctl terminate-user \"\" 2>/dev/null; "
    + "elif command -v systemctl >/dev/null 2>&1; then systemctl --user exit 2>/dev/null; fi"

  Process {
    running: root.compositor === ""
    command: ["sh", "-c",
      "if command -v niri >/dev/null 2>&1; then echo niri"
      + "; elif command -v mango >/dev/null 2>&1; then echo mango"
      + "; elif command -v swaymsg >/dev/null 2>&1; then echo sway"
      + "; elif command -v hyprctl >/dev/null 2>&1; then echo hyprland"
      + "; else echo none; fi"]
    stdout: SplitParser {
      onRead: line => root.compositor = String(line).trim() || "none"
    }
  }

  function switchLayout() {
    if (root.compositor === "niri")
      Quickshell.execDetached(["sh", "-c", "niri msg action switch-layout next"])
  }

  function playVolumeSound() {
    Quickshell.execDetached(["sh", "-c",
      "d=\"$XDG_DATA_DIRS:/usr/share:/usr/local/share:/run/current-system/sw/share\"; "
      + "oifs=\"$IFS\"; IFS=':'; for x in $d; do "
      + "p=\"$x/" + root.soundRelPath + "\"; "
      + "if [ -f \"$p\" ]; then "
      + "if command -v pw-play >/dev/null 2>&1; then exec pw-play \"$p\" 2>/dev/null; fi; "
      + "if command -v paplay >/dev/null 2>&1; then exec paplay \"$p\" 2>/dev/null; fi; "
      + "fi; "
      + "done; IFS=\"$oifs\""])
  }
}