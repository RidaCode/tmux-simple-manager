#!/usr/bin/env bash

while true; do
  result="$(
    tmux list-sessions \
      -F '#{session_name}	#{session_windows} windows	#{?session_attached,attached,}' |
      fzf \
        --reverse \
        --cycle \
        --border \
        --prompt='SESSION > ' \
        --header='ENTER switch   CTRL-N new   CTRL-R rename   CTRL-X delete   ESC close' \
        --expect=enter,ctrl-n,ctrl-r,ctrl-x
  )" || exit 0

  key="$(printf '%s\n' "$result" | sed -n '1p')"
  line="$(printf '%s\n' "$result" | sed -n '2p')"

  session="${line%%$'\t'*}"

  case "$key" in
  enter | "")
    if [[ -n "$session" ]]; then
      tmux switch-client -t "=$session"
      exit 0
    fi
    ;;

  ctrl-n)
    printf 'New session name [blank = auto]: '
    IFS= read -r name

    if [[ -n "$name" ]]; then
      tmux new-session -d -s "$name"
      tmux switch-client -t "=$name"
    else
      name="$(tmux new-session -d -P -F '#{session_name}')"
      tmux switch-client -t "=$name"
    fi

    exit 0
    ;;

  ctrl-r)
    [[ -z "$session" ]] && continue

    printf 'Rename "%s" to: ' "$session"
    IFS= read -r name

    if [[ -n "$name" ]]; then
      tmux rename-session -t "=$session" "$name"
    fi
    ;;

  ctrl-x)
    [[ -z "$session" ]] && continue

    printf 'Delete session "%s"? [y/N]: ' "$session"
    IFS= read -r answer

    if [[ "$answer" =~ ^[Yy]$ ]]; then
      tmux kill-session -t "=$session"
    fi
    ;;
  esac
done
