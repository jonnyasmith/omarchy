# Markdown preview from the shell. Glob-sourced by ~/.bashrc, so this file
# needs no wiring.
#
# The whole implementation is ~/.config/omarchy/plugins/jonny.mdpreview, next to
# the other personal tools that drive the desktop; this is only the name it
# answers to. The nvim keymap (nvim/lua/plugins/mdpreview.lua) calls the same
# script with the buffer's path, which is the point: one renderer, so a document
# looks identical whichever side it was opened from.
#
#   mdp             preview ./README.md
#   mdp <file.md>   preview a file, or focus its window if it is already open
#   mdp --stop      stop every preview server
mdp() {
	"${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/jonny.mdpreview/mdpreview.sh" "$@"
}

# Complete on markdown files and the one flag, because the default completion
# for a function is filenames-with-directories and it offers .png just as
# happily.
_mdp_complete() {
	local cur=${COMP_WORDS[COMP_CWORD]}
	if [[ $cur == -* ]]; then
		mapfile -t COMPREPLY < <(compgen -W '--stop' -- "$cur")
		return
	fi
	mapfile -t COMPREPLY < <(compgen -f -X '!*.[Mm][Dd]' -- "$cur"; compgen -d -S / -- "$cur")
}
complete -o nospace -F _mdp_complete mdp
