#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load all plugin configuration
tmux source-file "$CURRENT_DIR/config.tmux"

# Ctrl+b s = session manager
tmux bind-key s display-popup -E \
  -T " SESSIONS " \
  -w 70% -h 60% \
  -s "bg=colour234,fg=colour250" \
  -S "fg=colour81" \
  "$CURRENT_DIR/scripts/session-manager.sh"

# Ctrl+b C = create session
# Blank = automatic tmux name
tmux bind-key C command-prompt \
  -p "New session name [blank = auto]: " \
  "if-shell -F '#{==:%1,}' 'new-session' 'new-session -s \"%1\"'"
