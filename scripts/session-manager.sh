#!/usr/bin/env bash

CLIENT="$(tmux display-message -p '#{client_name}')"
TAB=$'\t'

build_tree() {
	local current_session current_window_id

	current_session="$(tmux display-message -p '#{session_name}')"
	current_window_id="$(tmux display-message -p '#{window_id}')"

	while IFS="$TAB" read -r session attached; do
		local session_marker=""
		local attached_marker=""

		[[ "$session" == "$current_session" ]] && session_marker=" *"
		((attached > 0)) && attached_marker="  attached"

		printf 'session\t%s\t-\t▾ %s%s%s\n' \
			"$session" "$session" "$session_marker" "$attached_marker"

		mapfile -t windows < <(
			tmux list-windows -t "=$session" \
				-F "#{window_id}${TAB}#{window_index}${TAB}#{window_name}"
		)

		local last=$((${#windows[@]} - 1))

		for i in "${!windows[@]}"; do
			IFS="$TAB" read -r window_id window_index window_name <<<"${windows[$i]}"

			local branch='├─'
			local window_marker=""

			((i == last)) && branch='└─'
			[[ "$window_id" == "$current_window_id" ]] && window_marker=" *"

			printf 'window\t%s\t%s\t    %s %s: %s%s\n' \
				"$session" "$window_id" "$branch" "$window_index" "$window_name" "$window_marker"
		done
	done < <(
		tmux list-sessions \
			-F "#{session_name}${TAB}#{session_attached}"
	)
}

while true; do
	result="$(
		build_tree |
			fzf \
				--reverse \
				--cycle \
				--border \
				--no-sort \
				--delimiter="$TAB" \
				--with-nth=4.. \
				--prompt='TMUX > ' \
				--header='ENTER open   CTRL-N new session   CTRL-R rename   CTRL-X delete   ESC close' \
				--expect=enter,ctrl-n,ctrl-r,ctrl-x
	)" || exit 0

	key="$(printf '%s\n' "$result" | sed -n '1p')"
	line="$(printf '%s\n' "$result" | sed -n '2p')"

	IFS="$TAB" read -r type session window_id _ <<<"$line"

	case "$key" in
	enter | "")
		[[ -z "$type" ]] && continue

		if [[ "$type" == "session" ]]; then
			tmux switch-client -c "$CLIENT" -t "=$session"
		else
			tmux switch-client -c "$CLIENT" -t "=$session"
			tmux select-window -t "$window_id"
		fi

		exit 0
		;;

	ctrl-n)
		printf 'New session name [blank = auto]: '
		IFS= read -r name

		if [[ -n "$name" ]]; then
			tmux new-session -d -s "$name"
			tmux switch-client -c "$CLIENT" -t "=$name"
		else
			name="$(tmux new-session -d -P -F '#{session_name}')"
			tmux switch-client -c "$CLIENT" -t "=$name"
		fi

		exit 0
		;;

	ctrl-r)
		[[ -z "$type" ]] && continue

		if [[ "$type" == "session" ]]; then
			printf 'Rename session "%s" to: ' "$session"
			IFS= read -r name

			if [[ -n "$name" ]]; then
				tmux rename-session -t "=$session" "$name"
			fi
		else
			current_name="$(
				tmux display-message -p -t "$window_id" '#{window_name}'
			)"

			printf 'Rename window "%s" to: ' "$current_name"
			IFS= read -r name

			if [[ -n "$name" ]]; then
				tmux rename-window -t "$window_id" "$name"
			fi
		fi
		;;

	ctrl-x)
		[[ -z "$type" ]] && continue

		if [[ "$type" == "session" ]]; then
			printf 'Delete session "%s"? [y/N]: ' "$session"
			IFS= read -r answer

			if [[ "$answer" =~ ^[Yy]$ ]]; then
				tmux kill-session -t "=$session"
			fi
		else
			window_name="$(
				tmux display-message -p -t "$window_id" '#{window_name}'
			)"

			printf 'Delete window "%s"? [y/N]: ' "$window_name"
			IFS= read -r answer

			if [[ "$answer" =~ ^[Yy]$ ]]; then
				tmux kill-window -t "$window_id"
			fi
		fi
		;;
	esac
done
