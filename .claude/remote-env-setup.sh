#!/usr/bin/env bash
# =============================================================================
# Remote-environment SETUP SCRIPT snippet  (NOT a project hook)
# =============================================================================
# This file is a reference snippet meant to be PASTED INTO your Claude Code
# web/cloud *environment setup script* configuration (a trusted, user-
# controlled source that runs while the container is provisioned, BEFORE the
# agent session starts). It is intentionally NOT wired into
# .claude/settings.json, so it never runs as an (untrusted) project hook.
#
# What it does: installs the slash-passthrough hook into your TRUSTED user
# settings (~/.claude/settings.json) so /context and /compact are handled
# from the very first turn of every remote session — even if project hooks
# are not loaded.
#
# Idempotent: safe to run on every session start.
#
# CAVEAT: This is a FALLBACK. If the project hook in .claude/settings.json
# also loads, BOTH will fire and you'll get duplicate output. Only adopt
# this snippet if you confirm the project hook is NOT firing in your remote
# sessions.
# =============================================================================
set -euo pipefail

mkdir -p ~/.claude
settings=~/.claude/settings.json
[ -s "$settings" ] || echo '{}' > "$settings"

# Command string stored verbatim in settings.json. The surrounding quotes are
# part of the value so $CLAUDE_PROJECT_DIR expands and paths with spaces work.
hook_cmd='"$CLAUDE_PROJECT_DIR/.claude/hooks/slash-passthrough.sh"'

# Skip if an entry with this exact command is already registered.
if jq -e --arg c "$hook_cmd" \
     '[.hooks.UserPromptSubmit[]?.hooks[]?.command] | any(. == $c)' \
     "$settings" >/dev/null 2>&1; then
  echo "slash-passthrough hook already present in user settings; nothing to do."
  exit 0
fi

tmp=$(mktemp)
jq --arg c "$hook_cmd" '
  .hooks //= {} |
  .hooks.UserPromptSubmit //= [] |
  .hooks.UserPromptSubmit += [{
    "hooks": [{
      "type": "command",
      "command": $c,
      "timeout": 120,
      "statusMessage": "Rendering slash command..."
    }]
  }]
' "$settings" > "$tmp" && mv "$tmp" "$settings"

echo "Installed slash-passthrough hook into $settings"
