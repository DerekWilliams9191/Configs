#!/usr/bin/env bash
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmux_bin="${TMUX_BIN:-tmux}"
action="${1:-show}"
notify_host="${AGENT_NOTIFY_HOST:-127.0.0.1}"
notify_port="${AGENT_NOTIFY_PORT:-45891}"
hook_input=""
hook_event_name=""
hook_notification_type=""
hook_tool_name=""

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
  timeout 1 bash -c \
    'printf "%s\n" "$1" >"/dev/tcp/$2/$3"' \
    agent-notify "$request" "$notify_host" "$notify_port" 2>/dev/null
}

initialize_client_activity() {
  local state="$1" pid activity window_id client_tty session_id
  while IFS=$'\t' read -r pid activity window_id client_tty session_id; do
    [[ "$pid" =~ ^[0-9]+$ && "$activity" =~ ^[0-9]+$ ]] || continue
    [[ -f "$state/activity.$pid" ]] ||
      printf '%s\n' "$activity" >"$state/activity.$pid"
  done < <(list_clients)
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

show_notification() {
  [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]] || return 0

  local session session_id index name window_id title message request state activity
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
  request="$(
    jq -nc \
      --arg action "show" \
      --arg group "$(group_id "$window_id")" \
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
  mkdir -p "$state"
  initialize_client_activity "$state"
  printf '%s\n' "$(group_id "$window_id")" >"$state/pending.${window_id#@}"

  if [[ "$activity" =~ ^[0-9]+$ ]]; then
    while (( $(date +%s) <= activity )); do
      sleep 0.05
    done
  fi

  if ! send_request "$request"; then
    rm -f "$state/pending.${window_id#@}"
    return 0
  fi

  nohup "$script_dir/agent-notify-watch.sh" "$(server_id)" \
    >/dev/null 2>&1 &
}

clear_notification() {
  local window_id="${1:-}"
  [[ -n "${TMUX:-}" && -n "$window_id" ]] || return 0

  local state pending group request
  state="$(state_dir)"
  pending="$state/pending.${window_id#@}"
  [[ -f "$pending" || "${AGENT_NOTIFY_DRY_RUN:-0}" == "1" ]] || return 0
  group="$(group_id "$window_id")"
  [[ -f "$pending" ]] && group="$(cat "$pending")"

  request="$(
    jq -nc \
      --arg action "clear" \
      --arg group "$group" \
      '{action: $action, group: $group}'
  )"

  if [[ "${AGENT_NOTIFY_DRY_RUN:-0}" == "1" ]]; then
    send_request "$request"
    return 0
  fi

  if send_request "$request"; then
    rm -f "$pending"
  fi
}

case "$action" in
  show) show_notification ;;
  clear) clear_notification "${2:-}" ;;
  *) exit 2 ;;
esac
