#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  deploy.sh — one-command sideload for WatchTube (free Apple ID friendly)
# ─────────────────────────────────────────────────────────────────────────────
#
#  Usage:
#    ./deploy.sh              # build + install on the first watch it finds
#    ./deploy.sh --simulator  # build + run in the watchOS simulator instead
#
#  What it does:
#    1. Regenerates the Xcode project (xcodegen)
#    2. Finds your paired Apple Watch (or simulator)
#    3. Builds and installs WatchTube onto it
#
#  Free Apple ID?  Run this once a week to refresh the 7-day provisioning.
#  The app shows how many days are left in Settings, so you'll know when.
#
#  Prerequisites:
#    - Xcode (free from the Mac App Store)
#    - xcodegen (brew install xcodegen)
#    - Your Apple ID signed in under Xcode > Settings > Accounts
#    - For real-watch deploys: watch paired, unlocked, Developer Mode on
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
cd "$(dirname "$0")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { printf "${CYAN}▸${RESET} %s\n" "$*"; }
ok()    { printf "${GREEN}✔${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}⚠${RESET} %s\n" "$*"; }
fail()  { printf "${RED}✘${RESET} %s\n" "$*" >&2; exit 1; }

# ── Check tools ──────────────────────────────────────────────────────────────
command -v xcodegen >/dev/null 2>&1 || fail "xcodegen not found. Install it: brew install xcodegen"
command -v xcodebuild >/dev/null 2>&1 || fail "Xcode not found. Install it from the Mac App Store."

# ── Generate project ─────────────────────────────────────────────────────────
info "Generating Xcode project…"
xcodegen generate --quiet 2>/dev/null || xcodegen generate
ok "WatchTube.xcodeproj ready"

# ── Pick destination ─────────────────────────────────────────────────────────
USE_SIMULATOR=false
if [[ "${1:-}" == "--simulator" || "${1:-}" == "-s" ]]; then
    USE_SIMULATOR=true
fi

if $USE_SIMULATOR; then
    # Find an Apple Watch Ultra simulator (or any watch sim)
    DEST=$(xcrun simctl list devices available -j 2>/dev/null \
        | python3 -c "
import sys, json
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    if 'watchOS' not in runtime: continue
    for d in devices:
        if d.get('isAvailable') and 'Ultra' in d.get('name', ''):
            print(f\"platform=watchOS Simulator,id={d['udid']}\")
            sys.exit(0)
for runtime, devices in data.get('devices', {}).items():
    if 'watchOS' not in runtime: continue
    for d in devices:
        if d.get('isAvailable'):
            print(f\"platform=watchOS Simulator,id={d['udid']}\")
            sys.exit(0)
" 2>/dev/null || true)

    if [[ -z "$DEST" ]]; then
        DEST="generic/platform=watchOS Simulator"
        warn "No specific watch simulator found — using generic destination"
    else
        ok "Simulator: $DEST"
    fi
else
    # Real device: use generic destination (Xcode picks the paired watch)
    DEST="generic/platform=watchOS"
    info "Targeting your paired Apple Watch"
    echo ""
    warn "Make sure your watch is:"
    echo "    • Unlocked and on its charger (for first install)"
    echo "    • Developer Mode enabled (Settings > Privacy > Developer Mode)"
    echo "    • On the same Wi-Fi as this Mac"
    echo ""
fi

# ── Build & install ──────────────────────────────────────────────────────────
info "Building WatchTube…"
echo ""

BUILD_CMD=(
    xcodebuild
    -scheme WatchTube
    -destination "$DEST"
)

if $USE_SIMULATOR; then
    BUILD_CMD+=(build)
    # Simulator doesn't need signing
    BUILD_CMD+=(CODE_SIGNING_ALLOWED=NO)
else
    BUILD_CMD+=(build)
    BUILD_CMD+=(CODE_SIGN_STYLE=Automatic)
fi

if "${BUILD_CMD[@]}" 2>&1 | tail -5; then
    echo ""
    ok "Build succeeded!"
else
    echo ""
    fail "Build failed. Check the output above."
fi

# ── Run on simulator ─────────────────────────────────────────────────────────
if $USE_SIMULATOR; then
    info "Launching in simulator…"
    SIM_ID=$(echo "$DEST" | grep -oE '[0-9A-F-]{36}' || true)
    if [[ -n "$SIM_ID" ]]; then
        xcrun simctl boot "$SIM_ID" 2>/dev/null || true
        # Find the .app in DerivedData
        APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/WatchTube-*/Build/Products/Debug-watchsimulator -name "WatchTube.app" -maxdepth 1 2>/dev/null | head -1)
        if [[ -n "$APP_PATH" ]]; then
            xcrun simctl install "$SIM_ID" "$APP_PATH" 2>/dev/null || true
            xcrun simctl launch "$SIM_ID" com.at0m.watchtube.watchkitapp 2>/dev/null || true
            ok "Launched in simulator"
        fi
    fi
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
printf "${BOLD}${GREEN}Done!${RESET}"
if $USE_SIMULATOR; then
    echo " WatchTube is running in the simulator."
else
    echo " WatchTube is on your watch."
    echo ""
    echo "  Free Apple ID → re-run this script in 7 days to refresh."
    echo "  The app shows days remaining in Settings."
fi
echo ""
