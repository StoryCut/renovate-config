## PR Linking Convention

Whenever you open a pull request that relates to a Multica issue, always include the closing keyword in the PR body:

```
Closes STO-42
```

- The issue key (e.g. `STO-12`) is available in your issue context.
- Use `Closes`, `Fixes`, or `Resolves` (case-insensitive) — all are supported.
- For multiple issues: `Closes STO-42, Closes STO-43`
- For partial work (not fully resolving): use `Related to STO-42`

This ensures the workspace owner receives the review ticket automatically.

## Commit Convention

This repo enforces [Conventional Commits](https://www.conventionalcommits.org/) via `commitlint` (extending `@commitlint/config-conventional`).

Commit message format:

```
<type>(<optional scope>): <description>

[optional body]
```

Common types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

Examples:

- `docs: update renovate schedule`
- `ci: add lint step`
- `chore(deps): update dependency foo to v2`

The PR title must also follow this format — it is validated by the Semantic PR GitHub check.
