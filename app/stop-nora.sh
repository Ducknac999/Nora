#!/usr/bin/env bash
# Turn Nora off: stop the models, voice engine, and bridge.
pkill -f "llama-server"  2>/dev/null || true
pkill -f "whisper-server" 2>/dev/null || true
pkill -f "Nora/engine/bridge/bridge.py" 2>/dev/null || true
pkill -f "bridge.py"     2>/dev/null || true
echo "Nora stopped."
sleep 1
