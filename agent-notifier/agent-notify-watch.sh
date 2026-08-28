#!/usr/bin/env bash
set -uo pipefail

server_id="$1"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmux_bin="${TMUX_BIN:-tmux}"
notify_command="${AGENT_NOTIFY_COMMAND:-$script_dir/agent-notify.sh}"
state="${XDG_CACHE_HOME:-$HOME/.cache}/agent-notify/$server_id"
lock="$state/watcher.lock"

mkdir -p "$state"
exec 9>"$lock"
flock -n 9 || exit 0

cleanup() {
  rm -f "$state"/activity.* "$lock"
}
trap cleanup EXIT

has_pending() {
  compgen -G "$state/pending.*" >/dev/null
}

while has_pending; do
  while IFS=$'\t' read -r client_pid activity window_id client_tty session_id; do
    [[ "$client_pid" =~ ^[0-9]+$ && "$activity" =~ ^[0-9]+$ ]] || continue

    activity_file="$state/activity.$client_pid"
    previous="$(cat "$activity_file" 2>/dev/null || true)"
    pending="$state/pending.${window_id#@}"

    if [[ -n "$previous" && "$activity" != "$previous" && -f "$pending" ]]; then
      "$notify_command" clear "$window_id"
    fi
    printf '%s\n' "$activity" >"$activity_file"
  done < <(
    "$tmux_bin" list-clients \
      -F '#{client_pid}	#{client_activity}	#{window_id}	#{client_tty}	#{session_id}' \
      2>/dev/null
  )

  sleep 0.2
done
