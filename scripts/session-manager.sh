#!/usr/bin/env bash

CLIENT="$(tmux display-message -p '#{client_name}')"
TAB=$'\t'

pause_message() {
	printf '%s Press Enter to continue.' "$1"
	IFS= read -r
}

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

choose_destination_session() {
	local choice

	choice="$({
		printf 'new\t-\t+ New session\n'
		tmux list-sessions -F "existing${TAB}#{session_name}${TAB}#{session_name}"
	} | fzf \
		--reverse \
		--cycle \
		--border \
		--no-sort \
		--delimiter="$TAB" \
		--with-nth=3.. \
		--prompt='MOVE TO > ' \
		--header='ENTER choose destination   ESC cancel')" || return 1

	printf '%s\n' "$choice"
}

create_destination_session() {
	local name created

	NEW_DESTINATION_SESSION=""
	NEW_DESTINATION_PLACEHOLDER=""

	printf 'New destination session name [blank = auto]: '
	IFS= read -r name

	if [[ -n "$name" ]] && tmux has-session -t "=$name" 2>/dev/null; then
		pause_message "Session \"$name\" already exists."
		return 1
	fi

	if [[ -n "$name" ]]; then
		created="$(
			tmux new-session -d -P \
				-F "#{session_name}${TAB}#{window_id}" \
				-s "$name"
		)" || return 1
	else
		created="$(
			tmux new-session -d -P \
				-F "#{session_name}${TAB}#{window_id}"
		)" || return 1
	fi

	IFS="$TAB" read -r NEW_DESTINATION_SESSION NEW_DESTINATION_PLACEHOLDER <<<"$created"
}

move_selected() {
	local -a selected_lines=("$@")
	local -A windows=()
	local -A source_sessions=()
	local line type session window_id _

	for line in "${selected_lines[@]}"; do
		IFS="$TAB" read -r type session window_id _ <<<"$line"

		if [[ "$type" == "window" ]]; then
			windows["$window_id"]=1
			source_sessions["$window_id"]="$session"
		fi
	done

	if ((${#windows[@]} == 0)); then
		pause_message 'Move works on window rows. Select one or more windows.'
		return
	fi

	local destination_choice destination_type destination placeholder_window
	destination_choice="$(choose_destination_session)" || return
	IFS="$TAB" read -r destination_type destination _ <<<"$destination_choice"

	if [[ "$destination_type" == "new" ]]; then
		create_destination_session || return
		destination="$NEW_DESTINATION_SESSION"
		placeholder_window="$NEW_DESTINATION_PLACEHOLDER"
	fi

	local moved_count=0
	local skipped_count=0
	local failed_count=0

	for window_id in "${!windows[@]}"; do
		if [[ "${source_sessions[$window_id]}" == "$destination" ]]; then
			((skipped_count += 1))
			continue
		fi

		if tmux move-window -d -a \
			-s "$window_id" \
			-t "=$destination:{end}"; then
			((moved_count += 1))
		else
			((failed_count += 1))
		fi
	done

	if [[ "$destination_type" == "new" ]]; then
		if ((moved_count > 0)); then
			tmux kill-window -t "$placeholder_window" 2>/dev/null || true
		else
			tmux kill-session -t "=$destination" 2>/dev/null || true
		fi
	fi

	if ((failed_count > 0)); then
		pause_message "Moved $moved_count window(s), skipped $skipped_count, failed $failed_count."
	elif ((moved_count == 0)); then
		pause_message "No windows moved; $skipped_count already belong to that session."
	fi
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
				--header=$'ENTER open   TAB select\nCTRL-N new   CTRL-R rename\nCTRL-T move   CTRL-X delete   ESC close' \
				--expect=enter,ctrl-n,ctrl-r,ctrl-t,ctrl-x
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
			pause_message 'Rename works on one item at a time.'
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

	ctrl-t)
		move_selected "${lines[@]}"
		;;

	ctrl-x)
		delete_selected "${lines[@]}"
		;;
	esac
done
