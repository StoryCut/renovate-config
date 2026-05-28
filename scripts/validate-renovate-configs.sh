#!/usr/bin/env bash
#
# Validate every Renovate config (*.json5) in the repo, one file at a time, and
# print a per-config ASCII summary table. For any config that fails, print the
# validator's explanation. Exits non-zero if any config fails.
#
# The renovate version is read from .pre-commit-config.yaml so CI and the local
# pre-commit hook always validate with the exact same version. Runs in CI and
# locally (`./scripts/validate-renovate-configs.sh`) — only Node is required.

set -uo pipefail

CONFIG_FILE=".pre-commit-config.yaml"

# Single source of truth for the renovate version: the pinned rev of the
# renovatebot/pre-commit-hooks repo, whose release tags mirror renovate's npm
# versions (the hook bundles the matching renovate@<rev>).
RENOVATE_VERSION=$(awk '
  /renovatebot\/pre-commit-hooks/ { found = 1 }
  found && /rev:/ { sub(/.*rev:[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); print; exit }
' "$CONFIG_FILE")

if [ -z "${RENOVATE_VERSION:-}" ]; then
  echo "error: could not determine renovate version from $CONFIG_FILE" >&2
  exit 1
fi

# Discover configs from git so newly added *.json5 files are picked up automatically.
configs=()
while IFS= read -r f; do
  configs+=("$f")
done < <(git ls-files '*.json5' | sort)

if [ "${#configs[@]}" -eq 0 ]; then
  echo "No *.json5 Renovate configs found."
  exit 0
fi

# Validate one file as a repository config, in isolation. Each file is copied into an
# empty temp dir as renovate.json5 (a name auto-discovery recognizes) and validated
# there. This matters for two reasons:
#   1. Passing a file as a positional arg makes the validator treat it as a *global*
#      (admin) config — the wrong schema for these presets — and suppresses the error
#      details for every failing file after the first.
#   2. Validating in the repo root would also auto-discover the repo's own
#      renovate.json5, so one broken config would make *every* file report FAIL.
# Isolation gives the correct (repository) schema, full error details, and no cross-talk.
# The temp filename in the output is rewritten back to the real name by the caller.
validate() { # usage: validate <file>; prints validator output, returns its exit code
  local tmp rc
  tmp=$(mktemp -d)
  cp "$1" "$tmp/renovate.json5"
  ( cd "$tmp" && npx --yes --package "renovate@${RENOVATE_VERSION}" -- renovate-config-validator --strict 2>&1 )
  rc=$?
  rm -rf "$tmp"
  return "$rc"
}

# Warm the npx environment once so the cold-run npm install logs don't get mixed
# into a per-config result. (On a cache hit this is a no-op.)
echo "Validating ${#configs[@]} Renovate config(s) with renovate@${RENOVATE_VERSION}..."
validate "${configs[0]}" >/dev/null 2>&1 || true

# Parallel, index-aligned arrays (kept bash 3.2-compatible for macOS).
names=()
statuses=()
details=()
overall=0

i=0
for f in "${configs[@]}"; do
  # Capture once: the strict run already prints the failure reason, so the output
  # doubles as the details for the failure report (no second invocation needed).
  out=$(validate "$f")
  rc=$?
  names[i]="$f"
  if [ "$rc" -eq 0 ]; then
    statuses[i]="PASS"
    details[i]=""
  else
    statuses[i]="FAIL"
    overall=1
    # Rewrite the temp name (renovate.json5) back to the real file for readability.
    details[i]="${out//renovate.json5/$f}"
  fi
  i=$((i + 1))
done

# Column widths sized to the longest value.
w_config=6 # len("Config")
for n in "${names[@]}"; do [ "${#n}" -gt "$w_config" ] && w_config=${#n}; done
w_status=6 # len("Status")

dashes() { printf '%*s' "$1" '' | tr ' ' '-'; }
sep="+-$(dashes "$w_config")-+-$(dashes "$w_status")-+"

pass=0
fail=0
for s in "${statuses[@]}"; do
  if [ "$s" = "PASS" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
done

printf '\nRenovate config validation\n'
echo "$sep"
printf "| %-*s | %-*s |\n" "$w_config" "Config" "$w_status" "Status"
echo "$sep"
for i in "${!names[@]}"; do
  printf "| %-*s | %-*s |\n" "$w_config" "${names[i]}" "$w_status" "${statuses[i]}"
done
echo "$sep"
printf '%d passed, %d failed, %d total\n' "$pass" "$fail" "${#names[@]}"

if [ "$overall" -ne 0 ]; then
  printf '\n===== Failure details =====\n'
  for i in "${!names[@]}"; do
    if [ "${statuses[i]}" = "FAIL" ]; then
      printf '\n--- %s ---\n%s\n' "${names[i]}" "${details[i]}"
    fi
  done
fi

# Render the same summary into the GitHub Actions job summary (markdown).
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## Renovate config validation"
    echo
    echo "Validated with \`renovate@${RENOVATE_VERSION}\`."
    echo
    echo "| Config | Status |"
    echo "| --- | --- |"
    for i in "${!names[@]}"; do
      if [ "${statuses[i]}" = "PASS" ]; then icon="✅ PASS"; else icon="❌ FAIL"; fi
      echo "| \`${names[i]}\` | ${icon} |"
    done
    echo
    echo "**${pass} passed, ${fail} failed, ${#names[@]} total**"
    if [ "$overall" -ne 0 ]; then
      echo
      for i in "${!names[@]}"; do
        if [ "${statuses[i]}" = "FAIL" ]; then
          echo "<details><summary>❌ ${names[i]}</summary>"
          echo
          echo '```'
          echo "${details[i]}"
          echo '```'
          echo
          echo "</details>"
        fi
      done
    fi
  } >>"$GITHUB_STEP_SUMMARY"
fi

exit "$overall"
