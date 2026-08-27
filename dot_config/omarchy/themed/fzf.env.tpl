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

# `header` and `info` are on the same mix as FZF_THEME_DIM below, not on
# `muted`, and for the same reason: the header carries the keybinding legend,
# which has to be readable. Under Nord, `muted` renders it at #4c566a on a
# #2e3440 background, through a 0.9-alpha terminal -- i.e. invisible.
FZF_THEME_OPTS="--color=fg:{{ foreground }},bg:-1,gutter:-1,fg+:{{ bright_foreground }},bg+:{{ selection_background }},hl:{{ accent }},hl+:{{ accent }},info:{{ mix background foreground 60% }},border:{{ mix background foreground 30% }},separator:{{ mix background foreground 20% }},prompt:{{ accent }},pointer:{{ accent }},marker:{{ green }},spinner:{{ accent }},header:{{ mix background foreground 60% }},query:{{ foreground }},disabled:{{ muted }},preview-fg:{{ foreground }},preview-bg:-1,scrollbar:{{ mix background foreground 30% }},label:{{ muted }}"

# For the parts of a row a caller draws itself, which fzf cannot colour: it
# applies fg/fg+ per line, and only the fuzzy-match highlight is finer than
# that.
FZF_THEME_ACCENT="{{ accent }}"
FZF_THEME_MUTED="{{ muted }}"

# Deliberately a mix rather than `muted`. This one is for a column of text that
# is meant to be read and searched, only less loudly than the row's subject;
# `muted` is whatever each theme calls furniture, and in Nord that is #4c566a,
# which is a border colour, not a text colour. A fixed mix is legible in every
# theme because it is defined against that theme's own background.
FZF_THEME_DIM="{{ mix background foreground 60% }}"
