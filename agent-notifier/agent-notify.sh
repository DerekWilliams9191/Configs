#!/usr/bin/env bash
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmux_bin="${TMUX_BIN:-tmux}"
action="${1:-show}"
notify_host="${AGENT_NOTIFY_HOST:-127.0.0.1}"
notify_port="${AGENT_NOTIFY_PORT:-45891}"
notify_timeout=20
hook_input=""
hook_event_name=""
hook_notification_type=""
hook_tool_name=""
hook_error=""

if [[ ! -t 0 ]]; then
  hook_input="$(cat)"
  hook_event_name="$(
    jq -r '.hook_event_name // empty' <<<"$hook_input" 2>/dev/null || true
  )"
  hook_notification_type="$(
    jq -r '.notification_type // empty' <<<"$hook_input" 2>/dev/null || true
  )"
  hook_tool_name="$(
    jq -r '.tool_name // empty' <<<"$hook_input" 2>/dev/null || true
  )"
  hook_error="$(
    jq -r '.error // empty' <<<"$hook_input" 2>/dev/null || true
  )"
fi

server_id() {
  printf '%s' "${TMUX%%,*}" | cksum | awk '{print $1}'
}

group_id() {
  local id="$1"
  printf '%s:%s:%s' "$(hostname -s)" "$(server_id)" "$id"
}

state_dir() {
  printf '%s/agent-notify/%s' \
    "${XDG_CACHE_HOME:-$HOME/.cache}" "$(server_id)"
}

window_lock_file() {
  local state="$1"
  local window_id="$2"
  printf '%s/window.%s.lock' "$state" "${window_id#@}"
}

notification_generation() {
  printf '%s:%s:%s' "$(date +%s%N)" "$$" "$RANDOM"
}

pending_generation() {
  local pending="$1"
  jq -er '.generation | strings | select(length > 0)' "$pending" 2>/dev/null
}

pending_group() {
  local pending="$1"
  jq -er '.group | strings | select(length > 0)' "$pending" 2>/dev/null
}

pending_is_acknowledged() {
  local pending="$1"
  jq -e '.acknowledged == true' "$pending" >/dev/null 2>&1
}

pending_previous_generation() {
  local pending="$1"
  jq -er \
    '.previous.generation | strings | select(length > 0)' \
    "$pending" 2>/dev/null
}

pending_previous_group() {
  local pending="$1"
  jq -er \
    '.previous.group | strings | select(length > 0)' \
    "$pending" 2>/dev/null
}

