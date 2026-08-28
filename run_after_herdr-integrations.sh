#!/usr/bin/env bash
#
# Herdr agent integrations — the lifecycle hooks that make the sidebar's agent
# state dot mean anything.
#
# Herdr decides a pane's state from one authority per agent. For most agents
# that authority is a bundled screen manifest: herdr reads the bottom of the
# pane buffer and matches it against rules, so state works with nothing
# installed. OMP has no manifest at all -- its only authority is the lifecycle
# extension herdr installs into ~/.omp/agent/extensions/. Without it every OMP
# pane reports `idle` forever, `herdr agent explain <pane>` says
# "manifest: none / fallback_reason: default_known_agent_idle_fallback", and
# the sidebar can never show working or blocked. That is the whole reason this
# script exists.
#
# Only agents whose state is *unusable* without the integration are listed.
# `herdr integration install` writes into the agent's own config tree, and for
# claude/codex/opencode that tree is not managed by this repo and those agents
# already have a working manifest, so installing their hooks here would be an
# unmanaged write that buys only native session restore. Add an agent below
# when that trade changes, not because its CLI is on PATH.
#
# `run_after_`, not `run_onchange_after_`: the version that matters is herdr's,
# and `herdr update` bumps it outside any apply. Re-checking every apply is two
# cheap CLI calls and repairs an integration that went stale on its own.
#
# The extension file is herdr's, not chezmoi's. It is deliberately *not* a
# target file next to statusline.ts: herdr rewrites it on upgrade, and a
# managed copy would pin an old one and fight `herdr integration install`.
# dot_omp/private_agent/extensions is not an `exact_` directory, so chezmoi
# leaves it alone.
#
# Every failure exits 0. A missing herdr or a failed install costs the state
# dot, never the apply.

set -uo pipefail

command -v herdr >/dev/null 2>&1 || exit 0

# Agent ids as `herdr integration install` names them.
agents=(omp)

# Both probes come from one status call each, because the list is short and the
# command talks to no server.
status=$(herdr integration status 2>/dev/null) || exit 0
outdated=$(herdr integration status --outdated-only 2>/dev/null) || outdated=""

for agent in "${agents[@]}"; do
	if grep -q "^${agent}: not installed" <<<"$status"; then
		reason="not installed"
	elif grep -q "^${agent}:" <<<"$outdated"; then
		reason="outdated"
	else
		continue
	fi

	echo "Installing the herdr ${agent} integration (${reason})..."
	if herdr integration install "$agent"; then
		# The hook loads when the agent starts, so panes that are already
		# running keep reporting whatever they reported before.
		echo "Installed — restart any running ${agent} pane for it to report state"
	else
		echo "Could not install the herdr ${agent} integration" >&2
	fi
done

exit 0
