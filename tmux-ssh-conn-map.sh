#!/bin/sh
# Called by tmux hooks (client-attached, client-session-changed). Reads the
# triggering client's SSH_CONN_ID from the session environment (populated by
# update-environment on each attach/switch) and upserts
# SSH_CONN_ID<TAB>session in ~/.tmux-conn-map for remote-profile auto-reattach.
session="$(tmux display-message -p '#S')"
[ -n "$session" ] || exit 0

line="$(tmux show-environment -t "=$session" SSH_CONN_ID 2>/dev/null)" || exit 0
case "$line" in
  SSH_CONN_ID=?*) conn_id="${line#SSH_CONN_ID=}" ;;
  *) exit 0 ;;
esac

map="$HOME/.tmux-conn-map"
(
  flock -w 2 9 || exit 0
  tmp="$(mktemp "$map.XXXXXX")" || exit 0
  [ -f "$map" ] && awk -F '\t' -v id="$conn_id" '$1 != id' "$map" > "$tmp"
  printf '%s\t%s\n' "$conn_id" "$session" >> "$tmp"
  mv "$tmp" "$map"
) 9> "$map.lock"
