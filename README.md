# StoryCut/renovate-config

Renovate configurations for this organization

[![CI](https://github.com/StoryCut/renovate-config/actions/workflows/ci.yml/badge.svg)](https://github.com/StoryCut/renovate-config/actions/workflows/ci.yml)


# Local setup

A [pre-commit](https://pre-commit.com/) hook validates every `*.json5` config before
each commit, so problems are caught before they reach CI. Install it once per clone:

```bash
brew install pre-commit   # or: pipx install pre-commit
pre-commit install
```

To validate everything on demand (the same check CI runs):
```bash
pre-commit run --all-files
```


# Commands

## Validate a config locally

For a specific config file, eg. `js-lib.json5`:
```bash
npx --yes --package renovate -- renovate-config-validator js-lib.json5
```