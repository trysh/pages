#!/usr/bin/env bash
# UserPromptSubmit hook.
#
# In some Claude Code environments (e.g. the remote/web execution
# environment) the client does not intercept certain slash commands, so
# they are delivered to the model as a plain text prompt instead of being
# executed locally. This hook detects those prompts and forwards the FULL
# prompt (command + any arguments) to a child `claude -c -p ...` process,
# which DOES execute the command, then injects the output as additional
# context so the model can show the result.
#
# Currently handled:
#   /context            -> render context usage
#   /compact            -> compact the conversation (default instructions)
#   /compact <prompt>   -> compact with the given focus instructions; the
#                          entire prompt after "/compact " is preserved and
#                          forwarded verbatim, never truncated.
set -euo pipefail

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // empty')

# Recursion guard: the child `claude` invocation below also fires this hook.
# Skip when our marker env var is already set, so we never fork-bomb.
if [ -n "${CLAUDE_CONTEXT_HOOK_ACTIVE:-}" ]; then
  exit 0
fi

# Only forward known slash commands. "/compact "* matches /compact with any
# trailing arguments; the bare forms match the no-argument invocations.
# Anything else (including look-alikes such as /compacting) is ignored.
case "$prompt" in
  "/context" | "/compact" | "/compact "*) ;;
  *) exit 0 ;;
esac

# Forward the prompt unchanged so the full /compact instruction is preserved.
out=$(CLAUDE_CONTEXT_HOOK_ACTIVE=1 claude -c -p "$prompt" 2>&1 || true)

jq -n --arg cmd "$prompt" --arg ctx "$out" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: ("Result of the `" + $cmd + "` command (rendered by a child Claude Code process):\n\n" + $ctx)
  }
}'
