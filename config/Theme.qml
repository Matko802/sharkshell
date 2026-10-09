pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: root

  property string fontFamily: Quickshell.env("QUICKSHELL_FONT") || "DepartureMono Nerd Font"

  readonly property int spacingXS: 4
  readonly property int spacing6: 6
  readonly property int spacingS: 8
  readonly property int spacingM: 12
  readonly property int spacingL: 16
  readonly property int paddingXS: 4
  readonly property int paddingS: 8
  readonly property int paddingM: 12
  readonly property int paddingL: 16
  readonly property int rounding: 0
  readonly property int radius: 0
  readonly property int animFast: 90
  readonly property int animDefault: 140
  readonly property int animSlow: 200
  readonly property int themeTransition: 600
  readonly property real surfaceAlpha: TransparencyState.transparent ? 1.0 - TransparencyState.amount : 1.0
  readonly property int easingOut: Easing.OutCubic
  readonly property int easingIn: Easing.InCubic
  readonly property int easingDefault: Easing.OutCubic

  property color bgBase: DynamicTheme.bg
  property color bg: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, root.surfaceAlpha)
  Behavior on bg { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
  property color bgAltBase: DynamicTheme.bgAlt
  property color bgAlt: Qt.rgba(bgAltBase.r, bgAltBase.g, bgAltBase.b, root.surfaceAlpha)
  Behavior on bgAlt { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
  property color fg: DynamicTheme.fg
  Behavior on fg { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
  property color outline: DynamicTheme.outline
  Behavior on outline { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
  property color border: DynamicTheme.border
  Behavior on border { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
  property color borderStrong: DynamicTheme.borderStrong
  Behavior on borderStrong { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
  property color muted: DynamicTheme.muted
  Behavior on muted { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
  property color muted2: DynamicTheme.muted2
  Behavior on muted2 { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
  property color muted3: DynamicTheme.muted3
  Behavior on muted3 { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
  readonly property color hover: "#33ffffff"
  readonly property color match: DynamicTheme.role("tertiary", "#cb4b16")
  readonly property color onSelect: "#586e75"
  readonly property color error: "#ff5555"
  property color lockBgBase: TransparencyState.transparent ? DynamicTheme.bg : "#000000"
  property color lockBg: Qt.rgba(lockBgBase.r, lockBgBase.g, lockBgBase.b, root.surfaceAlpha)
  Behavior on lockBg { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
  FontLoader {
    id: materialLoader
    source: "fonts/material-icons.ttf"
  }
  FontLoader {
    id: outlinedLoader
    source: "fonts/material-icons-outlined.otf"
  }
  readonly property string materialFontFamily: materialLoader.name || "Material Icons"
  readonly property string outlinedFontFamily: outlinedLoader.name || "Material Icons Outlined"
}
