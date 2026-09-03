# Markup preview from the shell. Glob-sourced by ~/.bashrc, so this file needs
# no wiring.
#
# The whole implementation is ~/.config/omarchy/plugins/jonny.preview, next to
# the other personal tools that drive the desktop; this is only the name it
# answers to. The nvim keymap (nvim/lua/plugins/preview.lua) calls the same
# script with the buffer's path, which is the point: one renderer, so a document
# looks identical whichever side it was opened from.
#
# The name is `mp` because the nvim chord is `<Leader>mp` -- markup preview,
# spelled the same on both surfaces so neither has to be remembered separately.
# Markdown and HTML are the same command; the launcher dispatches on the
# extension.
#
#   mp             preview ./README.md
#   mp <file>      preview a .md, .html or .htm file, or focus its window if it
#                  is already open
#   mp --stop      stop every preview server
mp() {
	"${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/jonny.preview/preview.sh" "$@"
}

# Complete on previewable files and the one flag, because the default completion
# for a function is filenames-with-directories and it offers .png just as
# happily.
_mp_complete() {
	local cur=${COMP_WORDS[COMP_CWORD]}
	if [[ $cur == -* ]]; then
		mapfile -t COMPREPLY < <(compgen -W '--stop' -- "$cur")
		return
	fi
	mapfile -t COMPREPLY < <(
		compgen -f -X '!*.[Mm][Dd]' -- "$cur"
		compgen -f -X '!*.[Hh][Tt][Mm]' -- "$cur"
		compgen -f -X '!*.[Hh][Tt][Mm][Ll]' -- "$cur"
		compgen -d -S / -- "$cur"
	)
}
complete -o nospace -F _mp_complete mp