pending_clear_generations() {
  local pending="$1"
  jq -cer '
    (.clear_generations // []) |
    map(select(type == "string" and length > 0)) |
    unique
  ' "$pending" 2>/dev/null
}

pending_previous_clear_generations() {
  local pending="$1"
  jq -cer '
    (.previous.clear_generations // []) |
    map(select(type == "string" and length > 0)) |
    unique
  ' "$pending" 2>/dev/null
}

pending_accepts_generation() {
  local pending="$1"
  local generation="$2"
  jq -e \
    --arg generation "$generation" \
    '(.clear_generations // []) | index($generation) != null' \
    "$pending" >/dev/null 2>&1
}

pending_previous_accepts_generation() {
  local pending="$1"
  local generation="$2"
  jq -e \
    --arg generation "$generation" \
    '
      .acknowledged == false and (
        .previous.generation == $generation or
        (
          (.previous.clear_generations // []) |
          index($generation) != null
        )
      )
    ' "$pending" >/dev/null 2>&1
}

write_pending_notification() {
  local pending="$1"
  local generation="$2"
  local group="$3"
  local acknowledged="$4"
  local previous_generation="${5:-}"
  local previous_group="${6:-}"
  local clear_generations="${7:-[]}"
  local temporary="${pending}.tmp.$$.$RANDOM"
  local result

  if jq -nc \
    --arg generation "$generation" \
    --arg group "$group" \
    --argjson acknowledged "$acknowledged" \
    --arg previous_generation "$previous_generation" \
    --arg previous_group "$previous_group" \
    --argjson clear_generations "$clear_generations" \
    '
      {
        generation: $generation,
        group: $group,
        acknowledged: $acknowledged
      } +
      if $acknowledged then
        if ($clear_generations | length) > 0 then
          {clear_generations: $clear_generations}
        else
          {}
        end
      elif (
        ($previous_generation | length) > 0 and
        ($previous_group | length) > 0
      ) then
        {
          previous: (
            {
              generation: $previous_generation,
              group: $previous_group
            } +
            if ($clear_generations | length) > 0 then
              {clear_generations: $clear_generations}
            else
              {}
            end
          )
        }
      else
        {}
      end
    ' >"$temporary" &&
    mv -f -- "$temporary" "$pending"; then
    result=0
  else
    result=1
  fi
  rm -f -- "$temporary"
  return "$result"
}

restore_previous_notification() {
  local pending="$1"
  local clear_generations
  local previous_generation
  local previous_group

  pending_is_acknowledged "$pending" && return 0
  previous_generation="$(pending_previous_generation "$pending")" ||
    previous_generation=""
  previous_group="$(pending_previous_group "$pending")" ||
    previous_group=""
  clear_generations="$(pending_previous_clear_generations "$pending")" ||
    clear_generations="[]"

  if [[ -n "$previous_generation" && -n "$previous_group" ]]; then
    write_pending_notification \
      "$pending" "$previous_generation" "$previous_group" true "" "" \
      "$clear_generations"
  else
    rm -f -- "$pending"
  fi
}

list_clients() {
  "$tmux_bin" list-clients \
    -F '#{client_pid}	#{client_activity}	#{window_id}	#{client_tty}	#{session_id}' \
    2>/dev/null
}

select_client_activity() {
  local preferred_session_id="${1:-}"
  list_clients | awk -F '	' -v preferred="$preferred_session_id" '
    $2 ~ /^[0-9]+$/ {
      if (!have_any || $2 > any_activity) {
        have_any = 1
        any_activity = $2
      }
      if ($5 == preferred && (!have_preferred || $2 > preferred_activity)) {
        have_preferred = 1
        preferred_activity = $2
      }
    }
    END {
      if (have_preferred) {
        print preferred_activity
      } else if (have_any) {
        print any_activity
      }
    }
  '
}

send_request() {
  local request="$1"
  if [[ "${AGENT_NOTIFY_DRY_RUN:-0}" == "1" ]]; then
    printf '%s\n' "$request"
    return 0
  fi

  [[ "$notify_port" =~ ^[0-9]+$ ]] || return 1
  timeout "$notify_timeout" bash -c '
    exec 3<>"/dev/tcp/$2/$3" || exit 1
    printf "%s\n" "$1" >&3 || exit 1
    IFS= read -r response <&3 || exit 1
    [[ "$response" == "{\"ok\":true}" ]]
  ' agent-notify "$request" "$notify_host" "$notify_port" 2>/dev/null
}

initialize_client_activity() {
  local state="$1" pid activity window_id client_tty session_id
  while IFS=$'\t' read -r pid activity window_id client_tty session_id; do
    [[ "$pid" =~ ^[0-9]+$ && "$activity" =~ ^[0-9]+$ ]] || continue
    [[ -f "$state/activity.$pid" ]] ||
      printf '%s\n' "$activity" >"$state/activity.$pid"
  done < <(list_clients)
}

initialize_notification_state() {
  local state="$1"
  local window_id="$2"
  local group="$3"
  local generation="$4"
  local lock
  local pending
  local previous_clear_generations="[]"
  local previous_generation=""
  local previous_group=""
  local result
  local state_lock_fd
  local window_lock_fd

  mkdir -p "$state"
  lock="$(window_lock_file "$state" "$window_id")"
  pending="$state/pending.${window_id#@}"
  exec {window_lock_fd}>"$lock" || return 1
  if ! flock "$window_lock_fd"; then
    exec {window_lock_fd}>&-
    return 1
  fi

  if ! exec {state_lock_fd}>"$state/state.lock"; then
    exec {window_lock_fd}>&-
    return 1
  fi
  if ! flock "$state_lock_fd"; then
    exec {state_lock_fd}>&-
    exec {window_lock_fd}>&-
    return 1
  fi

  initialize_client_activity "$state"
  if [[ -f "$pending" ]]; then
    if pending_is_acknowledged "$pending"; then
      previous_generation="$(pending_generation "$pending")" ||
        previous_generation=""
      previous_group="$(pending_group "$pending")" ||
        previous_group=""
      previous_clear_generations="$(pending_clear_generations "$pending")" ||
        previous_clear_generations="[]"
    else
      previous_generation="$(pending_previous_generation "$pending")" ||
        previous_generation=""
      previous_group="$(pending_previous_group "$pending")" ||
        previous_group=""
      previous_clear_generations="$(
        pending_previous_clear_generations "$pending"
      )" || previous_clear_generations="[]"
    fi
  fi
  if [[ -z "$previous_generation" || -z "$previous_group" ]]; then
    previous_generation=""
    previous_group=""
    previous_clear_generations="[]"
  elif ! previous_clear_generations="$(
    jq -cn \
      --argjson existing "$previous_clear_generations" \
      --arg generation "$generation" \
      '$existing + [$generation] | unique'
  )"; then
    exec {state_lock_fd}>&-
    exec {window_lock_fd}>&-
    return 1
  fi

  write_pending_notification \
    "$pending" "$generation" "$group" false \
    "$previous_generation" "$previous_group" \
    "$previous_clear_generations"
  result=$?
  exec {state_lock_fd}>&-
  exec {window_lock_fd}>&-
  return "$result"
}

launch_watcher_with_readiness() {
  local state="$1"
  local watcher_server_id="$2"
  local watcher_lock_fd="$3"
  local inherited_state_lock_fd="$4"
  local attempt
  local check
  local ready_file
  local watcher_pid

  for attempt in 1 2 3; do
    ready_file="$state/watcher.ready.$$.$RANDOM"
    rm -f -- "$ready_file"
    nohup "$script_dir/agent-notify-watch.sh" \
      "$watcher_server_id" "$watcher_lock_fd" "$ready_file" \
      "$inherited_state_lock_fd" \
      >/dev/null 2>&1 &
    watcher_pid=$!

    for check in {1..50}; do
      if [[ -f "$ready_file" ]] &&
        kill -0 "$watcher_pid" 2>/dev/null; then
        return 0
      fi
      kill -0 "$watcher_pid" 2>/dev/null || break
      sleep 0.02
    done

    kill -KILL "$watcher_pid" 2>/dev/null || true
    wait "$watcher_pid" 2>/dev/null || true
    rm -f -- "$ready_file"
  done
  return 1
}

start_watcher_if_needed() {
  local state="$1"
  local result
  local state_lock_fd
  local watcher_lock_fd
  local watcher_server_id

  exec {state_lock_fd}>"$state/state.lock" || return 1
  if ! flock "$state_lock_fd"; then
    exec {state_lock_fd}>&-
    return 1
  fi

  exec {watcher_lock_fd}>"$state/watcher.lock" || {
    exec {state_lock_fd}>&-
    return 1
  }
  if ! flock -n "$watcher_lock_fd"; then
    exec {watcher_lock_fd}>&-
    exec {state_lock_fd}>&-
    return 0
  fi

  rm -f "$state"/watcher.ready.*
  watcher_server_id="$(server_id)"
  if launch_watcher_with_readiness \
    "$state" "$watcher_server_id" "$watcher_lock_fd" \
    "$state_lock_fd"; then
    result=0
  else
    result=1
  fi
  exec {watcher_lock_fd}>&-
  exec {state_lock_fd}>&-
  return "$result"
}

notification_message() {
  case "$hook_event_name" in
    "") printf '%s' "Finished" ;;
    Notification)
      case "$hook_notification_type" in
        elicitation_dialog) printf '%s' "Input needed" ;;
        worker_permission_prompt) printf '%s' "Approval needed" ;;
        *) return 1 ;;
      esac
      ;;
    PermissionRequest) printf '%s' "Approval needed" ;;
    PreToolUse)
      case "$hook_tool_name" in
        AskUserQuestion | request_user_input) printf '%s' "Input needed" ;;
        *) return 1 ;;
      esac
      ;;
    Stop)
      jq -e '(.background_tasks | length) == 0' \
        <<<"$hook_input" >/dev/null 2>&1 || return 1
      printf '%s' "Finished"
      ;;
    StopFailure) printf '%s' "Failed" ;;
    *) return 1 ;;
  esac
}

