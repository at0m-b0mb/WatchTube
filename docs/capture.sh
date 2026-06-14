#!/usr/bin/env bash
# Captures fresh WatchTube screenshots from the booted watch simulator using the
# app's built-in screenshot harness (WT_SEED / WT_TAB / WT_PLAY / WT_SETTINGS /
# WT_SEARCH). Usage:  ./docs/capture.sh <SIM_UDID>
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

UDID="${1:?pass the simulator UDID}"
BUNDLE="com.at0m.watchtube.watchkitapp"
RAW="docs/screenshots/_raw"
mkdir -p "$RAW"

shot() {            # shot <name> <wait_secs> <env KEY=VAL ...>
  local name="$1"; local wait="$2"; shift 2
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  local envargs=(WT_SEED=1)
  for kv in "$@"; do envargs+=("$kv"); done
  local prefixed=()
  for kv in "${envargs[@]}"; do prefixed+=("SIMCTL_CHILD_${kv}"); done
  echo "▸ $name  (env: ${envargs[*]})"
  env "${prefixed[@]}" xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot "$RAW/$name.png" >/dev/null 2>&1
  echo "  saved $RAW/$name.png"
}

shot home      6  WT_TAB=home
shot search    6  WT_TAB=search WT_SEARCH="lofi hip hop"
shot library   6  WT_TAB=library
shot shorts    7  WT_TAB=shorts
shot settings  4  WT_SETTINGS=1
shot player    8  WT_PLAY=5qap5aO4i9A

echo "Done. Raw screenshots in $RAW"
