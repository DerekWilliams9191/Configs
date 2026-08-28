#!/usr/bin/env python3
import argparse
import json
import shutil
import socketserver
import subprocess
import sys
import time


MAX_REQUEST_SIZE = 8192
CLEAR_RETRY_DELAYS = (0.0, 0.2, 0.8)


def notification_command(notifier: str, request: dict) -> list[str]:
    action = request.get("action")
    if action == "notify":
        title = request.get("title")
        if not isinstance(title, str) or not title or len(title) > 512:
            raise ValueError("invalid notification title")
        return [
            notifier,
            "-title",
            title,
            "-message",
            "",
            "-sound",
            "default",
        ]

    group = request.get("group")
    if not isinstance(group, str) or not group or len(group) > 512:
        raise ValueError("invalid notification group")

    if action == "show":
        title = request.get("title")
        if not isinstance(title, str) or not title or len(title) > 512:
            raise ValueError("invalid notification title")
        message = request.get("message", "")
        if not isinstance(message, str) or len(message) > 512:
            raise ValueError("invalid notification message")
        return [
            notifier,
            "-title",
            title,
            "-message",
            message,
            "-group",
            group,
            "-sound",
            "default",
        ]
    if action == "clear":
        return [notifier, "-remove", group]
    raise ValueError("invalid notification action")


def run_notification(command: list[str]) -> None:
    subprocess.run(
        command,
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=5,
    )


def process_request(
    notifier: str,
    request: dict,
    clear_retry_delays: tuple[float, ...] = CLEAR_RETRY_DELAYS,
) -> None:
    command = notification_command(notifier, request)
    if request.get("action") != "clear":
        run_notification(command)
        return

    last_error = None
    for delay in clear_retry_delays:
        time.sleep(delay)
        try:
            run_notification(command)
            last_error = None
        except (OSError, subprocess.SubprocessError) as error:
            last_error = error
    if last_error:
        raise last_error


class NotificationHandler(socketserver.StreamRequestHandler):
    def handle(self) -> None:
        line = self.rfile.readline(MAX_REQUEST_SIZE + 2)
        try:
            if len(line) > MAX_REQUEST_SIZE + 1:
                raise ValueError("notification request is too large")
            request = json.loads(line)
            if not isinstance(request, dict):
                raise ValueError("notification request must be an object")
            process_request(
                self.server.notifier,
                request,
                self.server.clear_retry_delays,
            )
        except (
            json.JSONDecodeError,
            OSError,
            subprocess.SubprocessError,
            UnicodeDecodeError,
            ValueError,
        ) as error:
            print(f"agent-notify: {error}", file=sys.stderr, flush=True)


class NotificationServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True

    def __init__(
        self,
        address: tuple[str, int],
        notifier: str,
        clear_retry_delays: tuple[float, ...] = CLEAR_RETRY_DELAYS,
    ):
        self.notifier = notifier
        self.clear_retry_delays = clear_retry_delays
        super().__init__(address, NotificationHandler)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=45891)
    parser.add_argument("--notifier")
    args = parser.parse_args()

    notifier = args.notifier or shutil.which("terminal-notifier")
    if not notifier:
        parser.error("terminal-notifier is not installed")

    with NotificationServer((args.host, args.port), notifier) as server:
        server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