is_rate_limit_failure() {
  [[ "$hook_event_name" == "StopFailure" ]] || return 1
  [[ "$hook_error" == "rate_limit" ]]
}

pane_has_rate_limit() {
  local pane="$1"
  local pane_text

  # capture-pane always pads to the pane height, so strip the blank filler
  # before taking the tail. A short session draws at the top of the pane.
  pane_text="$(
    "$tmux_bin" capture-pane -p -J -t "$pane" 2>/dev/null |
      sed '/^[[:space:]]*$/d' |
      tail -n 30
  )" || return 1

  [[ "$pane_text" == *"API Error: Request rejected (429)"* ]]
}

pane_is_ready_for_input() {
  local pane="$1"
  local cursor_y
  local cursor_line

  cursor_y="$(
    "$tmux_bin" display-message -p -t "$pane" '#{cursor_y}' 2>/dev/null
  )" || return 1
  [[ "$cursor_y" =~ ^[0-9]+$ ]] || return 1

  cursor_line="$(
    "$tmux_bin" capture-pane -p -J -t "$pane" 2>/dev/null |
      sed -n "$((cursor_y + 1))p"
  )" || return 1

  [[ "$cursor_line" == "❯"* ]]
}

wait_for_process_exit() {
  local process_id="$1"
  local attempts=0

  [[ "$process_id" =~ ^[0-9]+$ ]] || return 1

  while kill -0 "$process_id" 2>/dev/null; do
    (( attempts < 100 )) || return 1
    sleep 0.05
    ((attempts += 1))
  done
}

