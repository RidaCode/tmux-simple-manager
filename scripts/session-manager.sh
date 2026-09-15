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

delete_selected() {
	local -a selected_lines=("$@")
	local -A sessions=()
	local -A windows=()
	local line type session window_id _

	# Sessions take precedence over their child windows. If both a session and
	# one of its windows are selected, deleting the session is enough.
	for line in "${selected_lines[@]}"; do
		IFS="$TAB" read -r type session window_id _ <<<"$line"
		[[ "$type" == "session" ]] && sessions["$session"]=1
	done

	for line in "${selected_lines[@]}"; do
		IFS="$TAB" read -r type session window_id _ <<<"$line"

		if [[ "$type" == "window" && -z "${sessions[$session]+x}" ]]; then
			windows["$window_id"]=1
		fi
	done

	local session_count=${#sessions[@]}
	local window_count=${#windows[@]}

	if ((session_count == 0 && window_count == 0)); then
		return
	fi

	printf 'Delete %d session(s) and %d window(s)? [y/N]: ' \
		"$session_count" "$window_count"
	IFS= read -r answer

	[[ "$answer" =~ ^[Yy]$ ]] || return

	for window_id in "${!windows[@]}"; do
		tmux kill-window -t "$window_id" 2>/dev/null || true
	done

	for session in "${!sessions[@]}"; do
		tmux kill-session -t "=$session" 2>/dev/null || true
	done
}

while true; do
	result="$(
		build_tree |
			fzf \
				--reverse \
				--cycle \
				--border \
				--no-sort \
				--multi \
				--bind='tab:toggle+down,shift-tab:toggle+up' \
				--marker='✓ ' \
				--delimiter="$TAB" \
				--with-nth=4.. \
				--prompt='TMUX > ' \
				--header=$'ENTER open   TAB select\nCTRL-N new   CTRL-R rename\nCTRL-X delete selected   ESC close' \
				--expect=enter,ctrl-n,ctrl-r,ctrl-x
	)" || exit 0

	key="$(printf '%s\n' "$result" | sed -n '1p')"
	mapfile -t lines < <(printf '%s\n' "$result" | tail -n +2)

	[[ ${#lines[@]} -eq 0 ]] && continue

	line="${lines[0]}"
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

		if ((${#lines[@]} > 1)); then
			printf 'Rename works on one item at a time. Press Enter to continue.'
			IFS= read -r
			continue
		fi

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
		delete_selected "${lines[@]}"
		;;
	esac
done
