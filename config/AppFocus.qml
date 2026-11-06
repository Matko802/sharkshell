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
if not wins: sys.exit(1)
def ts(w):
 t=w.get('focus_timestamp') or {}
 return t.get('secs',0)+t.get('nanos',0)/1e9
def key(w):
 t=ts(w)
 has=t>0
 return (1 if has else 0,t,w.get('id',0))
def ancestors(p):
 out=[]
 seen=set()
 cur=p
 while cur>0 and cur not in seen:
  seen.add(cur)
  nxt=0
  try:
   with open('/proc/'+str(cur)+'/status') as f:
    for line in f:
     if line.startswith('PPid:'):
      nxt=int(line.split()[1]); break
  except Exception:
   nxt=0
  cur=nxt
  if cur>0: out.append(cur)
 return out
best=None
bestkey=None
if pid>0:
 wins_by_pid={}
 for w in wins:
  wp=w.get('pid') or 0
  if wp>0: wins_by_pid.setdefault(wp,[]).append(w)
 def pick(cands):
  global best,bestkey
  if not cands: return
  scored=sorted(cands,key=lambda w:((0 if target and target in norm(w.get('title') or '') else 1),-key(w)[1],w.get('id',0)))
  w=scored[0]
  k=(5,key(w))
  if bestkey is None or k>bestkey:
   bestkey=k
   best=w
 chain=[pid]+ancestors(pid)
 for anc in chain:
  cands=wins_by_pid.get(anc)
  if cands:
   pick(cands)
   break
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
  k=(score,key(w))
  if bestkey is None or k>bestkey:
   bestkey=k
   best=w
if best is None: sys.exit(1)
subprocess.run(['niri','msg','action','focus-window','--id',str(best['id'])],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
`, String(pid), raw]
    runProc.running = false
    runProc.running = true
  }
}
