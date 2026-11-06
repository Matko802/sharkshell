import QtQuick
import Quickshell
import Quickshell.Power

Scope {
  id: root

  function setAllPower(on) {
    power.setAllPower(on)
  }

  OutputPower {
    id: power
  }
}
