#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This installer must run on macOS." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LISTENER="$SCRIPT_DIR/agent-notify-listener.py"
TUNNEL="$SCRIPT_DIR/agent-notify-tunnel.sh"
LABEL="com.dkws.agent-notify"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/agent-notify.log"

if [[ ! -f "$LISTENER" || ! -f "$TUNNEL" ]]; then
    echo "Missing agent notification scripts in $SCRIPT_DIR." >&2
    exit 1
fi

if ! command -v terminal-notifier >/dev/null 2>&1; then
    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew is required to install terminal-notifier." >&2
        exit 1
    fi
    brew install terminal-notifier
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required to run the notification listener." >&2
    exit 1
fi

PYTHON_BIN="$(command -v python3)"
NOTIFIER_BIN="$(command -v terminal-notifier)"

chmod +x "$LISTENER" "$TUNNEL"
mkdir -p "$(dirname "$PLIST")" "$(dirname "$LOG")"

PLIST_PATH="$PLIST" \
NOTIFY_LABEL="$LABEL" \
PYTHON_PATH="$PYTHON_BIN" \
LISTENER_PATH="$LISTENER" \
NOTIFIER_PATH="$NOTIFIER_BIN" \
NOTIFY_LOG="$LOG" \
"$PYTHON_BIN" <<'PY'
import os
import plistlib


config = {
    "Label": os.environ["NOTIFY_LABEL"],
    "ProgramArguments": [
        os.environ["PYTHON_PATH"],
        os.environ["LISTENER_PATH"],
        "--host",
        "127.0.0.1",
        "--port",
        "45891",
        "--notifier",
        os.environ["NOTIFIER_PATH"],
    ],
    "RunAtLoad": True,
    "KeepAlive": True,
    "StandardOutPath": os.environ["NOTIFY_LOG"],
    "StandardErrorPath": os.environ["NOTIFY_LOG"],
}

with open(os.environ["PLIST_PATH"], "wb") as plist:
    plistlib.dump(config, plist)
PY

launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$PLIST"
launchctl kickstart -k "gui/$UID/$LABEL"

echo "Agent notification listener enabled on 127.0.0.1:45891."
echo "Start one notification tunnel for each remote host:"
echo "  $TUNNEL HOST"
