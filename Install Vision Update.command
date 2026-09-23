#!/usr/bin/env bash
# =====================================================================
#  NORA — VISION UPDATE  (optional add-on)
#  Adds image understanding to an already-installed Nora. Detects your
#  RAM and downloads the right vision model + projector into ~/Nora.
#  After this, click the "Nora" icon and you'll see a Vision tab.
# =====================================================================
set -uo pipefail
b(){ printf "\033[1;36m%s\033[0m\n" "$*"; }
g(){ printf "\033[1;32m%s\033[0m\n" "$*"; }
y(){ printf "\033[1;33m%s\033[0m\n" "$*"; }
r(){ printf "\033[1;31m%s\033[0m\n" "$*"; }
line(){ printf "\033[2m%s\033[0m\n" "----------------------------------------------------------"; }

clear
b "  N O R A   —   V I S I O N   U P D A T E"
line
NORA="$HOME/Nora"
if [ ! -d "$NORA" ]; then
  r "  Nora isn't installed yet. Run \"Install Nora\" first, then this update."
  read -r _; exit 1
fi

HF_VIS="https://huggingface.co/Netherslayer99/nora-vison/resolve/main"
V8_MODEL="Qwen8gb2.5-VL-3B-Abl-Caption-it.Q4_K_M.gguf"
V8_PROJ="Qwen8gb2.5-VL-3B-Ab-Caption-it.mmproj-Q8_0.gguf"
V16_MODEL="Qwen2.516gb-VL-7B-Instruct-ab.Q4_K_M.gguf"
V16_PROJ="Qwen2.516gb-VL-7B-Instruct-ab.mmproj-Q8_0.gguf"

MEMGB=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1000000000 ))
if [ "$MEMGB" -ge 12 ]; then TIER="16gb"; VMODEL="$V16_MODEL"; VPROJ="$V16_PROJ"; else TIER="8gb"; VMODEL="$V8_MODEL"; VPROJ="$V8_PROJ"; fi
g "  Detected ${MEMGB} GB RAM  ->  installing the ${TIER} vision model."
echo ""

mkdir -p "$NORA/vision"
dl(){ local url="$1" dest="$2" label="$3"
  if [ -f "$dest" ] && [ "$(stat -f%z "$dest" 2>/dev/null || echo 0)" -gt 1000000 ]; then g "  $label already there — skipping."; return 0; fi
  echo "  Downloading $label …"
  curl -L --fail --retry 3 --retry-delay 3 -C - --progress-bar -o "$dest" "$url" || { r "  Download failed for $label. Try again."; return 1; }
  g "  $label done."; }

b "  Downloading vision model + projector…"
dl "$HF_VIS/$VMODEL" "$NORA/vision/$VMODEL" "vision model (${TIER})" || { read -r _; exit 1; }
dl "$HF_VIS/$VPROJ"  "$NORA/vision/$VPROJ"  "vision projector"        || { read -r _; exit 1; }
xattr -dr com.apple.quarantine "$NORA/vision" 2>/dev/null || true
echo ""
line
g "  VISION IS INSTALLED."
echo "  Click the \"Nora\" icon — you'll now see a Vision tab at the top."
echo "  Don't want it later? Just delete the ~/Nora/vision folder."
line
echo ""
read -r -p "  Press Return to close." _
