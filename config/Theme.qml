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
  readonly property int spacingXL: 20
  readonly property int spacingXXL: 24
  readonly property int paddingXS: 4
  readonly property int paddingS: 8
  readonly property int paddingM: 12
  readonly property int paddingL: 16
  readonly property int paddingXL: 20
  readonly property int paddingXXL: 24
  readonly property int radiusXS: 4
  readonly property int radiusS: 8
  readonly property int radiusM: 12
  readonly property int radiusL: 16
  readonly property int radiusXL: 24
  readonly property int radiusXXL: 28
  readonly property int radiusFull: 999
  readonly property int rounding: radiusM
  readonly property int radius: radiusM

  readonly property int animFast: 160
  readonly property int animDefault: 260
  readonly property int animSlow: 400
  readonly property int animExpressive: 500
  readonly property int animEffects: 200
  readonly property int themeTransition: 600
  readonly property real surfaceAlpha: TransparencyState.transparent ? 1.0 - TransparencyState.amount : 1.0
  readonly property int easingOut: Easing.OutCubic
  readonly property int easingIn: Easing.InCubic
  readonly property int easingDefault: Easing.OutCubic
  readonly property int animSwipe: 320
  readonly property int easingSwipe: Easing.OutExpo

  property color bgBase: DynamicTheme.bg
  property color bg: Qt.rgba(bgBase.r, bgBase.g, bgBase.b, root.surfaceAlpha)
  Behavior on bg { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
  property color bgAltBase: DynamicTheme.bgAlt
  property color bgAlt: Qt.rgba(bgAltBase.r, bgAltBase.g, bgAltBase.b, root.surfaceAlpha)
  property color fg: DynamicTheme.fg
  Behavior on fg { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
  property color outline: DynamicTheme.outline
  property color border: DynamicTheme.border
  property color borderStrong: DynamicTheme.borderStrong
  property color muted: DynamicTheme.muted
  property color muted2: DynamicTheme.muted2
  property color muted3: DynamicTheme.muted3
  readonly property color hover: "#33ffffff"
  readonly property color match: DynamicTheme.role("tertiary", "#cb4b16")
  readonly property color onSelect: "#586e75"
  readonly property color error: DynamicTheme.role("error", "#ff5555")
  readonly property color onError: DynamicTheme.role("onError", "#000000")

  readonly property color primary: DynamicTheme.role("primary", "#ffffff")
  readonly property color onPrimary: DynamicTheme.role("onPrimary", "#000000")
  readonly property color primaryContainer: DynamicTheme.role("primaryContainer", "#333333")
  readonly property color onPrimaryContainer: DynamicTheme.role("onPrimaryContainer", "#ffffff")
  readonly property color secondary: DynamicTheme.role("secondary", "#cccccc")
  readonly property color onSecondary: DynamicTheme.role("onSecondary", "#000000")
  readonly property color secondaryContainer: DynamicTheme.role("secondaryContainer", "#333333")
  readonly property color onSecondaryContainer: DynamicTheme.role("onSecondaryContainer", "#ffffff")
  readonly property color tertiary: DynamicTheme.role("tertiary", "#dddddd")
  readonly property color onTertiary: DynamicTheme.role("onTertiary", "#000000")
  readonly property color tertiaryContainer: DynamicTheme.role("tertiaryContainer", "#333333")
  readonly property color onTertiaryContainer: DynamicTheme.role("onTertiaryContainer", "#ffffff")
  readonly property color surface: DynamicTheme.role("surface", "#111111")
  readonly property color surfaceDim: DynamicTheme.role("surfaceDim", "#111111")
  readonly property color surfaceBright: DynamicTheme.role("surfaceBright", "#222222")
  readonly property color surfaceLowest: DynamicTheme.role("surfaceContainerLowest", "#0a0a0a")
  readonly property color surfaceLow: DynamicTheme.role("surfaceContainerLow", "#191919")
  readonly property color surfaceContainer: DynamicTheme.role("surfaceContainer", "#1f1f1f")
  readonly property color surfaceHigh: DynamicTheme.role("surfaceContainerHigh", "#292929")
  readonly property color surfaceHighest: DynamicTheme.role("surfaceContainerHighest", "#333333")
  readonly property color onSurface: DynamicTheme.role("onSurface", "#ffffff")
  readonly property color onSurfaceVariant: DynamicTheme.role("onSurfaceVariant", "#aaaaaa")
  readonly property color outlineVariant: DynamicTheme.role("outlineVariant", "#444444")
  readonly property color inverseSurface: DynamicTheme.role("inverseSurface", "#ffffff")
  readonly property color inverseOnSurface: DynamicTheme.role("inverseOnSurface", "#111111")
  readonly property color errorContainer: DynamicTheme.role("errorContainer", "#333333")
  readonly property color onErrorContainer: DynamicTheme.role("onErrorContainer", "#ffffff")
  readonly property color scrim: DynamicTheme.role("scrim", "#000000")

  function withSurfaceAlpha(c) {
    return Qt.rgba(c.r, c.g, c.b, root.surfaceAlpha)
  }
  readonly property color surfaceBg: root.withSurfaceAlpha(root.surface)
  readonly property color surfaceLowBg: root.withSurfaceAlpha(root.surfaceLow)
  readonly property color surfaceContainerBg: root.withSurfaceAlpha(root.surfaceContainer)
  readonly property color surfaceHighBg: root.withSurfaceAlpha(root.surfaceHigh)
  property color lockBgBase: TransparencyState.transparent ? DynamicTheme.bg : "#000000"
  property color lockBg: Qt.rgba(lockBgBase.r, lockBgBase.g, lockBgBase.b, root.surfaceAlpha)
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
