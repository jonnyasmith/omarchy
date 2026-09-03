#!/bin/bash
#
# Markup preview: render a file into a Chromium app window that Hyprland tiles
# beside the terminal. Markdown goes through go-grip, mermaid included; HTML is
# served as itself. One launcher, two entrypoints -- the `mp` shell function and
# the nvim `<Leader>mp` keymap both land here, so what you see never depends on
# which one you used, and there is no second implementation to drift.
#
# The extension picks the renderer, and the caller never says which: nvim hands
# over a path and reads the stderr, exactly as it did when this only did
# markdown. Every rule about what is previewable lives here.
#
# ## Markdown: go-grip
#
# The renderer is go-grip (mise: go:github.com/chrishrb/go-grip). It was picked
# over every nvim preview plugin for one measured reason: 57% of the markdown
# under ~/dev carries YAML frontmatter, and go-grip is the only maintained
# option that extracts it and renders it as a table the way GitHub does --
# `internal/parser.go` calls `frontmatter.Extract` before goldmark ever runs.
# It also ships the newest mermaid of anything surveyed (11.13.0), which is what
# draws `architecture-beta`; mermaid below 11.1 renders that fence as an error
# box, and every nvim plugin is below it (markdown-preview.nvim's prebuilt
# binary is still on 8.13.8, from 2022).
#
# Three properties of go-grip shape this script:
#
#   1. `-b` opens a browser through a hard-coded xdg-open with no override, so
#      it is always `-b=false` here and opening the window is our job.
#   2. it serves `dirname <file>`, not the file. One server therefore covers a
#      whole directory, and a file in a second directory needs a second server,
#      which is why ports are discovered from the running processes below
#      instead of being fixed or hashed. Hashing a directory to a port was the
#      first attempt: a collision silently previews the wrong file.
#   3. reload is fsnotify on that directory plus a full page reload, so the
#      preview updates on `:w`, not on keystroke. That is the deliberate trade.
#      Keystroke-live rendering was available (live-preview.nvim) and its cost
#      was leaking raw YAML at the top of 1302 of those files.
#
# It binds every interface -- `ListenAndServe(":port")`, and `-H` only changes
# the URL it prints, not the bind -- and the handler is a plain file server over
# the served directory. Nothing here is reachable off this box only because
# ufw's default policy is deny incoming and the tailnet rule in
# run_after_sshd-tailnet.sh is scoped to port 22. Widening that rule publishes
# every preview; read this first.
#
# ## HTML: python http.server
#
# go-grip cannot do this half: its handler renders only paths matching
# `(?i)\.md$` and hands everything else to a raw file server with no content
# type, so the browser offers a download instead of a page.
#
# A server is used rather than a `file://` URL because `file://` is a different
# origin model: ES modules, `fetch` and anything CORS-checked fail there, which
# is most of what is worth previewing. `python3 -m http.server` is already on
# this box (mise pins python) and needs no dependency of its own.
#
# Two differences from the markdown half, both deliberate:
#
#   1. **It binds 127.0.0.1**, not every interface. go-grip gives no choice;
#      python does, so this half takes it. The ufw note above is why that is
#      worth the one flag.
#   2. **There is no reload on save.** python's handler has no watcher and
#      injects no client script, so an HTML preview updates when you refresh
#      the window, not when you write the file. Saying so beats implying the
#      markdown behaviour carries over.
#
# The interpreter is resolved to an absolute path *here*, in the caller's
# environment, because the server is started through uwsm-app and lands in the
# systemd user manager's environment, where a mise shim directory may not be on
# PATH.
#
#   preview.sh <file>   preview a file, or focus its window if it is open
#   preview.sh --stop   stop every preview server
#
# Previewable: .md, .html, .htm.

set -uo pipefail

# go-grip's own default, then one port per additional directory. Twenty is far
# past the number of documents anyone has open, and staying in a named window
# keeps a stray listener recognisable in `ss` output. The static range is a
# separate decade so a glance at `ss` says which half a listener belongs to.
md_port_first=6419
md_port_last=6438
html_port_first=6519
html_port_last=6538

# Errors have to reach two audiences: a shell, where stderr is read, and the
# nvim keymap, where `vim.system` swallows it. Same split the sibling pickers
# use, minus the glyph, which is not worth a private-use codepoint here.
say() {
  if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && command -v omarchy-notification-send >/dev/null 2>&1; then
    omarchy-notification-send -u critical "Preview" "$1"
  else
    echo "$1" >&2
  fi
}

