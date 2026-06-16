# renovate-config — agent guide

`CLAUDE.md` is a symlink to this file. Source of truth.

When you update this file, **rewrite the affected section cohesively** — don't append patches to the
bottom. The next reader (human or agent) should be able to scan a section top-to-bottom without
archaeology.

---

## What this repo is

`nunofyobiz/renovate-config` holds the organization's shared [Renovate](https://docs.renovatebot.com/)
configuration presets — the `*.json5` files at the repo root (`default.json5`, `js-base.json5`,
`js-lib.json5`, `js-app.json5`, `org.json5`, …). Other repos extend these presets
(e.g. `extends: ["github>nunofyobiz/renovate-config:js-lib.json5"]`). There is **no application code
and no `package.json`** — the only executable is the validator script, run through `npx`.

## Verification ritual

Before claiming a task done — whenever you add or edit any `*.json5` preset — run the validator:

```
bash scripts/validate-renovate-configs.sh
```

It validates every `*.json5` config one file at a time with the exact `renovate` version pinned in
[`.pre-commit-config.yaml`](./.pre-commit-config.yaml) (via `npx renovate-config-validator --strict`),
prints a per-config PASS/FAIL table, and exits non-zero on any failure. This is the same check CI runs.
Node ≥ 22 is the only prerequisite (pinned in `.nvmrc`); run `nvm use` first only if a bare invocation
reports an engine error.

## Permission-prompt posture (command shape)

Most permission prompts are a **command-shape problem, not a missing allowlist entry** — the engine
auto-approves a command only when *every* part of it is independently safe, so several wrappers defeat
an otherwise-allowlisted command. The allowlist in [`.claude/settings.json`](./.claude/settings.json)
covers the safe reads and the validator script; you keep prompts low by *how* you invoke things:

- **Prefer the built-in `Grep` / `Glob` / `Read` tools** over shell `grep` / `find` / `cat` and
  pipelines. They don't go through the Bash permission path, so they never prompt — and they're faster.
- **One command per tool call — never `&&` / `;` / `|` chains.** A compound line is auto-approved only
  if every segment independently clears, so even an all-allowlisted chain (`git add … && git commit …
  && git log …`) prompts. Run the steps as separate calls.
- **Run the validator verbatim** — `bash scripts/validate-renovate-configs.sh`, with no env-var prefix
  (`TMPDIR=…`) and no `2>&1 | tail` / `2>/dev/null` capture wrapper. Run it bare and read the output;
  the redirect/pipe is itself what prompts.
- **Commit with `-m` (or `-F <file>`), never a heredoc.** `git commit <<'EOF' … EOF` is an input
  redirect and prompts on *every* commit.
- **Don't `cd` / `git -C <path>` into the worktree you're already in** — an out-of-cwd path triggers a
  prompt. The cwd already *is* the repo; run `git status`, the validator, etc. directly.

Consequential actions stay **deliberately gated** (they *should* prompt): bare `npx` (arbitrary code
execution — only the validator *script* is allowlisted, not raw `npx`), `gh pr merge`, `gh issue
create`, and destructive git (`git reset --hard`, `git clean -fd`, bare `git push --force`). Expanding
the allowlist is the smallest lever, not the first — fix the root cause in command shape before
reaching for it.

## Commits and PRs

- **Conventional Commits**, enforced by `commitlint` in CI (`commitlint.config.cjs`). Types: `feat`,
  `fix`, `refactor`, `chore`, `docs`, `test`, `perf`, `style`, `ci`, `build`. The PR title is itself a
  Conventional Commit. CI also rejects `WIP` / `DNM` markers in commit messages and the PR title.
- **Atomic commits** — one cohesive change each.
- On an **unmerged branch**, amending / squashing / reordering is fine; update an open PR with
  `git push --force-with-lease` (never bare `--force`).
- Run the validator before pushing. Open a PR; don't merge unless asked.

## CLAUDE.md ↔ AGENTS.md

`CLAUDE.md` is a symbolic link to this file. If you find yourself editing both, you've broken the
symlink — restore it with `ln -sf AGENTS.md CLAUDE.md` from the repo root.
