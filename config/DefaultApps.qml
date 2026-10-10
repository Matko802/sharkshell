pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "DefaultApps.js" as Apps

Scope {
  id: root

  readonly property string homeDir: Quickshell.env("HOME")
  readonly property string mimeappsPath: root.homeDir + "/.config/mimeapps.list"
  readonly property string termChoicePath: root.homeDir + "/.config/sharkshell/default-terminal"
  readonly property string xdgTermsPath: root.homeDir + "/.config/xdg-terminals.list"

  property string mimeText: ""
  property string termChoice: ""

  readonly property var allEntries: DesktopEntries.applications.values.filter(function(e) { return e && !e.noDisplay })

  function findEntry(id) {
    for (var i = 0; i < root.allEntries.length; i++) {
      var e = root.allEntries[i]
      if (e && e.id === id) return e
    }
    return null
  }

  function fullId(id) {
    var s = String(id || "")
    if (s === "" || s.endsWith(".desktop")) return s
    if (root.findEntry(s + ".desktop")) return s + ".desktop"
    return s
  }

  function healIds() {
    var b = root.fullId(root.mimeDefaults["x-scheme-handler/http"] || "")
    if (b !== "" && b !== (root.mimeDefaults["x-scheme-handler/http"] || "")) root.setBrowser(b)
    var f = root.fullId(root.mimeDefaults["inode/directory"] || "")
    if (f !== "" && f !== (root.mimeDefaults["inode/directory"] || "")) root.setFiles(f)
    var m = root.fullId(root.mimeDefaults["x-scheme-handler/mailto"] || "")
    if (m !== "" && m !== (root.mimeDefaults["x-scheme-handler/mailto"] || "")) root.setMail(m)
    var t = root.fullId(root.termChoice)
    if (t !== "" && t !== root.termChoice) root.setTerminal(t)
  }

  function plainEntries() {
    return root.allEntries.map(function(e) {
      return { id: String(e.id || ""), name: String(e.name || ""), noDisplay: !!e.noDisplay }
    })
  }

  readonly property var browsers: Apps.matchEntries(root.plainEntries(), Apps.BROWSER_RES, Apps.BROWSER_NAME_RES)
  readonly property var fileManagers: Apps.matchEntries(root.plainEntries(), Apps.FILES_RES, Apps.FILES_NAME_RES)
  readonly property var mailClients: Apps.matchEntries(root.plainEntries(), Apps.MAIL_RES, Apps.MAIL_NAME_RES)
  readonly property var terminals: Apps.matchEntries(root.plainEntries(), Apps.TERM_RES, Apps.TERM_NAME_RES)

  readonly property var mimeDefaults: Apps.parseMimeapps(root.mimeText)

  readonly property string browserId: root.fullId(root.mimeDefaults["x-scheme-handler/http"] || "")
  readonly property string filesId: root.fullId(root.mimeDefaults["inode/directory"] || "")
  readonly property string mailId: root.fullId(root.mimeDefaults["x-scheme-handler/mailto"] || "")

  function displayName(id) {
    if (!id) return ""
    var e = root.findEntry(id) || root.findEntry(root.fullId(id))
    if (e && e.name) return String(e.name)
    return String(id).replace(/\.desktop$/, "")
  }

  readonly property string browserName: root.browserId !== "" ? root.displayName(root.browserId) : "System default"
  readonly property string filesName: root.filesId !== "" ? root.displayName(root.filesId) : "System default"
  readonly property string mailName: root.mailId !== "" ? root.displayName(root.mailId) : "Not set"
  readonly property string terminalName: root.termChoice === "" ? "Automatic" : root.displayName(root.termChoice)

  readonly property var rows: [
    { cat: "browser", label: "Web browser", icon: "search", current: root.browserName },
    { cat: "files", label: "File manager", icon: "folder", current: root.filesName },
    { cat: "terminal", label: "Terminal", icon: "cpu", current: root.terminalName },
    { cat: "mail", label: "Email client", icon: "notifications", current: root.mailName }
  ]

  function idsOf(list) {
    return list.map(function(x) { return x.id })
  }

  function cycle(cat) {
    var n = null
    if (cat === "browser") {
      n = Apps.nextId(root.browserId, root.idsOf(root.browsers))
      if (n) root.setBrowser(n)
    } else if (cat === "files") {
      n = Apps.nextId(root.filesId, root.idsOf(root.fileManagers))
      if (n) root.setFiles(n)
    } else if (cat === "mail") {
      n = Apps.nextId(root.mailId, root.idsOf(root.mailClients))
      if (n) root.setMail(n)
    } else if (cat === "terminal") {
      n = Apps.nextId(root.termChoice, root.idsOf(root.terminals))
      if (n) root.setTerminal(n)
    }
  }

  function setBrowser(id) {
    id = root.fullId(id)
    var t = Apps.serializeMimeapps(root.mimeText, {
      "x-scheme-handler/http": id,
      "x-scheme-handler/https": id
    })
    root.mimeText = t
    mimeFile.setText(t)
  }

  function setFiles(id) {
    id = root.fullId(id)
    var t = Apps.serializeMimeapps(root.mimeText, { "inode/directory": id })
    root.mimeText = t
    mimeFile.setText(t)
  }

  function setMail(id) {
    id = root.fullId(id)
    var t = Apps.serializeMimeapps(root.mimeText, { "x-scheme-handler/mailto": id })
    root.mimeText = t
    mimeFile.setText(t)
  }

  function setTerminal(id) {
    id = root.fullId(id)
    root.termChoice = id
    termFile.setText(id + "\n")
    termListFile.setText(id + "\n")
  }

  function setApp(cat, id) {
    if (cat === "browser") root.setBrowser(id)
    else if (cat === "files") root.setFiles(id)
    else if (cat === "mail") root.setMail(id)
    else if (cat === "terminal") root.setTerminal(id)
  }

  function currentIdOf(cat) {
    if (cat === "browser") return root.browserId
    if (cat === "files") return root.filesId
    if (cat === "mail") return root.mailId
    if (cat === "terminal") return root.termChoice
    return ""
  }

  function optsFor(cat) {
    if (cat === "browser") return root.browsers
    if (cat === "files") return root.fileManagers
    if (cat === "mail") return root.mailClients
    if (cat === "terminal") return root.terminals
    return []
  }

  readonly property var terminalCmd: {
    if (root.termChoice === "") return []
    var e = root.findEntry(root.termChoice) || root.findEntry(root.fullId(root.termChoice))
    var bin = e && e.execString ? Apps.binFromExec(String(e.execString)) : root.termChoice.replace(/\.desktop$/, "")
    if (bin === "") return []
    return Apps.termCmdForBin(bin)
  }
  readonly property bool hasTerminalChoice: root.termChoice !== "" && root.terminalCmd.length > 0

  FileView {
    id: mimeFile
    path: root.mimeappsPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      root.mimeText = text()
      root.healIds()
    }
    onFileChanged: reload()
  }

  FileView {
    id: termFile
    path: root.termChoicePath
    watchChanges: true
    printErrors: false
    onLoaded: {
      root.termChoice = text().trim()
      root.healIds()
    }
    onFileChanged: reload()
  }

  FileView {
    id: termListFile
    path: root.xdgTermsPath
    watchChanges: false
    printErrors: false
  }
}
