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

# Dark status bar
set -g status-style "bg=colour234,fg=colour250"

# Current session
set -g status-left \
  "#[bg=colour31,fg=colour231,bold] SESSION: #S #[bg=colour234,fg=colour240] | "

set -g status-left-length 30

# Inactive windows
setw -g window-status-format \
  "#[fg=colour245] #I:#W "

# Current window
setw -g window-status-current-format \
  "#[bg=colour81,fg=colour234,bold] #I:#W* #[bg=colour234]"

# Shortcuts + clock
set -g status-right \
  "#[fg=colour244]s:sessions  C:new-session  c:new-window  ,:rename  &:kill #[fg=colour250] %H:%M "

set -g status-right-length 70

# Pane borders
set -g pane-border-style "fg=colour238"
set -g pane-active-border-style "fg=colour81"