# Every running preview server, as `<pid> <kind> <port> <served directory>`.
# Read out of /proc rather than parsed from `pgrep -a`, because a filename with
# a space in it turns a single pgrep line into an ambiguous one, and cmdline is
# already NUL-delimited. The port has to come from argv too: neither server
# records its address anywhere durable.
#
# The python half is matched on `-m http.server` rather than on the interpreter,
# which would claim every unrelated python process on the box.
servers() {
  local c cmd port dir i pid
  for c in /proc/[0-9]*/cmdline; do
    [[ -r $c ]] || continue
    mapfile -d '' -t cmd <"$c" 2>/dev/null || continue
    ((${#cmd[@]})) || continue
    pid=${c#/proc/}
    pid=${pid%/cmdline}

    if [[ ${cmd[0]} == */go-grip || ${cmd[0]} == go-grip ]]; then
      port=$md_port_first dir=""
      i=1
      while ((i < ${#cmd[@]})); do
        case ${cmd[i]} in
          -p | --port)
            port=${cmd[i + 1]:-$md_port_first}
            ((i += 2))
            ;;
          -p=* | --port=*)
            port=${cmd[i]#*=}
            ((i++))
            ;;
          -*) ((i++)) ;;
          *)
            dir=$(dirname "${cmd[i]}")
            ((i++))
            ;;
        esac
      done
      [[ -n $dir ]] || continue
      printf '%s\t%s\t%s\t%s\n' "$pid" md "$port" "$dir"
      continue
    fi

    [[ ${cmd[1]:-} == -m && ${cmd[2]:-} == http.server ]] || continue
    port="" dir=""
    i=3
    while ((i < ${#cmd[@]})); do
      case ${cmd[i]} in
        -d | --directory)
          dir=${cmd[i + 1]:-}
          ((i += 2))
          ;;
        -b | --bind)
          ((i += 2))
          ;;
        -*) ((i++)) ;;
        *)
          port=${cmd[i]}
          ((i++))
          ;;
      esac
    done
    [[ -n $dir && -n $port ]] || continue
    printf '%s\t%s\t%s\t%s\n' "$pid" html "$port" "$dir"
  done
}

if [[ ${1:-} == --stop ]]; then
  mapfile -t pids < <(servers | cut -f1)
  if ((${#pids[@]} == 0)); then
    echo "No preview servers running."
    exit 0
  fi
  kill "${pids[@]}" 2>/dev/null
  echo "Stopped ${#pids[@]} preview server(s)."
  exit 0
fi

file=${1:-}
# Bare `mp` in a repo means its README, which is what go-grip's own CLI does
# when given no file and is the shape the shell entrypoint is used in most.
# The nvim keymap always passes a path, so this only ever fires from a shell.
if [[ -z $file ]]; then
  file=README.md
  [[ -f $file ]] || {
    say "Usage: preview.sh <file.md|file.html> | --stop  (no README.md in $PWD)"
    exit 64
  }
fi

file=$(realpath -e -- "$file" 2>/dev/null) || {
  say "No such file: ${1:-README.md}"
  exit 66
}
[[ -f $file ]] || {
  say "Not a regular file: $file"
  exit 66
}

# The extension is the whole dispatch, and the only place either renderer is
# named. Case-insensitive because `README.MD` and `INDEX.HTML` both exist in
# the wild.
shopt -s nocasematch
case $file in
  *.md) kind=md ;;
  *.html | *.htm) kind=html ;;
  *)
    shopt -u nocasematch
    say "Not previewable: $(basename -- "$file") (want .md, .html or .htm)"
    exit 65
    ;;
esac
shopt -u nocasematch

dir=$(dirname -- "$file")
base=$(basename -- "$file")

port=$(servers | awk -F'\t' -v k="$kind" -v d="$dir" '$2 == k && $4 == d { print $3; exit }')

if [[ -z $port ]]; then
  if [[ $kind == md ]]; then
    first=$md_port_first last=$md_port_last
  else
    first=$html_port_first last=$html_port_last
  fi

  # First free port in the range, asking the kernel rather than trusting the
  # process list: something unrelated may hold 6419.
  taken=$(ss -ltnH 2>/dev/null | awk '{ n = split($4, a, ":"); print a[n] }')
  for ((p = first; p <= last; p++)); do
    [[ $'\n'$taken$'\n' == *$'\n'"$p"$'\n'* ]] || {
      port=$p
      break
    }
  done
  [[ -n $port ]] || {
    say "No free port in $first-$last for a preview server."
    exit 69
  }

  # uwsm-app makes the server its own transient systemd unit, the same route
  # omarchy-launch-webapp takes: a plain background child sits in the calling
  # terminal's scope and dies with it, which would kill the preview of a
  # document still on screen.
  #
  # Backgrounded because uwsm-app does not return until the unit it started
  # exits -- it is a foreground launcher, and every other caller in Omarchy
  # `exec`s it as the last thing they do. Waiting here hung the script for as
  # long as the server lived and the window never opened. Only this waiter is
  # backgrounded; the server itself is in its own scope by then, so losing the
  # waiter costs nothing.
  if [[ $kind == md ]]; then
    uwsm-app -- go-grip -b=false -H localhost -p "$port" -- "$file" >/dev/null 2>&1 &
  else
    python=$(command -v python3) || {
      say "No python3 on PATH to serve $base."
      exit 69
    }
    uwsm-app -- "$python" -m http.server "$port" --bind 127.0.0.1 --directory "$dir" >/dev/null 2>&1 &
  fi

  for _ in {1..60}; do
    ss -ltnH "sport = :$port" 2>/dev/null | read -r _ && break
    sleep 0.05
  done
fi

# Chromium derives an `--app` window's Wayland app_id itself, from the URL and
# the profile, and ignores `--class` on this path entirely: it is
# `chrome-<host>__<url path>-<profile>` (GetXdgAppIdForWebApp ->
# GenerateApplicationNameFromURL -> GetShortcutFileName). Rebuilding it here is
# what lets a second `mp` on the same file focus the window instead of opening
# a duplicate. The path is what varies, so this is per-file by construction.
path=$(printf '%s' "$base" | jq -sRr @uri)
url="http://localhost:$port/$path"
app_id="chrome-localhost__${path}-Default"

# omarchy-launch-or-focus interpolates the pattern into a jq regex, so a
# filename carrying regex metacharacters would either fail to match or make jq
# error. Escaping is cheaper than either.
pattern=$(printf '%s' "$app_id" | sed 's/[][\\.^$*+?(){}|]/\\&/g')

exec omarchy-launch-or-focus-webapp "$pattern" "$url"
