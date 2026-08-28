#!/bin/bash
#
# Modal fzf, for people who live in normal mode: a list that starts with no
# input line at all, moves under j/k, and only becomes a search box when you
# press `/`. Sourced by the pickers in ../jonny.*/; never run on its own.
#
#   vfzf --ctx 'usb drive' --keys 'r rescan' --back -- [fzf args...]
#
# Rows on stdin; on stdout a tag line and then the chosen row, read back with
# vfzf_tag and vfzf_row. Three outcomes rather than two:
#
#   0  chose   tag is '' for l/enter, or whatever a caller's own key printed
#   2  back    `h`: one level up the tree, nothing chosen
#   1  quit    `q`, esc or ctrl-c
#
# How the two modes actually work, since fzf has no notion of a mode:
#
#   * `--no-input` hides the input line and stops keystrokes reaching the
#     query, which is the whole trick -- it is what frees bare letters to be
#     bound as commands. `show-input` brings it back for `/`.
#   * the bare keys are `unbind`-ed on entering search so they type, and
#     `rebind`-ed on leaving it. Chords (ctrl-j, ctrl-k, alt-enter) are bound
#     in both modes, which is what makes movement possible while filtering.
#   * esc has to do two different things, so it is a `transform` reading
#     $FZF_INPUT_STATE: hidden means normal mode, so quit; anything else means
#     search mode, so return to normal.
#   * `clear-query` leads that chain rather than sitting inside the transform,
#     because an fzf action list that hides the input silently discards a query
#     change emitted after it -- leaving normal mode still filtered by a
#     pattern with no visible input line to explain why. Tested on 0.74.3, in
#     both orders.
#   * going back is `print(sentinel)+accept` rather than an `--expect` key,
#     because `--expect` captures the key in *both* modes and would stop `h`
#     ever being typed into a search. `print` needs `accept`, not `abort`:
#     abort throws the output queue away.
#
# Keys deliberately left alone: ctrl-c and ctrl-g abort, because every terminal
# user has that reflex, and Backspace is 0x7f rather than ctrl-h's 0x08, so
# binding `h` never steals it from the query line.

VFZF_BACK='__vfzf:back'

# Every bare key bound below. One list, used to bind and to unbind, so a key
# added to normal mode cannot be left typing itself into a search.
VFZF_BARE='j,k,g,G,l,h,q,r'

vfzf() {
  local ctx='' keys='' back=0
  while (( $# )); do
    case $1 in
      --ctx) ctx=$2; shift 2 ;;
      --keys) keys=$2; shift 2 ;;
      --back) back=1; shift ;;
      --) shift; break ;;
      *) break ;;
    esac
  done

  # The footer is the mode line: which keys work *now*. Parentheses would end
  # the change-footer argument early, so the legends never use them.
  local normal search
  normal='j/k move · l open'
  (( back )) && normal+=' · h back'
  [[ -n $keys ]] && normal+=" · $keys"
  normal+=' · / search · q quit'
  search='type to filter · ctrl-j/k move · enter open · esc normal mode'

  local out rc tag='' row='' line
  # shellcheck disable=SC2086  # one flag per word; the rendered values have no spaces
  out=$(
    fzf --no-input --ansi --no-multi --cycle --layout=reverse --height=100% \
      --pointer='▌' --prompt='/ ' --header="$ctx" --footer="$normal" \
      --bind='j:down,k:up,ctrl-j:down,ctrl-k:up' \
      --bind='g:first,G:last,ctrl-d:half-page-down,ctrl-u:half-page-up' \
      --bind='l:accept,q:abort' \
      --bind="h:print($VFZF_BACK)+accept" \
      --bind="/:show-input+unbind($VFZF_BARE)+change-footer($search)" \
      --bind="esc:clear-query+transform:[[ \$FZF_INPUT_STATE = hidden ]] \
        && echo abort \
        || echo \"hide-input+rebind($VFZF_BARE)+change-footer($normal)\"" \
      "$@" $FZF_THEME_OPTS
  )
  rc=$?
  (( rc == 0 )) || return 1

  # Tags are read off the front of the output rather than assumed to be on line
  # 1, because fzf prints the queue in the order the actions ran.
  while IFS= read -r line; do
    if [[ $line == __vfzf:* ]]; then
      tag=${line#__vfzf:}
      continue
    fi
    row+=$line$'\n'
  done <<<"$out"

  [[ $tag == back ]] && return 2
  # Tag first, then the row -- the same shape `--expect` had. A caller cannot
  # read a variable set in here: it runs at the far end of a pipe, inside a
  # command substitution, so every assignment dies with that subshell.
  printf '%s\n%s' "$tag" "$row"
  return 0
}

# The two halves of what vfzf printed. Worth two functions rather than a
# sed at every callsite, which is where the off-by-one lives.
vfzf_tag() { sed -n 1p <<<"$1"; }
vfzf_row() { sed -n '2,$p' <<<"$1"; }
