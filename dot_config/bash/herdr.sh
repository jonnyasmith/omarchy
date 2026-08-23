# Herdr dev-layout overrides. Sourced by ~/.bashrc *after*
# $OMARCHY_PATH/default/bash/rc, so these deliberately win over Omarchy's
# hdl/hds (forked from omarchy 4.0.0-1, default/bash/fns/herdr).
#
# The only change is pane labels. Herdr keeps a `label` per pane that is
# separate from the app-controlled terminal title -- both show up in
# `herdr pane list` -- and Omarchy's layouts never set one, so every pane in
# an hdl tab comes out with "label":null. Tmux has no equivalent worth using:
# its pane_title is overwritten by whatever the pane runs (bash writes
# "user@host:~", codex writes the repo name), and pane-border-status is off,
# so tdl/tds are left alone.
#
# Roles: editor, cmd (the small bottom shell), diff, and the AI panes, which
# are labelled with their own command so two of them stay distinguishable.
#
# After `omarchy update`, diff these against
# /usr/share/omarchy/default/bash/fns/herdr to pick up upstream changes.
# hsl (the swarm layout) is not forked: every pane there runs the same
# command, so a label adds nothing.

# Label a pane, quietly. Extra words are joined by herdr into one label.
# Usage: _herdr_label <pane_id> <label>...
_herdr_label() {
	local pane="$1"
	shift
	herdr pane rename "$pane" "$@" >/dev/null
}

# Create a Herdr Dev Layout with editor, ai, and terminal
# Usage: hdl <c|cx|codex|other_ai> [<second_ai>]
hdl() {
	[[ -z $1 ]] && {
		echo "Usage: hdl <c|cx|codex|other_ai> [<second_ai>]"
		return 1
	}
	[[ -z $HERDR_PANE_ID ]] && {
		echo "You must start herdr to use hdl."
		return 1
	}

	local current_dir="${PWD}"
	local editor_pane cmd_pane ai_pane ai2_pane
	local ai="$1"
	local ai2="${2:-}"

	# Use HERDR_PANE_ID for the pane we're running in (stable even if focus moves)
	editor_pane="$HERDR_PANE_ID"

	# Name the current tab after the base directory name
	herdr tab rename "$HERDR_TAB_ID" "$(basename "$current_dir")" >/dev/null

	# Split tab vertically - top 85%, bottom 15%. Upstream discards this pane
	# id; it is captured here so the shell pane can be labelled.
	cmd_pane=$(_herdr_split "$editor_pane" down 0.85 "$current_dir")

	# Split editor pane horizontally - AI on right 30%
	ai_pane=$(_herdr_split "$editor_pane" right 0.7 "$current_dir")

	_herdr_label "$editor_pane" editor
	_herdr_label "$cmd_pane" cmd
	_herdr_label "$ai_pane" "${ai%% *}"

	# If second AI provided, split the AI pane vertically
	if [[ -n $ai2 ]]; then
		ai2_pane=$(_herdr_split "$ai_pane" down 0.5 "$current_dir")
		_herdr_label "$ai2_pane" "${ai2%% *}"
		herdr pane run "$ai2_pane" "$ai2" >/dev/null
	fi

	# Run ai in the right pane
	herdr pane run "$ai_pane" "$ai" >/dev/null

	# Run nvim in the left pane
	herdr pane run "$editor_pane" "$EDITOR ." >/dev/null
}

# Create a Herdr Dev Square layout with editor, diff watch, terminal, and opencode
# Usage: hds
hds() {
	[[ -n $1 ]] && {
		echo "Usage: hds"
		return 1
	}
	[[ -z $HERDR_PANE_ID ]] && {
		echo "You must start herdr to use hds."
		return 1
	}

	local current_dir="${PWD}"
	local editor_pane diff_pane terminal_pane opencode_pane

	editor_pane="$HERDR_PANE_ID"

	herdr tab rename "$HERDR_TAB_ID" "$(basename "$current_dir")" >/dev/null

	terminal_pane=$(_herdr_split "$editor_pane" down 0.5 "$current_dir")
	diff_pane=$(_herdr_split "$editor_pane" right 0.5 "$current_dir")
	opencode_pane=$(_herdr_split "$terminal_pane" right 0.5 "$current_dir")

	_herdr_label "$editor_pane" editor
	_herdr_label "$diff_pane" diff
	_herdr_label "$terminal_pane" cmd
	_herdr_label "$opencode_pane" opencode

	herdr pane run "$editor_pane" "nvim ." >/dev/null
	herdr pane run "$diff_pane" "hunk diff --watch" >/dev/null
	herdr pane run "$opencode_pane" "opencode" >/dev/null
}
