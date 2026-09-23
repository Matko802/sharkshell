import QtQuick
import "Material.js" as Material

Item {
  id: root

  property string name: ""
  property color color: Theme.fg
  property int size: 16

  implicitWidth: size
  implicitHeight: size

  readonly property bool useMaterialOutlined: Material.isOutlined(root.name)

  Text {
    anchors.centerIn: parent
    text: Material.resolve(root.name)
    color: root.color
    font.family: root.useMaterialOutlined ? Theme.outlinedFontFamily : Theme.materialFontFamily
    font.pixelSize: root.size
    font.hintingPreference: Font.PreferNoHinting
    renderType: Text.NativeRendering
  }
}
