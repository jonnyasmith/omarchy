# ble.sh integrations for the tools Omarchy's bash rc already loaded.
#
# Sourced after $OMARCHY_PATH/default/bash/rc, which does two things ble.sh
# needs told about:
#
#   source /usr/share/fzf/completion.bash
#   source /usr/share/fzf/key-bindings.bash
#
# fzf's stock bash scripts assume readline. Under ble.sh they misfire: fzf
# installs `complete -F _fzf_path_completion` for a long list of commands, and
# ble.sh calls those compspecs while generating inline suggestions — where
# fzf's function, expecting to be driven by a TAB press, returns a mangled
# candidate. Typing `ls -la` suggested `[-lAGENTS.md]`.
#
# ble.sh ships patched versions. Each one detects that fzf's script is already
# loaded and only applies its advice wrappers, so this does not double-load.
if [[ ${BLE_VERSION-} ]] && command -v fzf >/dev/null 2>&1; then
	ble-import -d contrib/integration/fzf-completion
	ble-import -d contrib/integration/fzf-key-bindings
	# Render the TAB completion menu through fzf. This is the closest thing
	# to zsh's fzf-tab, and it is why the menu is worth having at all with
	# large candidate sets.
	ble-import -d contrib/integration/fzf-menu
fi

# zoxide's bash init hooks the prompt; ble.sh's version hooks its own chpwd
# instead, which is cheaper and does not fight PROMPT_COMMAND.
if [[ ${BLE_VERSION-} ]] && command -v zoxide >/dev/null 2>&1; then
	ble-import -d contrib/integration/zoxide
fi
