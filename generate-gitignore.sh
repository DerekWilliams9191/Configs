#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRACKED_GITIGNORE="$SCRIPT_DIR/.gitignore_global"
LOCAL_GITIGNORE="$HOME/.gitignore_global.local"
COMBINED_GITIGNORE="$HOME/.gitignore_global.combined"
TEMP_FILE="$(mktemp "$COMBINED_GITIGNORE.tmp.XXXXXX")"

cleanup() {
    rm -f "$TEMP_FILE"
}
trap cleanup EXIT

cat "$TRACKED_GITIGNORE" > "$TEMP_FILE"

if [ -f "$LOCAL_GITIGNORE" ]; then
    printf '\n' >> "$TEMP_FILE"
    cat "$LOCAL_GITIGNORE" >> "$TEMP_FILE"
fi

mv -f "$TEMP_FILE" "$COMBINED_GITIGNORE"
trap - EXIT

echo "Generated $COMBINED_GITIGNORE"
