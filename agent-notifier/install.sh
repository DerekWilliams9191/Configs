#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This installer must run on macOS." >&2
    exit 1
fi

if (( EUID == 0 )); then
    echo "Do not run this installer as root or with sudo." >&2
    exit 1
fi

if [[ $# -ne 1 || -z "$1" || "$1" == -* || "$1" =~ [[:space:]] ]]; then
    echo "Usage: $(basename "$0") HOST" >&2
    exit 2
fi

host="$1"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source_listener="$script_dir/agent-notify-listener.py"
source_tunnel="$script_dir/agent-notify-tunnel.sh"
install_dir="$HOME/.local/bin"
installed_listener="$install_dir/agent-notify-listener.py"
installed_tunnel="$install_dir/agent-notify-tunnel.sh"
listener_label="local.agent-notifier.listener"
tunnel_label="local.agent-notifier.tunnel"
plist_dir="$HOME/Library/LaunchAgents"
listener_plist="$plist_dir/$listener_label.plist"
tunnel_plist="$plist_dir/$tunnel_label.plist"
listener_log="$HOME/Library/Logs/agent-notifier-listener.log"
tunnel_log="$HOME/Library/Logs/agent-notifier-tunnel.log"
port="${AGENT_NOTIFY_PORT:-45891}"
launchctl_bin="$(command -v launchctl)"

if [[ ! "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
    echo "AGENT_NOTIFY_PORT must be an integer from 1 through 65535." >&2
    exit 2
fi

if [[ ! -f "$source_listener" || ! -f "$source_tunnel" ]]; then
    echo "Missing agent notification scripts in $script_dir." >&2
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

python_bin="$(command -v python3)"
notifier_bin="$(command -v terminal-notifier)"

mkdir -p "$install_dir" "$plist_dir" "$(dirname "$listener_log")"

install_file() {
    local source="$1"
    local destination="$2"
    local temporary

    temporary="$(mktemp "$install_dir/.${destination##*/}.XXXXXX")"
    if ! install -m 0755 "$source" "$temporary"; then
        rm -f "$temporary"
        return 1
    fi
    if ! mv -f "$temporary" "$destination"; then
        rm -f "$temporary"
        return 1
    fi
}

install_file "$source_listener" "$installed_listener"
install_file "$source_tunnel" "$installed_tunnel"

bootout_agent() {
    "$launchctl_bin" bootout "gui/$UID/$1" 2>/dev/null || true
}

remove_existing_agents() {
    local plist label argument_0 argument_1

    bootout_agent "$listener_label"
    bootout_agent "$tunnel_label"

    for plist in "$plist_dir"/*.plist; do
        [[ -f "$plist" ]] || continue

        argument_0=$(
            /usr/libexec/PlistBuddy -c "Print :ProgramArguments:0" \
                "$plist" 2>/dev/null || true
        )
        argument_1=$(
            /usr/libexec/PlistBuddy -c "Print :ProgramArguments:1" \
                "$plist" 2>/dev/null || true
        )

        case "${argument_0##*/} ${argument_1##*/}" in
            *agent-notify-listener.py*|*agent-notify-tunnel.sh*)
                label=$(
                    /usr/libexec/PlistBuddy -c "Print :Label" \
                        "$plist" 2>/dev/null || true
                )
                if [[ -n "$label" ]]; then
                    case "$label" in
                        "$listener_label"|"$tunnel_label")
                            ;;
                        *)
                            bootout_agent "$label"
                            ;;
                    esac
                fi
                rm -f "$plist"
                ;;
        esac
    done
}

remove_existing_agents

LISTENER_LABEL="$listener_label" \
TUNNEL_LABEL="$tunnel_label" \
LISTENER_PLIST="$listener_plist" \
TUNNEL_PLIST="$tunnel_plist" \
PYTHON_BIN="$python_bin" \
LISTENER_BIN="$installed_listener" \
TUNNEL_BIN="$installed_tunnel" \
NOTIFIER_BIN="$notifier_bin" \
NOTIFY_HOST="$host" \
NOTIFY_PORT="$port" \
LISTENER_LOG="$listener_log" \
TUNNEL_LOG="$tunnel_log" \
"$python_bin" <<'PY'
import os
import plistlib
import tempfile


def write_plist(path: str, config: dict) -> None:
    directory = os.path.dirname(path)
    with tempfile.NamedTemporaryFile(dir=directory, delete=False) as plist:
        plistlib.dump(config, plist)
        temp_path = plist.name
    os.chmod(temp_path, 0o644)
    os.replace(temp_path, path)


port = os.environ["NOTIFY_PORT"]
write_plist(
    os.environ["LISTENER_PLIST"],
    {
        "Label": os.environ["LISTENER_LABEL"],
        "ProgramArguments": [
            os.environ["PYTHON_BIN"],
            os.environ["LISTENER_BIN"],
            "--host",
            "127.0.0.1",
            "--port",
            port,
            "--notifier",
            os.environ["NOTIFIER_BIN"],
        ],
        "RunAtLoad": True,
        "KeepAlive": True,
        "ProcessType": "Background",
        "StandardOutPath": os.environ["LISTENER_LOG"],
        "StandardErrorPath": os.environ["LISTENER_LOG"],
    },
)
write_plist(
    os.environ["TUNNEL_PLIST"],
    {
        "Label": os.environ["TUNNEL_LABEL"],
        "ProgramArguments": [
            os.environ["TUNNEL_BIN"],
            os.environ["NOTIFY_HOST"],
        ],
        "EnvironmentVariables": {
            "AGENT_NOTIFY_PORT": port,
        },
        "RunAtLoad": True,
        "KeepAlive": {
            "SuccessfulExit": False,
        },
        "ProcessType": "Background",
        "ThrottleInterval": 10,
        "StandardOutPath": os.environ["TUNNEL_LOG"],
        "StandardErrorPath": os.environ["TUNNEL_LOG"],
    },
)
PY

run_launchctl_or_rollback() {
    local status

    if "$launchctl_bin" "$@"; then
        return 0
    else
        status=$?
    fi

    bootout_agent "$listener_label"
    bootout_agent "$tunnel_label"
    return "$status"
}

run_launchctl_or_rollback bootstrap "gui/$UID" "$listener_plist"
run_launchctl_or_rollback bootstrap "gui/$UID" "$tunnel_plist"
run_launchctl_or_rollback kickstart -k "gui/$UID/$listener_label"
run_launchctl_or_rollback kickstart -k "gui/$UID/$tunnel_label"

echo "Installed agent notifications for $host."
