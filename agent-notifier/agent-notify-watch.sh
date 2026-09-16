#!/usr/bin/env bash
set -uo pipefail

server_id="$1"
inherited_lock_fd="${2:-}"
ready_file="${3:-}"
inherited_state_lock_fd="${4:-}"
if [[ "$inherited_state_lock_fd" =~ ^[0-9]+$ ]] &&
  (( inherited_state_lock_fd > 2 )); then
  exec {inherited_state_lock_fd}>&-
fi
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmux_bin="${TMUX_BIN:-tmux}"
notify_command="${AGENT_NOTIFY_COMMAND:-$script_dir/agent-notify.sh}"
state="${XDG_CACHE_HOME:-$HOME/.cache}/agent-notify/$server_id"
lock="$state/watcher.lock"
state_lock="$state/state.lock"
watcher_lock_released=0

mkdir -p "$state"
if [[ "$inherited_lock_fd" =~ ^[0-9]+$ ]]; then
  watcher_lock_fd="$inherited_lock_fd"
  flock -n "$watcher_lock_fd" || exit 2
else
  exec {watcher_lock_fd}>"$lock"
  flock -n "$watcher_lock_fd" || exit 0
  rm -f "$state"/watcher.ready.*
fi

has_pending() {
  compgen -G "$state/pending.*" >/dev/null
}

launch_successor_with_readiness() {
  local attempt
  local check
  local successor_pid
  local successor_ready_file

  for attempt in 1 2 3; do
    successor_ready_file="$state/watcher.ready.$$.$RANDOM"
    rm -f -- "$successor_ready_file"
    nohup "$script_dir/agent-notify-watch.sh" \
      "$server_id" "$watcher_lock_fd" "$successor_ready_file" \
      >/dev/null 2>&1 &
    successor_pid=$!

    for check in {1..50}; do
      if [[ -f "$successor_ready_file" ]] &&
        kill -0 "$successor_pid" 2>/dev/null; then
        return 0
      fi
      kill -0 "$successor_pid" 2>/dev/null || break
      sleep 0.02
    done

    kill -KILL "$successor_pid" 2>/dev/null || true
    wait "$successor_pid" 2>/dev/null || true
    rm -f -- "$successor_ready_file"
  done
  return 1
}

cleanup_if_idle() {
  local state_lock_fd
  local result

  exec {state_lock_fd}>"$state_lock" || return 1
  if ! flock "$state_lock_fd"; then
    exec {state_lock_fd}>&-
    return 1
  fi

  if has_pending; then
    result=1
  else
    rm -f "$state"/activity.* "$state"/watcher.ready.*
    if (( ! watcher_lock_released )); then
      exec {watcher_lock_fd}>&-
      watcher_lock_released=1
    fi
    result=0
  fi
  exec {state_lock_fd}>&-
  return "$result"
}

cleanup() {
  local state_lock_fd

  (( watcher_lock_released )) && return 0
  if [[ -n "$ready_file" && ! -f "$ready_file" ]]; then
    exec {watcher_lock_fd}>&-
    watcher_lock_released=1
    return 0
  fi
  exec {state_lock_fd}>"$state_lock" || return 0
  if ! flock "$state_lock_fd"; then
    exec {state_lock_fd}>&-
    return 0
  fi

  if has_pending; then
    exec {state_lock_fd}>&-
    launch_successor_with_readiness || true
    [[ -n "$ready_file" ]] && rm -f -- "$ready_file"
  else
    rm -f "$state"/activity.* "$state"/watcher.ready.*
    exec {state_lock_fd}>&-
  fi
  exec {watcher_lock_fd}>&-
  watcher_lock_released=1
}
trap cleanup EXIT

if [[ -n "$ready_file" ]]; then
  printf '%s\n' "$$" >"$ready_file" || exit 3
fi

while ! cleanup_if_idle; do
  while IFS=$'\t' read -r client_pid activity window_id client_tty session_id; do
    [[ "$client_pid" =~ ^[0-9]+$ && "$activity" =~ ^[0-9]+$ ]] || continue

    activity_file="$state/activity.$client_pid"
    previous="$(cat "$activity_file" 2>/dev/null || true)"
    pending="$state/pending.${window_id#@}"

    if [[ -f "$pending" ]] &&
      { [[ ! -f "$activity_file" ]] ||
        [[ -n "$previous" && "$activity" != "$previous" ]]; }; then
      generation="$(
        jq -er \
          '.generation | strings | select(length > 0)' \
          "$pending" 2>/dev/null
      )" || continue
      "$notify_command" clear "$window_id" "$generation" || continue
    fi
    printf '%s\n' "$activity" >"$activity_file"
  done < <(
    "$tmux_bin" list-clients \
      -F '#{client_pid}	#{client_activity}	#{window_id}	#{client_tty}	#{session_id}' \
      2>/dev/null
  )

  sleep 0.2
done
