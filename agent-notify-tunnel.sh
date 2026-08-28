#!/usr/bin/env bash
set -uo pipefail

host="${1:-}"
port="${AGENT_NOTIFY_PORT:-45891}"

if [[ -z "$host" || ! "$port" =~ ^[0-9]+$ ]]; then
  echo "Usage: $(basename "$0") HOST" >&2
  exit 2
fi

remote_port_in_use() {
  ssh -T \
    -o ConnectTimeout=5 \
    "$host" \
    "timeout 1 bash -c '</dev/tcp/127.0.0.1/$port'" \
    >/dev/null 2>&1
}

trap 'exit 130' INT TERM

while true; do
  if remote_port_in_use; then
    echo "Notification tunnel for $host is already running." >&2
    exit 0
  fi

  ssh -N -T \
    -o ExitOnForwardFailure=yes \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -R "127.0.0.1:$port:127.0.0.1:$port" \
    "$host"
  echo "Notification tunnel lost. Reconnecting in 3s..." >&2
  sleep 3
done
