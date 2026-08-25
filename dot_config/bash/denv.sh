# denv — run a command with this repo's secrets injected from 1Password.
#
# Replaces the copy-a-.env-file-into-place habit. Secrets never touch disk:
# `op run` resolves op:// references and passes the values to a subprocess
# only, and masks them in stdout/stderr.
#
#   denv pnpm dev              # stage dev (default)
#   denv -s prod pnpm build    # stage prod
#   denv -k                    # print the key this repo resolves to
#   denv -l                    # list templates, marking this repo's
#   denv -e                    # edit this repo's template
#   denv-check [stage]         # verify every reference in every template
#
# Templates live in $DENV_DIR (default ~/.config/dev-env), NOT in the repo:
# the team does not use 1Password, and an op:// reference names a vault and
# item, which on work repos means it names the client. Nothing here is
# committed to a repo — see the "employer name" rule in the dotfiles README.
#
#   _shared.tpl        loaded first for every repo   (optional)
#   <key>.tpl          the repo's own                (required)
#   <key>.<stage>.tpl  stage-specific overrides      (optional)
#
# `op run --env-file` may be repeated and the last file wins, so the three
# layers compose. A template holds no secrets, only pointers:
#
#   PUBLIC_API_URL=op://Dev/myapp-$APP_ENV/api_url
#
# $APP_ENV is substituted by op from the environment, so one template covers
# every stage and switching stage is an argument rather than a file copy.

DENV_DIR=${DENV_DIR:-$HOME/.config/dev-env}

# The lookup key is the repo's identity, not its directory name: a git
# worktree has a different basename from its main checkout, and this repo is
# worked in worktrees. Origin URL first (stable across worktrees and clones),
# then the main worktree's directory via --git-common-dir, then cwd so that
# scratch directories outside git still resolve to something.
_denv_key() {
	local url name common
	url=$(git config --get remote.origin.url 2>/dev/null)
	if [[ -n $url ]]; then
		name=${url%.git}
		name=${name##*[:/]}
		# Azure DevOps percent-encodes path segments. Decode only on a real
		# escape, so a literal % or \ in a repo name is left alone.
		[[ $name == *%[0-9A-Fa-f][0-9A-Fa-f]* ]] && name=$(printf '%b' "${name//%/\\x}")
	else
		common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
		name=${common:+$(basename "${common%/.git*}")}
		name=${name:-$(basename "$PWD")}
	fi
	printf '%s' "${name,,}"
}

denv() {
	local stage=${DENV_STAGE:-dev} key root tpl
	local -a files=()

	while [[ $1 == -* ]]; do
		case $1 in
		-s)
			[[ -n $2 ]] || {
				echo "denv: -s needs a stage" >&2
				return 2
			}
			stage=$2
			shift 2
			;;
		-k)
			_denv_key
			echo
			return 0
			;;
		-l)
			key=$(_denv_key)
			local f
			for f in "$DENV_DIR"/*.tpl; do
				[[ -e $f ]] || {
					echo "denv: no templates in $DENV_DIR" >&2
					return 1
				}
				f=$(basename "$f" .tpl)
				[[ $f == "$key" || $f == "$key".* ]] &&
					printf '* %s\n' "$f" || printf '  %s\n' "$f"
			done
			return 0
			;;
		-e)
			key=$(_denv_key)
			mkdir -p "$DENV_DIR"
			"${EDITOR:-nvim}" "$DENV_DIR/$key.tpl"
			return $?
			;;
		*)
			echo "denv: unknown flag $1" >&2
			return 2
			;;
		esac
	done

	[[ $# -gt 0 ]] || {
		echo "denv: no command given" >&2
		return 2
	}
	command -v op >/dev/null 2>&1 || {
		echo "denv: op (1password-cli) not installed" >&2
		return 1
	}

	key=$(_denv_key)
	tpl="$DENV_DIR/$key.tpl"
	[[ -f $tpl ]] || {
		echo "denv: no template $tpl (key: $key)" >&2
		return 1
	}
	[[ -f $DENV_DIR/_shared.tpl ]] && files+=(--env-file="$DENV_DIR/_shared.tpl")
	files+=(--env-file="$tpl")
	[[ -f $DENV_DIR/$key.$stage.tpl ]] && files+=(--env-file="$DENV_DIR/$key.$stage.tpl")

	# The one silent failure mode left: a leftover .env in the repo root is
	# still loaded by Vite's dotenv and beats anything injected here.
	root=$(git rev-parse --show-toplevel 2>/dev/null) || root=$PWD
	[[ -f $root/.env ]] && echo "denv: warning — $root/.env exists and will shadow injected values" >&2

	APP_ENV=$stage op run "${files[@]}" -- "$@"
	local rc=$?
	if ((rc != 0)) && ! op whoami >/dev/null 2>&1; then
		echo "denv: op is not signed in — enable 1Password → Settings → Developer →" >&2
		echo "      Integrate with 1Password CLI, then retry." >&2
	fi
	return $rc
}

# Every template, resolved against one stage. Catches a rotated or renamed
# vault item before the app does.
denv-check() {
	local stage=${1:-dev} f found=0
	for f in "$DENV_DIR"/*.tpl; do
		[[ -e $f ]] || break
		found=1
		if APP_ENV=$stage op inject -i "$f" >/dev/null 2>&1; then
			printf 'ok    %s\n' "$(basename "$f")"
		else
			printf 'FAIL  %s\n' "$(basename "$f")"
		fi
	done
	((found)) || {
		echo "denv-check: no templates in $DENV_DIR" >&2
		return 1
	}
}
