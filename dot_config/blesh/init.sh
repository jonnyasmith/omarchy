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

# --- Keyboard protocol under herdr ------------------------------------------
# `;` has no control-character encoding -- 59 & 0x1f is 27, i.e. ESC -- so
# Ctrl+; exists only over a modern key protocol. foot always emits it as
# \e[27;5;59~, and tmux re-encodes it as \e[59;5u for the pane.
#
# herdr is the odd one out, and not because it lacks the plumbing: it answers
# DA2 as a generic xterm (`1;0;0`), so ble.sh selects xterm's modifyOtherKeys,
# but herdr ignores \e[>4;2m and only re-encodes modified keys for a pane that
# pushed the kitty keyboard protocol (\e[>1u). Ctrl+; then reaches bash as a
# bare `;`. nvim gets the key right in the same pane because nvim asks for the
# kitty protocol.
#
# ble.sh picks the method from the terminal it identified and exposes no
# option to override it (`ble/term/modifyOtherKeys/.update`), so the identity
# is what has to change: kitty:* selects the protocol, and the branch reads
# the DA2 reply for the version, which must be >= 23. ble.sh then pushes
# \e[>1u when it takes the terminal and pops it before running a command, so
# no child program inherits a protocol it did not ask for. The other three
# things this identity controls are all true of herdr anyway: `\e[N q` cursor
# shapes, synchronized updates, and kitty CSI-u key decoding.
#
# term_DA2R fires just after ble.sh parses the DA2 reply -- earlier than that
# and detection overwrites this.
#
# Rewriting the identity is not enough on its own: ble/term/DA2/notify has
# already re-resolved the key protocol from the xterm identity by the time the
# hook runs (it calls ble/term/modifyOtherKeys/reset just before invoking
# term_DA2R), so the first prompt of a pane sits in modifyOtherKeys -- which
# herdr ignores -- and Ctrl+; arrives as a bare `;`. It only healed on the
# next prompt, because the leave/enter pair around a command re-resolves the
# method and finds kitty by then. Hence the second reset below: it re-runs the
# resolution against the identity this hook just wrote, so the protocol is
# pushed before the first prompt is drawn. `reset` is a no-op when ble.sh has
# not taken the terminal yet, and the enter at attach then picks kitty up.
if [[ $HERDR_ENV ]]; then
  function ble/term/herdr-kitty-protocol.hook {
    _ble_term_TERM[0]=kitty:23
    _ble_term_DA2R[0]='1;4023;23'
    ble/term/modifyOtherKeys/reset
  }
  blehook term_DA2R+=ble/term/herdr-kitty-protocol.hook
fi

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
# Both only ever fire in a bare terminal window: Ctrl+Space is the prefix key
# of tmux (tmux.conf `set -g prefix C-Space`) and of herdr
# (~/.config/herdr/config.toml `prefix = "ctrl+space"`), so inside either
# multiplexer the key is swallowed before bash sees it, which is why the
# accept key is Ctrl+; and Ctrl+Space is only kept for a bare window.
#
# Ctrl+; is the one to press. It rides the same wire everywhere: foot emits
# \e[27;5;59~ directly, tmux forwards it as \e[59;5u because tmux.conf sets
# `extended-keys always`, and herdr sends the CSI-u form too now that the
# block above makes ble.sh speak the kitty protocol there. Alt+; stays bound
# as the no-protocol fallback -- it is ESC ; on the wire, so it survives a
# terminal that has none of this.
#
# ESC ; does not collide with the C-[ cancel below. ble.sh's decoder waits out
# the escape timeout, so a lone ESC still cancels the suggestion and ESC
# followed by anything else is read as a meta key, as it always was.
ble-bind -m auto_complete -f 'M-;' auto_complete/insert
ble-bind -m auto_complete -f 'C-;' auto_complete/insert
ble-bind -m auto_complete -f 'C-SP' auto_complete/insert
ble-bind -m auto_complete -f 'C-@' auto_complete/insert
ble-bind -m auto_complete -f 'C-[' auto_complete/cancel

# ble.sh binds S-RET to "accept suggestion" by default (Right-arrow and End
# already do that, and Alt+; now does too). Reclaim it for zsh's literal
# newline, in both keymaps so it behaves the same with a suggestion showing.
# `newline` is the widget that inserts LF; `insert-string \n` would insert a
# literal backslash-n.
ble-bind -m emacs -f 'S-RET' newline
ble-bind -m auto_complete -f 'S-RET' newline
