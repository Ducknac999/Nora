#!/usr/bin/env bash
# =====================================================================
#  NORA  (installed edition, macOS Apple Silicon)
#  Runs entirely from ~/Nora. No USB, no internet. Bridge serves the UI
#  and runs ONE model at a time (TEXT or VISION), swapping to save RAM.
#  Whisper (voice input) runs separately.
#  Turn off: close this Terminal window, or double-click "Stop Nora".
# =====================================================================
set -euo pipefail

BASE="$HOME/Nora"
ENGINE="$BASE/engine"; MODELS="$BASE/models"; VISION="$BASE/vision"; WEBAPP="$BASE/webapp"; DATA="$BASE/data"
mkdir -p "$ENGINE" "$MODELS" "$VISION" "$WEBAPP" "$DATA"
echo "[*] NORA  root=$BASE"

command -v python3 >/dev/null 2>&1 || { echo "[ERR] python3 is required. Run the installer again to set it up."; read -r _; exit 1; }

# --- Ports: text model, vision model, bridge/web, whisper -----------
pick(){ python3 -c "import socket
p=$1
while p<$1+60:
 s=socket.socket()
 try:
  s.bind(('127.0.0.1',p));s.close();print(p);break
 except OSError:
  p+=1"; }
PORT="$(pick 8080)"; VPORT="$(pick 8180)"; BPORT="$(pick 8790)"; WPORT="$(pick 8850)"

# --- Engine binary ---------------------------------------------------
SERVER="$(find "$ENGINE" -maxdepth 3 -name llama-server -type f 2>/dev/null | head -n1 || true)"
[ -n "$SERVER" ] || { echo "[ERR] llama-server not found. Run the installer again."; read -r _; exit 1; }
chmod +x "$SERVER" 2>/dev/null || true

# --- Resolve model files (glob, so either RAM tier works) ------------
TEXT_MODEL="$(find "$MODELS" -maxdepth 1 -name '*.gguf' -type f 2>/dev/null | head -n1 || true)"
[ -n "$TEXT_MODEL" ] || { echo "[ERR] No text model in $MODELS. Run the installer again."; read -r _; exit 1; }
VIS_MODEL="$(find "$VISION" -maxdepth 1 -name '*.gguf' -type f 2>/dev/null | grep -vi mmproj | head -n1 || true)"
VIS_MMPROJ="$(find "$VISION" -maxdepth 1 -name '*.gguf' -type f 2>/dev/null | grep -i  mmproj | head -n1 || true)"
echo "[*] Text model:   $(basename "$TEXT_MODEL")"
if [ -n "$VIS_MODEL" ] && [ -n "$VIS_MMPROJ" ]; then echo "[*] Vision model: $(basename "$VIS_MODEL")"; else echo "[*] Vision: not installed (optional Vision Update)"; fi

# --- Per-launch token + web config (served by the bridge) -----------
BTOKEN="$( { uuidgen 2>/dev/null || python3 -c 'import uuid;print(uuid.uuid4())'; } | tr -d '-' | tr 'A-Z' 'a-z' )"
HAVE_VISION=false; [ -n "$VIS_MODEL" ] && [ -n "$VIS_MMPROJ" ] && HAVE_VISION=true
printf 'window.NORA={token:"%s",textPort:%s,visionPort:%s,whisperPort:%s,hasVision:%s};\n' \
  "$BTOKEN" "$PORT" "$VPORT" "$WPORT" "$HAVE_VISION" > "$WEBAPP/bridge.local.js"

# --- Model supervisor config (read by the bridge) -------------------
python3 - "$DATA/models.json" "$SERVER" "$TEXT_MODEL" "$PORT" "${VIS_MODEL:-}" "${VIS_MMPROJ:-}" "$VPORT" <<'PY'
import json,os,sys
out, server, tmodel, tport, vmodel, vmmproj, vport = sys.argv[1:8]
cfg={"server":server,"default":"text",
     "text":{"model":tmodel,"port":int(tport),
             "args":["-c","8192","--parallel","1","-ngl","999","-fa","on","--jinja","--temp","0.35","--repeat-penalty","1.1"]}}
if vmodel and vmmproj and os.path.isfile(vmodel) and os.path.isfile(vmmproj):
    cfg["vision"]={"model":vmodel,"mmproj":vmmproj,"port":int(vport),
                   "args":["-c","16384","--parallel","1","-ngl","999","-fa","on","--jinja","--temp","0.35","--repeat-penalty","1.1","--image-min-tokens","1024"]}
json.dump(cfg,open(out,"w"),indent=2)
print("[*] wrote",out)
PY

# --- Start the bridge (supervisor + web server). It auto-loads TEXT. -
python3 "$ENGINE/bridge/bridge.py" "$BPORT" "$BTOKEN" "$BASE" "$DATA/models.json" >"$DATA/bridge.log" 2>&1 &
BRIDGE_PID=$!
echo "[*] Bridge (supervisor + web) on 127.0.0.1:$BPORT"

# --- Whisper (voice input): start AFTER the text model is up --------
WHISPER_PID=""; WSERVER="$ENGINE/whisper/whisper-server"; WMODEL="$ENGINE/whisper/ggml-base.en.bin"; START_WHISPER=0
if [ -x "$WSERVER" ] && [ -f "$WMODEL" ]; then START_WHISPER=1; else echo "[!] Whisper not found — voice input disabled."; fi

# --- Clean shutdown (Terminal closed or Stop Nora) ------------------
cleanup(){ [ -n "${BRIDGE_PID:-}" ] && kill "$BRIDGE_PID" 2>/dev/null || true; [ -n "${WHISPER_PID:-}" ] && kill "$WHISPER_PID" 2>/dev/null || true; pkill -f "llama-server" 2>/dev/null || true; pkill -f "whisper-server" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

# --- Instant "waking up" window (flips into Nora when ready) --------
PROFILE="$HOME/.nora-browser"; mkdir -p "$PROFILE" "$HOME/.nora"
LOADER="$HOME/.nora/loading.html"
cat > "$LOADER" <<EOF
<!doctype html><html><head><meta charset="utf-8"><title>NORA</title>
<style>
  html,body{height:100%;margin:0;background:#030712;color:#cfe9f2;
    font-family:system-ui,-apple-system,"Segoe UI",monospace;overflow:hidden}
  .wrap{height:100%;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:26px}
  .logo{font-weight:700;letter-spacing:12px;font-size:34px;color:#22d3ee;text-shadow:0 0 18px rgba(34,211,238,.55)}
  .ring{width:60px;height:60px;border-radius:50%;border:3px solid rgba(34,211,238,.15);
    border-top-color:#22d3ee;animation:spin 1s linear infinite;box-shadow:0 0 20px rgba(34,211,238,.35)}
  @keyframes spin{to{transform:rotate(360deg)}}
  .sub{letter-spacing:3px;color:#5b7487;font-size:11px;text-transform:uppercase}
  .msg{color:#5b7487;font-size:12px;letter-spacing:1px}
</style></head><body><div class="wrap">
  <div class="logo">N O R A</div><div class="ring"></div>
  <div class="sub">Waking up &middot; local &amp; offline</div>
  <div class="msg" id="m">Loading model&hellip;</div>
</div><script>
  var BASE="http://127.0.0.1:$BPORT", t0=Date.now();
  function retry(){ var s=Math.round((Date.now()-t0)/1000);
    if(s>300){ location.replace(BASE+"/"); return; }
    document.getElementById("m").textContent="Loading model… "+s+"s"; setTimeout(tick,800); }
  function tick(){ fetch(BASE+"/ready",{cache:"no-store"})
      .then(function(r){ if(r&&r.ok){ location.replace(BASE+"/"); } else { retry(); } })
      .catch(retry); }
  tick();
</script></body></html>
EOF

open -na "Google Chrome" --args --app="file://$LOADER" --user-data-dir="$PROFILE" 2>/dev/null \
  || open -na "Vivaldi" --args --app="file://$LOADER" --user-data-dir="$PROFILE" 2>/dev/null \
  || open -na "Microsoft Edge" --args --app="file://$LOADER" --user-data-dir="$PROFILE" 2>/dev/null \
  || open "file://$LOADER"
echo "[*] Window up (loading screen). Nora opens automatically when the model is ready."

# --- Wait for the text model to be ready (bridge /ready) ------------
echo "[*] Loading model..."
READY=0
for i in $(seq 1 600); do
  curl -fs "http://127.0.0.1:${BPORT}/ready" >/dev/null 2>&1 && { READY=1; break; }
  sleep 1
done
[ "$READY" = 1 ] && echo "[OK] Model online after ${i}s." || echo "[!] Model still loading…"

# --- Start Whisper now (text model up -> no boot contention) --------
if [ "$START_WHISPER" = 1 ]; then
  chmod +x "$WSERVER" 2>/dev/null || true
  "$WSERVER" -m "$WMODEL" --host 127.0.0.1 --port "$WPORT" -t 4 >"$DATA/whisper.log" 2>&1 &
  WHISPER_PID=$!
  echo "[*] Voice-input (Whisper) on 127.0.0.1:$WPORT"
fi

echo ""
echo "[OK] NORA is running.  Close this window (or double-click 'Stop Nora') to turn it off."
wait "$BRIDGE_PID"
