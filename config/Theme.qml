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
  // dynamic theme crossfade (Noctalia-style smooth transition)
  readonly property int themeTransition: 600
  // transparency mode: surfaces go translucent, text/borders stay opaque
  readonly property real surfaceAlpha: TransparencyState.transparent ? 0.85 : 1.0
  readonly property int easingOut: Easing.OutCubic
  readonly property int easingIn: Easing.InCubic
  readonly property int easingDefault: Easing.OutCubic

  // Declarative defaults (used when DynamicTheme is off).
  // When DynamicTheme is on, colors follow the wallpaper with a
  // smooth animated transition.
  property color bgBase: DynamicTheme.enabled ? DynamicTheme.bg : "#000000"
  property color bg: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, root.surfaceAlpha)
  Behavior on bg { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
  property color bgAltBase: DynamicTheme.enabled ? DynamicTheme.bgAlt : "#0a0a0a"
  property color bgAlt: Qt.rgba(bgAltBase.r, bgAltBase.g, bgAltBase.b, root.surfaceAlpha)
  Behavior on bgAlt { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
  property color fg: DynamicTheme.enabled ? DynamicTheme.fg : "#ffffff"
  Behavior on fg { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
  property color outline: DynamicTheme.enabled ? DynamicTheme.outline : "#ffffff"
  Behavior on outline { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
  property color border: DynamicTheme.enabled ? DynamicTheme.border : "#222222"
  Behavior on border { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
  property color borderStrong: DynamicTheme.enabled ? DynamicTheme.borderStrong : "#333333"
  Behavior on borderStrong { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
  property color muted: DynamicTheme.enabled ? DynamicTheme.muted : "#888888"
  Behavior on muted { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
  property color muted2: DynamicTheme.enabled ? DynamicTheme.muted2 : "#555555"
  Behavior on muted2 { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
  property color muted3: DynamicTheme.enabled ? DynamicTheme.muted3 : "#333333"
  Behavior on muted3 { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
}
