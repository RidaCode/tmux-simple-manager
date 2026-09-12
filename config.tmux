# ==================================================
# CORE
# ==================================================

# Vim-style copy mode
setw -g mode-keys vi

# More scrollback
set -g history-limit 50000

# Proper colors
set -g default-terminal "tmux-256color"
set -as terminal-features ",xterm-256color:RGB"

# Fast Escape for Vim/Neovim
set -sg escape-time 10

# Focus events
set -g focus-events on

# Wayland clipboard
bind-key -T copy-mode-vi y \
  send-keys -X copy-pipe-and-cancel "wl-copy"


# ==================================================
# WINDOWS
# ==================================================

set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# If a session dies, move to another session
set -g detach-on-destroy off

# Ctrl+b c = create window, optional name
bind c command-prompt \
  -p "New window name [blank = auto]: " \
  "if-shell -F '#{==:%1,}' 'new-window' 'new-window -n \"%1\"'"

# Keep tmux defaults:
#
# Ctrl+b ,       rename window
# Ctrl+b &       delete window
# Ctrl+b 1..9    switch window
# Ctrl+b n       next window
# Ctrl+b p       previous window


# ==================================================
# APPEARANCE
# ==================================================

# Overall status bar background and default text color
set -g status-style "bg=colour234,fg=colour240"

# Left side: current session name
set -g status-left \
  "#[fg=colour241] SESSION: #S #[fg=colour237] | "

# Maximum width of the left section
set -g status-left-length 30

# Inactive windows: keep them very dim
setw -g window-status-format \
  "#[fg=colour238] #I:#W "

# Active window: slightly brighter so it is still easy to find
setw -g window-status-current-format \
  "#[fg=colour245] #I:#W* "

# Right side: shortcut reminders and clock
# Keep shortcut text dim, with the clock slightly brighter
set -g status-right \
  "#[fg=colour238]s:sessions  C:new-session  c:new-window  ,:rename  &:kill #[fg=colour242] %H:%M "

# Maximum width of the right section
set -g status-right-length 70