continue_rate_limited_pane() {
  local pane="$1"
  local hook_process_id="$2"
  local attempts=0

  [[ -n "$pane" ]] || return 0
  wait_for_process_exit "$hook_process_id" || return 0

  while (( attempts < 100 )); do
    if pane_has_rate_limit "$pane" && pane_is_ready_for_input "$pane"; then
      "$tmux_bin" send-keys -l -t "$pane" "Continue." 2>/dev/null ||
        return 0
      "$tmux_bin" send-keys -t "$pane" Enter 2>/dev/null || true
      return 0
    fi

    sleep 0.05
    ((attempts += 1))
  done
}

queue_rate_limit_continue() {
  [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]] || return 1
  is_rate_limit_failure || return 1

  nohup "$script_dir/agent-notify.sh" \
    continue-rate-limit "$TMUX_PANE" "$$" \
    </dev/null >/dev/null 2>&1 &
}

rollback_pending_notification() {
  local state="$1"
  local window_id="$2"
  local generation="$3"
  local pending="$state/pending.${window_id#@}"
  local current_generation
  local lock
  local window_lock_fd

  lock="$(window_lock_file "$state" "$window_id")"
  exec {window_lock_fd}>"$lock" || return 1
  if ! flock "$window_lock_fd"; then
    exec {window_lock_fd}>&-
    return 1
  fi

  current_generation="$(pending_generation "$pending")" ||
    current_generation=""
  if [[ "$current_generation" == "$generation" ]]; then
    restore_previous_notification "$pending" || true
  fi
  exec {window_lock_fd}>&-
}

send_pending_notification() {
  local state="$1"
  local window_id="$2"
  local generation="$3"
  local request="$4"
  local pending="$state/pending.${window_id#@}"
  local lock
  local current_generation
  local current_group
  local window_lock_fd

  lock="$(window_lock_file "$state" "$window_id")"
  exec {window_lock_fd}>"$lock" || return 0
  if ! flock "$window_lock_fd"; then
    exec {window_lock_fd}>&-
    return 0
  fi

  current_generation="$(pending_generation "$pending")" || current_generation=""
  if [[ "$current_generation" != "$generation" ]]; then
    exec {window_lock_fd}>&-
    return 0
  fi

  current_group="$(pending_group "$pending")" || {
    exec {window_lock_fd}>&-
    return 0
  }
  if send_request "$request"; then
    write_pending_notification \
      "$pending" "$generation" "$current_group" true || true
  else
    restore_previous_notification "$pending" || true
  fi
  exec {window_lock_fd}>&-
}

