#!/usr/bin/env bash
# UserPromptSubmit hook.
#
# In some Claude Code environments (e.g. the remote/web execution
# environment) the client does not intercept the "/context" slash command,
# so it is delivered to the model as a plain text prompt instead of being
# rendered locally. This hook detects that case: when the submitted prompt
# is exactly "/context", it runs `claude -c -p /context` in a child process
# (which DOES render the command) and injects the output as additional
# context so the model can show the result.
set -euo pipefail

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // empty')

# Recursion guard: the child `claude` invocation below also fires this hook.
# Skip when our marker env var is already set, so we never fork-bomb.
if [ "$prompt" != "/context" ] || [ -n "${CLAUDE_CONTEXT_HOOK_ACTIVE:-}" ]; then
  exit 0
fi

out=$(CLAUDE_CONTEXT_HOOK_ACTIVE=1 claude -c -p /context 2>&1 || true)

jq -n --arg ctx "$out" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: ("Result of the /context command (rendered by a child Claude Code process):\n\n" + $ctx)
  }
}'
