#!/usr/bin/env python3
# =====================================================================
#  NORA Bridge + Model Supervisor + Static Web Server  (macOS / Linux)
#  - Serves the webapp (so the page is always available).
#  - Read-only system monitor (/sys, /fs/list, /fs/read) — token-gated.
#  - Model supervisor: runs the TEXT model or the VISION model, ONE AT A
#    TIME, swapping on request so only one uses RAM (fast + light).
#  - Self-terminates when the USB is unplugged.
#
#  Started by start-jarvis.sh:
#    python3 bridge.py <port> <token> <usb_root> <models_json>
# =====================================================================
import json, os, sys, time, threading, platform, shutil, subprocess, urllib.request, posixpath
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT   = int(sys.argv[1]) if len(sys.argv) > 1 else 8790
TOKEN  = sys.argv[2] if len(sys.argv) > 2 else ""
ROOT   = sys.argv[3] if len(sys.argv) > 3 else ""
CFGP   = sys.argv[4] if len(sys.argv) > 4 else ""
WEBDIR = os.path.join(ROOT, "webapp") if ROOT else ""
DATADIR= os.path.join(ROOT, "data") if ROOT else ""
MARKER = os.path.join(ROOT, "webapp", "index.html") if ROOT else ""

CFG = {}
if CFGP and os.path.exists(CFGP):
    try: CFG = json.load(open(CFGP))
    except Exception: CFG = {}

_procs = {}                 # which -> Popen
_active = {"which": None}
_lock = threading.Lock()

MIMES = {".html":"text/html;charset=utf-8", ".js":"application/javascript", ".css":"text/css",
         ".json":"application/json", ".png":"image/png", ".svg":"image/svg+xml", ".ico":"image/x-icon"}


def usb_gone():
    return bool(MARKER) and not os.path.exists(MARKER)


def model_health(port):
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=2) as r:
            return getattr(r, "status", 200) == 200
    except Exception:
        return False


def _stop(which):
    p = _procs.get(which)
    if p and p.poll() is None:
        try:
            p.terminate(); p.wait(timeout=8)
        except Exception:
            try: p.kill()
            except Exception: pass
    _procs.pop(which, None)


def _start(which):
    m = CFG.get(which)
    if not m:
        return False
    port = m["port"]
    if _procs.get(which) and _procs[which].poll() is None and model_health(port):
        return True
    cmd = [CFG["server"], "-m", m["model"], "--host", "127.0.0.1", "--port", str(port)]
    if m.get("mmproj"):
        cmd += ["--mmproj", m["mmproj"]]
    cmd += m.get("args", [])
    try:
        logf = open(os.path.join(DATADIR, which + "-model.log"), "ab", buffering=0)
    except Exception:
        logf = subprocess.DEVNULL
    _procs[which] = subprocess.Popen(cmd, stdout=logf, stderr=logf, env=dict(os.environ))
    for _ in range(240):
        if usb_gone():
            return False
        if model_health(port):
            return True
        if _procs[which].poll() is not None:
            return False
        time.sleep(1)
    return model_health(port)


def activate(which):
    """Ensure `which` model is running and the other is stopped (frees RAM)."""
    if which not in ("text", "vision"):
        return False, None
    with _lock:
        other = "vision" if which == "text" else "text"
        _stop(other)              # unload the other model FIRST to free RAM
        ok = _start(which)
        _active["which"] = which if ok else None
        return ok, CFG.get(which, {}).get("port")


def watchdog():
    while True:
        if usb_gone():
            for w in list(_procs):
                _stop(w)
            os._exit(0)
        time.sleep(3)


