# tmux-simple-manager

A simple, clear tmux setup focused on sessions and windows while keeping
tmux's default keybindings wherever possible.

## Features

- Clear session and window status
- Interactive session manager
- Create, rename, switch and delete sessions
- Create and manage windows using familiar tmux defaults
- Vim-style copy mode
- Wayland clipboard support
- Minimal status bar with contextual prefix shortcuts

## Requirements

- tmux
- fzf
- wl-clipboard on Wayland

## Keybindings

### Sessions

- `prefix + s` - session manager
- `prefix + C` - create session
- `prefix + $` - rename current session

Inside the session manager:

- `Enter` - switch
- `Ctrl+n` - create
- `Ctrl+r` - rename
- `Ctrl+x` - delete
- `Esc` - close

### Windows

- `prefix + c` - create window
- `prefix + ,` - rename window
- `prefix + &` - delete window
- `prefix + 1..9` - switch window
- `prefix + n` - next window
- `prefix + p` - previous window
