pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: root

  Process { id: runProc; running: false }

  function focus(n) {
    const raw = typeof n === "string" ? n : (n ? (n.desktopEntry || n.appName || "") : "")
    root.focusPid(-1, raw)
  }

  function focusPid(pid, app) {
    const raw = String(app || "")
    if (pid <= 0 && raw === "")
      return
    runProc.command = ["python3", "-c", `import json,re,subprocess,sys
pid=int(sys.argv[1] or -1)
raw=re.sub(r'\.desktop$','',sys.argv[2].strip().lower())
def norm(s): return re.sub(r'[^a-z0-9]','',s.lower())
target=norm(raw)
try:
 wins=json.loads(subprocess.check_output(['niri','msg','-j','windows'],stderr=subprocess.DEVNULL))
except Exception:
 sys.exit(1)
def ts(w):
 t=w.get('focus_timestamp') or {}
 return t.get('secs',0)+t.get('nanos',0)/1e9
best=None
bestkey=None
if pid>0:
 for w in wins:
  if w.get('pid')==pid:
   key=(4,ts(w))
   if bestkey is None or key>bestkey:
    bestkey=key
    best=w
if best is None and target:
 for w in wins:
  app=norm(w.get('app_id') or '')
  title=norm(w.get('title') or '')
  if app==target:
   score=3
  elif app and (target in app or app in target):
   score=2
  elif title and target in title:
   score=1
  else:
   continue
  key=(score,ts(w))
  if bestkey is None or key>bestkey:
   bestkey=key
   best=w
if best is None: sys.exit(1)
subprocess.run(['niri','msg','action','focus-window','--id',str(best['id'])],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
`, String(pid), raw]
    runProc.running = false
    runProc.running = true
  }
}