def sysinfo():
    info = {"os": platform.platform(), "host": platform.node(), "user": os.environ.get("USER", "?")}
    try:
        la = os.getloadavg(); cores = os.cpu_count() or 1
        info["load_1m"] = round(la[0], 2); info["cpu_pct"] = min(100, int(la[0] / cores * 100))
    except Exception: pass
    try:
        du = shutil.disk_usage("/"); info["disk_total_gb"] = round(du.total/1e9,1); info["disk_free_gb"] = round(du.free/1e9,1)
    except Exception: pass
    try:
        if platform.system() == "Linux":
            m = {}
            with open("/proc/meminfo") as f:
                for line in f:
                    k, v = line.split(":", 1); m[k] = int(v.strip().split()[0])
            total = m.get("MemTotal",0)/1e6; avail = m.get("MemAvailable",0)/1e6
            info["mem_total_gb"] = round(total,1); info["mem_used_gb"] = round(total-avail,1)
        else:
            info["mem_total_gb"] = round(os.sysconf("SC_PAGE_SIZE")*os.sysconf("SC_PHYS_PAGES")/1e9, 1)
    except Exception: pass
    return info


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def _hdr(self, code=200, ctype="application/json"):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type,X-Jarvis-Token")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.end_headers()

    def _json(self, obj, code=200):
        body = json.dumps(obj).encode("utf-8")
        self._hdr(code); self.wfile.write(body)

    def _auth(self):
        return self.headers.get("X-Jarvis-Token", "") == TOKEN

    def _body(self):
        n = int(self.headers.get("Content-Length", 0) or 0)
        if not n: return {}
        try: return json.loads(self.rfile.read(n).decode("utf-8"))
        except Exception: return {}

    def _serve_static(self, path):
        # map URL path -> file under WEBDIR (no traversal)
        rel = path.split("?", 1)[0]
        if rel == "/" or rel == "":
            rel = "/index.html"
        rel = posixpath.normpath(rel).lstrip("/")
        fp = os.path.join(WEBDIR, rel)
        if not os.path.abspath(fp).startswith(os.path.abspath(WEBDIR)) or not os.path.isfile(fp):
            self._json({"error": "not found"}, 404); return
        ext = os.path.splitext(fp)[1].lower()
        try:
            data = open(fp, "rb").read()
        except Exception:
            self._json({"error": "read"}, 500); return
        self.send_response(200)
        self.send_header("Content-Type", MIMES.get(ext, "application/octet-stream"))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers(); self.wfile.write(data)

    def do_OPTIONS(self):
        self._json({"ok": True})

    def do_GET(self):
        p = self.path.split("?", 1)[0]
        if p == "/health":
            self._json({"ok": True, "os": platform.system().lower(), "host": platform.node()}); return
        if p == "/ready":
            w = _active["which"]; port = CFG.get(w, {}).get("port") if w else None
            up = bool(port) and model_health(port)
            self._json({"ready": up, "which": w, "port": port}, 200 if up else 503); return
        if p == "/model":
            w = _active["which"]; self._json({"which": w, "port": CFG.get(w, {}).get("port") if w else None}); return
        if usb_gone():
            self._json({"error": "usb-removed"}, 410); return
        if p == "/sys":
            if not self._auth(): self._json({"error": "unauthorized"}, 401); return
            self._json(sysinfo()); return
        # otherwise: static webapp files
        self._serve_static(self.path)

    def do_POST(self):
        if usb_gone():
            self._json({"error": "usb-removed"}, 410); return
        p = self.path.split("?", 1)[0]
        if p == "/model":
            b = self._body(); ok, port = activate(b.get("which", "text"))
            self._json({"ok": ok, "which": _active["which"], "port": port}, 200 if ok else 500); return
        if not self._auth():
            self._json({"error": "unauthorized"}, 401); return
        b = self._body()
        try:
            if p == "/fs/list":
                pth = b.get("path") or os.path.expanduser("~"); items = []
                with os.scandir(pth) as it:
                    for i, e in enumerate(it):
                        if i >= 500: break
                        try: sz = e.stat().st_size if e.is_file() else 0
                        except Exception: sz = 0
                        items.append({"name": e.name, "dir": e.is_dir(), "size": sz})
                self._json({"ok": True, "path": pth, "items": items}); return
            if p == "/fs/read":
                pth = b.get("path", "")
                with open(pth, "r", errors="replace") as f: txt = f.read(100000)
                self._json({"ok": True, "path": pth, "text": txt}); return
            self._json({"error": "not found"}, 404)
        except Exception as e:
            self._json({"error": str(e)}, 500)


if __name__ == "__main__":
    threading.Thread(target=watchdog, daemon=True).start()
    # Boot the default model (text) in the background so the page can load fast.
    threading.Thread(target=lambda: activate(CFG.get("default", "text")), daemon=True).start()
    srv = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"[bridge] supervisor + web on http://127.0.0.1:{PORT}")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        for w in list(_procs): _stop(w)
