# ble.sh configuration. Sourced by ble.sh itself (it looks for
# $XDG_CONFIG_HOME/blesh/init.sh), so nothing in .bashrc references it.
#
# ble.sh is the bash replacement for zsh-autosuggestions +
# fast-syntax-highlighting: a full re-implementation of the line editor that
# reads readline's bindings — including Omarchy's inputrc — and then drives
# the terminal itself.
#
# Only genuine departures from ble.sh's defaults belong here. Inline
# suggestions, menu completion, ambiguous matching and syntax highlighting are
# all on out of the box.

# --- Autosuggestions (zsh-autosuggestions) ----------------------------------
# ble.sh defaults to a light *block* (bg=254,fg=238) for the ghost text, which
# reads as a selection rather than a hint. Grey foreground on the normal
# background is what zsh-autosuggestions does (its default is fg=8).
ble-face auto_complete='fg=242'

# History is the only suggestion source, which is what zsh-autosuggestions
# offered. ble.sh's extra `syntax` source — inline filename and command-name
# guesses — is disabled because it completes filenames *inside option
# clusters*: with it on, typing `echo -lR` in a directory containing README.md
# ghosts `EADME.md`, and Right-arrow inserts `echo -lREADME.md`. That fires on
# any `-xY` flag whose trailing letters prefix a local file, which is often
# enough to make the ghost text untrustworthy. TAB still completes filenames.
#
# To trade back: drop this line for `syntax-suppress-ambiguous`, which keeps
# the source but only suggests when the match is unambiguous. It does not fix
# the option-cluster case — that guess is unambiguous, just wrong.
bleopt complete_auto_complete_opts=syntax-disabled

# --- Syntax highlighting (fast-syntax-highlighting) -------------------------
# ble.sh flags an unresolvable command with a red *background*, which is much
# louder than fast-syntax-highlighting's red foreground on a still-incomplete
# command name — i.e. on almost every keystroke of a long command.
ble-face syntax_error='fg=203'

# --- Keybindings ------------------------------------------------------------
# Ported from .zshrc:
#   bindkey '^ '          autosuggest-accept
#   bindkey '\e'          autosuggest-clear
#   bindkey '^[[27;2;13~' insert-buffer-newline
#
# The auto_complete keymap is only active while a suggestion is on screen, so
# the first two do not shadow the normal meaning of those keys the rest of the
# time: C-SP stays set-mark, ESC stays the meta prefix.
# Ctrl+Space reaches ble.sh as C-@ from a terminal sending a bare NUL, and as
# C-SP from one with modifyOtherKeys on; they are distinct keys to the decoder.
ble-bind -m auto_complete -f 'C-SP' auto_complete/insert
ble-bind -m auto_complete -f 'C-@' auto_complete/insert
ble-bind -m auto_complete -f 'C-[' auto_complete/cancel

# ble.sh binds S-RET to "accept suggestion" by default (Right-arrow and End
# already do that, and Ctrl+Space now does too). Reclaim it for zsh's literal
# newline, in both keymaps so it behaves the same with a suggestion showing.
# `newline` is the widget that inserts LF; `insert-string \n` would insert a
# literal backslash-n.
ble-bind -m emacs -f 'S-RET' newline
ble-bind -m auto_complete -f 'S-RET' newline
