# Ported from the zsh setup's ~/.config/zsh/aliases.zsh and os.zsh.tmpl.
# Sourced by ~/.bashrc *after* $OMARCHY_PATH/default/bash/rc, so anything
# defined here deliberately wins over Omarchy's defaults. The overrides are
# called out individually below.
#
# The os.zsh template's branches collapsed on the way over: that file existed
# to serve macOS and three Linux package managers from one repo. This machine
# is Arch only, so the Linux branch is inlined and the darwin branch dropped.

# `source ~/.bashrc` cannot be re-run cleanly with ble.sh attached — it would
# re-source the line editor over itself. Replacing the shell is equivalent and
# also picks up changes to ~/.config/blesh/init.sh.
alias reload='exec bash'

# bat detects a non-tty and emits plain undecorated text, so `cat file | …`
# and `$(cat file)` are unchanged; `command cat` bypasses.
command -v bat >/dev/null 2>&1 && alias cat="bat --paging=never"

# --- git --------------------------------------------------------------------
# These lean on the one-letter git aliases in ~/.config/git/config (a, cm, d,
# f, l, m, p, r, s). Both halves came over together; neither works alone.
alias g="git"
alias lg="lazygit"

alias ga='git a .'
# Overrides Omarchy's gcm='git commit -m'. Same effect, via the git alias.
alias gcm='git cm'
alias gf='git f'
alias gd='git d'
alias gll='git l -20'
alias gm='git m'
alias gp='git p'
alias gr='git r'
alias gs='git s'
alias push='git push'

# Bash has no `noglob`, so an unquoted `gac fix the *.ts import` would glob
# before the function saw it. A function taking "$*" has the same ergonomics
# as the zsh alias and no globbing hazard at the call site.
gac() {
	git add -A
	git commit -m "$*"
}

# `echo -e` is not portable across bash's shopt settings; printf is.
git_fetch_all() {
	local original_dir dir
	original_dir=$(pwd)
	cd ~/dev || return
	for dir in */; do
		if [ -d "$dir/.git" ]; then
			printf '\n\033[33mfetching %s\033[0m\n' "$dir"
			(cd "$dir" && git fetch --all)
		fi
	done
	cd "$original_dir" || return
}
alias fa='git_fetch_all'

alias clean-orig="find . -name '*.orig' -delete"

# --- worktree-cli -----------------------------------------------------------
alias wtc='worktree create'
alias wtr='worktree remove'
alias wtl='worktree list'

# --- containers -------------------------------------------------------------
alias d='docker'
# `docker compose`, not the retired v1 binary.
alias dc='docker compose'
alias k='kubectl'

# --- files and navigation ---------------------------------------------------
# lsd is not installed here; Omarchy already aliases ls to eza. The guard is
# kept so that installing lsd restores the zsh behaviour, and the la fallback
# below works against whichever ls is live.
if command -v lsd >/dev/null 2>&1; then
	alias ls="lsd"
fi
alias la="ls -AF"
alias ll="ls -l"
alias lla="ls -la"
alias lld="ls -l | grep ^d"
alias rmf="rm -rf"

# .. and ... are already Omarchy aliases; .... and ..... are not.
alias ....="cd ../../.."
alias .....="cd ../../../.."

alias y="yarn"
# Overrides Omarchy's h='herdr'. Use `herdr` for that.
alias h="history"

# --- system -----------------------------------------------------------------
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h -c'
alias fs='stat -c "%s bytes"'
alias weather='curl v2.wttr.in'

# The zsh setup's `ip` alias (dig myip.opendns.com) is deliberately not ported:
# on Linux `ip` is iproute2, and shadowing it breaks every network command.
alias myip="curl -fsS https://ifconfig.me && echo"
alias ips="ip -brief address"
alias localip="hostname -I"

alias flush="sudo resolvectl flush-caches"
alias emptytrash="rm -rfv ~/.local/share/Trash/files/* ~/.local/share/Trash/info/*"

alias sniff="sudo ngrep -d any -t '^(GET|POST) ' 'tcp and port 80'"
alias httpdump="sudo tcpdump -i any -n -s 0 -w - | grep -a -o -E \"Host\: .*|GET \/.*\""

# One of @janmoesen's ProTip™s. Guarded: lwp-request ships with perl-libwww,
# which is not installed by default on Arch.
if command -v lwp-request >/dev/null 2>&1; then
	for method in GET HEAD POST PUT DELETE TRACE OPTIONS; do
		alias "$method"="lwp-request -m '$method'"
	done
	unset method
fi
