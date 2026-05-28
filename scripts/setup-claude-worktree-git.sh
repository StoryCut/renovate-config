#!/usr/bin/env bash
#
# setup-claude-worktree-git.sh
#
# Configures a per-worktree git identity so that commits made by an agent
# (Claude Code, Codex, Multica platform agents, etc.) inside a `claude/*`
# or `agent/*` branch are authored as "Claude Code (<contributor>)" and
# signed with a dedicated SSH key — NOT with the human contributor's
# personal GPG key.
#
# Why per-worktree config (not includeIf in ~/.gitconfig)?
#   The repo's local `.git/config` may set `user.signingkey` to the
#   contributor's personal GPG key. Local config beats global config —
#   including any `includeIf` rule in ~/.gitconfig. So an `includeIf`
#   approach can override `user.name` and `user.email` but NOT
#   `user.signingkey`. Per-worktree config (via `extensions.worktreeConfig`)
#   sits ABOVE local config in git's precedence ladder, so it can
#   actually override the signing key in just the Claude worktrees.
#
# Where the identity comes from:
#   This script reads the contributor's Claude identity from
#   ~/.gitconfig.claude (a regular git-config-format file). Each
#   contributor sets that file up once on their machine — see the
#   "Agent commit signing" section in README.md (which points to
#   StoryCut's full one-time setup guide).
#
# When this runs:
#   - Automatically: SessionStart hook in .claude/settings.json fires
#     this script every time an agent session starts in a Claude
#     worktree. Idempotent — safe to run repeatedly.
#   - Manually: invoke it directly if you need to (re-)apply the
#     identity without restarting the agent session.
#
# What this does NOT do:
#   - Does not affect non-agent branches (the `claude/*` / `agent/*` check
#     is at the top — exits early on `main`, `feature/...`, etc.).
#   - Does not affect other repos (per-worktree config is scoped to
#     this repo only).
#   - Does not modify the human contributor's personal git config.

set -euo pipefail

# ---- 1. Bail early if not in an agent worktree ----------------------------
# Agent worktrees use `claude/<name>` (Claude Code desktop) or
# `agent/<agent-name>/<run-id>` (Multica platform agents) branch naming.
# In any other branch (main, feature/*, dependabot/*, etc.) we want
# the human contributor's normal git identity to apply.
branch=$(git branch --show-current 2>/dev/null || true)
if [[ "$branch" != claude/* && "$branch" != agent/* ]]; then
  exit 0
fi

# ---- 2. Bail if the contributor hasn't set up ~/.gitconfig.claude ---------
# This is the per-contributor identity file. New contributors create it
# once via the steps in the README's "Agent commit signing" section. If
# it's missing, surface a friendly hint instead of failing silently.
identity_file="$HOME/.gitconfig.claude"
if [[ ! -f "$identity_file" ]]; then
  echo "WARNING: $identity_file not found."
  echo "Claude commit identity not configured for this worktree."
  echo "See the 'Agent commit signing' section in README.md for the one-time setup."
  exit 0
fi

# ---- 3. Enable extensions.worktreeConfig (one-time per repo) --------------
# Per-worktree config files (.git/worktrees/<name>/config.worktree)
# only take effect when this extension is enabled in the main repo
# config. Idempotent — git short-circuits if it's already true.
git config extensions.worktreeConfig true

# ---- 4. Apply the Claude identity to this worktree's config ---------------
# Each setting is copied from ~/.gitconfig.claude into the worktree's
# own config file. The worktree config beats local .git/config, so
# this overrides the contributor's personal user.signingkey just for
# commits made inside this worktree.
#
# Idempotent: only writes if the value differs from what's already
# there, so re-runs are silent no-ops.
keys=(
  user.name
  user.email
  user.signingkey
  gpg.format
  gpg.ssh.allowedSignersFile
  commit.gpgsign
)

changed=0
for key in "${keys[@]}"; do
  value=$(git config --file "$identity_file" --get "$key" 2>/dev/null || true)
  [[ -z "$value" ]] && continue

  current=$(git config --worktree --get "$key" 2>/dev/null || true)
  if [[ "$current" != "$value" ]]; then
    git config --worktree "$key" "$value"
    changed=1
  fi
done

if [[ $changed -eq 1 ]]; then
  echo "✓ Claude commit identity configured for this worktree (branch: $branch)"
fi
