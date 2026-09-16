// CloseCode plugin that forwards agent events to agent-notify.sh.
// agent-notify.sh reads Claude Code hook JSON on stdin, so this plugin
// translates CloseCode events into that format.
//
// Loaded from ~/.config/closecode/plugins/ (symlink created by the
// install scripts). Restart CloseCode after changes.

import { spawn } from "node:child_process"
import os from "node:os"
import path from "node:path"

const NOTIFY_SCRIPT = path.join(
  os.homedir(),
  ".config/Configs/agent-notifier/agent-notify.sh",
)

function send(payload) {
  try {
    const child = spawn(NOTIFY_SCRIPT, ["show"], {
      stdio: ["pipe", "ignore", "ignore"],
      detached: true,
    })
    child.on("error", () => {})
    child.stdin.write(JSON.stringify(payload))
    child.stdin.end()
    child.unref()
  } catch {
    // Notifications are best effort. Never break the agent.
  }
}

export const AgentNotifier = async ({ client }) => {
  async function isSubagentSession(sessionID) {
    if (!sessionID) return false
    try {
      const result = await client.session.get({ path: { id: sessionID } })
      return Boolean(result.data?.parentID)
    } catch {
      return false
    }
  }

  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        if (await isSubagentSession(event.properties?.sessionID)) return
        send({ hook_event_name: "Stop", background_tasks: [] })
        return
      }
      if (event.type === "session.error") {
        if (await isSubagentSession(event.properties?.sessionID)) return
        send({ hook_event_name: "StopFailure" })
      }
    },
    "permission.ask": async () => {
      send({ hook_event_name: "PermissionRequest" })
    },
    "tool.execute.before": async (input) => {
      if (input?.tool !== "question") return
      send({ hook_event_name: "PreToolUse", tool_name: "AskUserQuestion" })
    },
  }
}
