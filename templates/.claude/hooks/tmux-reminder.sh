#!/usr/bin/env bash
# PreToolUse hook: remind Claude about active tmux panes before Bash calls

panes=$(tmux list-windows -F '#{window_name}' 2>/dev/null | grep '^mcp:' | sed 's/^mcp://' | tr '\n' ', ' | sed 's/,$//')

if [ -n "$panes" ]; then
  jq -n --arg panes "$panes" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      additionalContext: ("REMINDER: You have active tmux panes: " + $panes + " — consider using mcp__tmux__send instead of Bash for commands that benefit from persistent shell state.")
    }
  }'
fi

exit 0
