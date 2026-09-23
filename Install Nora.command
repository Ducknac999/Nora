#!/usr/bin/env bash
# =====================================================================
#  INSTALL NORA  —  one-time setup (Apple Silicon Mac)
#  Downloads the right model for your RAM (8GB or 16GB), the voice
#  engine, and the AI engine, into a folder called "Nora" in your home.
#  After this finishes you can delete this installer. To use Nora,
#  double-click the "Nora" icon (drag it to your Dock for easy access).
# =====================================================================
set -uo pipefail

# ---- pretty output -------------------------------------------------
b(){ printf "\033[1;36m%s\033[0m\n" "$*"; }   # cyan bold
g(){ printf "\033[1;32m%s\033[0m\n" "$*"; }   # green
y(){ printf "\033[1;33m%s\033[0m\n" "$*"; }   # yellow
r(){ printf "\033[1;31m%s\033[0m\n" "$*"; }   # red
line(){ printf "\033[2m%s\033[0m\n" "----------------------------------------------------------"; }

clear
b "  N O R A   —   I N S T A L L E R"
line
echo "This sets up your offline AI assistant. It needs the internet"
echo "ONCE (now) to download everything. After that, Nora is 100% offline."
echo ""

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NORA="$HOME/Nora"

# ---- config: where the files live ----------------------------------
HF_TEXT="https://huggingface.co/Netherslayer99/nora-text/resolve/main"
REL="https://github.com/Ducknac999/Nora/releases/download/v1.0"
TEXT_8="josiefied8gb-qwen3-4b-ab-v1_q4_k_m.gguf"
TEXT_16="Josiefied16gb-Qwen3-8B-ab-v1.Q4_K_M.gguf"

# ---- 1. Python check (macOS asks to install if missing) ------------
b "[1/5]  Checking your Mac…"
if ! command -v python3 >/dev/null 2>&1; then
  y "  Your Mac needs Apple's free developer tools (for python3)."
  y "  A window will pop up — click \"Install\" and wait for it to finish."
  xcode-select --install 2>/dev/null || true
  echo ""
  y "  After it finishes installing, run this installer again."
  echo ""
  read -r -p "  Press Return to close." _
  exit 0
fi
ARCH="$(uname -m)"
[ "$ARCH" = "arm64" ] || y "  Note: this build is tuned for Apple Silicon (M1/M2/M3/M4)."

# ---- 2. Detect RAM -> pick the right model -------------------------
MEMBYTES="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
MEMGB=$(( MEMBYTES / 1000000000 ))
if [ "$MEMGB" -ge 12 ]; then TIER="16gb"; TEXT_FILE="$TEXT_16"; else TIER="8gb"; TEXT_FILE="$TEXT_8"; fi
g "  Detected ${MEMGB} GB RAM  ->  using the ${TIER} model."
echo ""

# ---- 3. Build the folders + copy the app -----------------------------
b "[2/5]  Setting up your Nora folder…"
mkdir -p "$NORA/engine" "$NORA/models" "$NORA/vision" "$NORA/webapp" "$NORA/data"
if [ -d "$HERE/app" ]; then
  cp -R "$HERE/app/." "$NORA/"          # start-nora.sh, stop-nora.sh, engine/bridge, webapp
  chmod +x "$NORA/start-nora.sh" "$NORA/stop-nora.sh" 2>/dev/null || true
  g "  App files copied."
else
  r "  Could not find the app files next to this installer. Re-download the zip and try again."
  read -r _; exit 1
fi
echo ""

# ---- helper: resumable download with a friendly label ---------------
dl(){ # url  dest  label
  local url="$1" dest="$2" label="$3"
  if [ -f "$dest" ] && [ "$(stat -f%z "$dest" 2>/dev/null || echo 0)" -gt 1000000 ]; then
    g "  $label already downloaded — skipping."; return 0
  fi
  echo "  Downloading $label …"
  curl -L --fail --retry 3 --retry-delay 3 -C - --progress-bar -o "$dest" "$url" || {
    r "  Download failed for $label. Check your internet and run the installer again."; return 1; }
  g "  $label done."
}

# ---- 4. Download the engines (AI + voice) --------------------------
b "[3/5]  Downloading the engines (AI + voice)…"
TMP="$NORA/data/_dl"; mkdir -p "$TMP"
dl "$REL/llama-macos-arm64.zip"   "$TMP/llama.zip"   "AI engine (small)"   || { read -r _; exit 1; }
dl "$REL/whisper-macos-arm64.zip" "$TMP/whisper.zip" "voice engine"        || { read -r _; exit 1; }
echo "  Unpacking engines…"
rm -rf "$NORA/engine/macos-arm64" "$NORA/engine/whisper"
ditto -xk "$TMP/llama.zip"   "$NORA/engine/" 2>/dev/null || unzip -oq "$TMP/llama.zip"   -d "$NORA/engine/"
ditto -xk "$TMP/whisper.zip" "$NORA/engine/" 2>/dev/null || unzip -oq "$TMP/whisper.zip" -d "$NORA/engine/"
# normalize folder names if the zip nested them
[ -d "$NORA/engine/llama-macos-arm64" ] && { rm -rf "$NORA/engine/macos-arm64"; mv "$NORA/engine/llama-macos-arm64" "$NORA/engine/macos-arm64"; }
[ -d "$NORA/engine/whisper-macos-arm64" ] && { rm -rf "$NORA/engine/whisper"; mv "$NORA/engine/whisper-macos-arm64" "$NORA/engine/whisper"; }
rm -rf "$TMP"/*.zip
g "  Engines ready."
echo ""

# ---- 5. Download the text model for this Mac -----------------------
b "[4/5]  Downloading your AI model (this is the big one)…"
dl "$HF_TEXT/$TEXT_FILE" "$NORA/models/$TEXT_FILE" "text model (${TIER})" || { read -r _; exit 1; }
echo ""

# ---- 6. Make everything trusted + runnable -------------------------
b "[5/5]  Finishing up…"
xattr -dr com.apple.quarantine "$NORA" 2>/dev/null || true
xattr -dr com.apple.quarantine "$HERE" 2>/dev/null || true   # bless the Nora / Stop Nora apps too
# ad-hoc re-sign the engine binaries so macOS won't call them "damaged"
find "$NORA/engine" -type f \( -name '*.dylib' -o -name 'llama-server' -o -name 'whisper-server' \) -print0 2>/dev/null \
  | xargs -0 -I{} codesign --force --sign - "{}" 2>/dev/null || true
g "  Done."
echo ""
line
g "  NORA IS INSTALLED."
echo ""
echo "  • Drag the  \"Nora\"  icon into your Dock  ->  click it to turn Nora ON."
echo "  • Drag  \"Stop Nora\"  into your Dock too   ->  click it to turn Nora OFF."
echo "    (You can also just close the black window to turn it off.)"
echo ""
echo "  You can delete this installer now if you want — Nora is fully set up."
line
echo ""
read -r -p "  Press Return to close this window." _