show_notification() {
  [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]] || return 0

  local session session_id index name window_id title message request state activity
  local generation group
  message="$(notification_message)" || return 0
  session="$("$tmux_bin" display-message -p -t "$TMUX_PANE" '#{session_name}')" ||
    return 0
  session_id="$("$tmux_bin" display-message -p -t "$TMUX_PANE" '#{session_id}')" ||
    return 0
  index="$("$tmux_bin" display-message -p -t "$TMUX_PANE" '#{window_index}')" ||
    return 0
  name="$("$tmux_bin" display-message -p -t "$TMUX_PANE" '#{window_name}')" ||
    return 0
  window_id="$("$tmux_bin" display-message -p -t "$TMUX_PANE" '#{window_id}')" ||
    return 0

  title="$(
    jq -nr --arg value "$session - $index $name" \
      '$value | gsub("[\u0000-\u001f\u007f]"; " ")'
  )"
  group="$(group_id "$window_id")"
  request="$(
    jq -nc \
      --arg action "show" \
      --arg group "$group" \
      --arg title "$title" \
      --arg message "$message" \
      '{action: $action, group: $group, title: $title, message: $message}'
  )"

  if [[ "${AGENT_NOTIFY_DRY_RUN:-0}" == "1" ]]; then
    send_request "$request"
    return 0
  fi

  activity="$(select_client_activity "$session_id")"

  state="$(state_dir)"
  generation="$(notification_generation)"
  initialize_notification_state \
    "$state" "$window_id" "$group" "$generation" || return 0
  if ! start_watcher_if_needed "$state"; then
    rollback_pending_notification "$state" "$window_id" "$generation"
    return 0
  fi

  if [[ "$activity" =~ ^[0-9]+$ ]]; then
    while (( $(date +%s) <= activity )); do
      sleep 0.05
    done
  fi

  send_pending_notification "$state" "$window_id" "$generation" "$request"
}

clear_notification() {
  local window_id="${1:-}"
  local expected_generation="${2:-}"
  [[ -n "${TMUX:-}" && -n "$window_id" ]] || return 0

  local state pending group request lock result current_generation
  local resolution_waits=0
  local max_resolution_waits=100
  local window_lock_fd
  state="$(state_dir)"
  pending="$state/pending.${window_id#@}"
  lock="$(window_lock_file "$state" "$window_id")"

  while true; do
    [[ -f "$pending" ]] || return 0
    exec {window_lock_fd}>"$lock" || return 1
    if ! flock "$window_lock_fd"; then
      exec {window_lock_fd}>&-
      return 1
    fi

    if [[ ! -f "$pending" ]]; then
      exec {window_lock_fd}>&-
      return 0
    fi
    current_generation="$(pending_generation "$pending")" || {
      exec {window_lock_fd}>&-
      return 1
    }
    if [[ -n "$expected_generation" &&
      "$current_generation" != "$expected_generation" ]]; then
      if pending_accepts_generation "$pending" "$expected_generation"; then
        :
      elif pending_previous_accepts_generation \
        "$pending" "$expected_generation"; then
        if (( resolution_waits < max_resolution_waits )); then
          exec {window_lock_fd}>&-
          sleep 0.05
          ((resolution_waits += 1))
          continue
        fi
      else
        exec {window_lock_fd}>&-
        return 0
      fi
    fi
    group="$(pending_group "$pending")" || {
      exec {window_lock_fd}>&-
      return 1
    }

    request="$(
      jq -nc \
        --arg action "clear" \
        --arg group "$group" \
        '{action: $action, group: $group}'
    )"

    if send_request "$request"; then
      if [[ "${AGENT_NOTIFY_DRY_RUN:-0}" != "1" ]]; then
        rm -f "$pending"
      fi
      result=0
    else
      result=1
    fi
    exec {window_lock_fd}>&-
    return "$result"
  done
}

case "$action" in
  show)
    queue_rate_limit_continue && exit 0
    show_notification
    ;;
  continue-rate-limit) continue_rate_limited_pane "${2:-}" "${3:-}" ;;
  clear) clear_notification "${2:-}" "${3:-}" ;;
  *) exit 2 ;;
esac
