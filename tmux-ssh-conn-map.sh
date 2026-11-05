#!/bin/sh
# Called by tmux hooks (client-attached, client-session-changed) with the
# client's session and pid. Reads SSH_CONN_ID from the triggering client
# process's environment and upserts SSH_CONN_ID<TAB>session in
# ~/.tmux-conn-map for remote-profile auto-reattach.
session="$1"
client_pid="$2"
[ -n "$session" ] && [ -n "$client_pid" ] || exit 0

conn_id="$(ps eww -o command= -p "$client_pid" 2>/dev/null | tr ' ' '\n' | sed -n 's/^SSH_CONN_ID=//p' | tail -n 1)"
[ -n "$conn_id" ] || exit 0

map="$HOME/.tmux-conn-map"
lock="$map.lock"

# mkdir is atomic on macOS and Linux (no flock on macOS). Retry ~2s.
tries=0
until mkdir "$lock" 2>/dev/null; do
  tries=$((tries + 1))
  [ "$tries" -lt 20 ] || exit 0
  sleep 0.1
done
trap 'rmdir "$lock"' EXIT

tmp="$(mktemp "$map.XXXXXX")" || exit 0
[ -f "$map" ] && awk -F '\t' -v id="$conn_id" '$1 != id' "$map" > "$tmp"
printf '%s\t%s\n' "$conn_id" "$session" >> "$tmp"
mv "$tmp" "$map"
