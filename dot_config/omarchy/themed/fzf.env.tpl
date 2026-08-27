# fzf palette for the active Omarchy theme. Rendered into
# ~/.local/state/omarchy/current/theme/fzf.env by every `omarchy theme set`,
# and sourced at run time by the scripts that want it -- currently the dev-ports
# picker (`plugins/jonny.ports/ports-tui.sh`).
#
# Omarchy themes every TUI it ships but not fzf, so without this the picker is
# fzf's stock 16-colour default in the middle of a themed desktop.
#
# Sourced by bash, so this file is shell syntax, not fzf syntax: one variable
# holding the flags rather than a config file, because fzf has no include and
# `FZF_DEFAULT_OPTS` belongs to the interactive shell, not to a script that must
# work when no rc file has been read.
#
# `bg` and `preview-bg` are deliberately `-1` (inherit) rather than the theme
# background: foot runs at alpha=0.9 here, and painting an opaque background
# across the pane would throw that translucency away. `gutter:-1` for the same
# reason -- it is the strip behind the pointer column.

FZF_THEME_OPTS="--color=fg:{{ foreground }},bg:-1,gutter:-1,fg+:{{ bright_foreground }},bg+:{{ selection_background }},hl:{{ accent }},hl+:{{ accent }},info:{{ muted }},border:{{ mix background foreground 30% }},separator:{{ mix background foreground 20% }},prompt:{{ accent }},pointer:{{ accent }},marker:{{ green }},spinner:{{ accent }},header:{{ muted }},query:{{ foreground }},disabled:{{ muted }},preview-fg:{{ foreground }},preview-bg:-1,scrollbar:{{ mix background foreground 30% }},label:{{ muted }}"

# For the parts of a row a caller draws itself, which fzf cannot colour: it
# applies fg/fg+ per line, and only the fuzzy-match highlight is finer than
# that.
FZF_THEME_ACCENT="{{ accent }}"
FZF_THEME_MUTED="{{ muted }}"
