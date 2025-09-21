#!/usr/bin/env bash
set -euo pipefail

BASE_REF="$1"
HEAD_REF="$2"

# Collect changed files between base and head
CHANGED_FILES=$(git diff --name-only "${BASE_REF}"..."${HEAD_REF}")

if grep -qi '\[skip-changelog\]' <(git log --format=%B "${BASE_REF}".."${HEAD_REF}"); then
  echo "[INFO] Found [skip-changelog] directive in commit messages – skipping changelog enforcement."
  exit 0
fi

# If no non-doc code changed, allow missing changelog.
# Heuristic: if only files inside README*, *.md (excluding CHANGELOG.md) or .github/ changed.
NON_DOC_CHANGED=false
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in
    CHANGELOG.md) HAVE_CHANGELOG_CHANGE=true ;;
    README.md|README.en.md|*.md|.github/*) ;; # ignore pure docs/ci
    *) NON_DOC_CHANGED=true ;;
  esac
done <<<"$CHANGED_FILES"

if [ "${HAVE_CHANGELOG_CHANGE:-false}" = true ]; then
  echo "[OK] CHANGELOG.md updated."
  exit 0
fi

if [ "$NON_DOC_CHANGED" = false ]; then
  echo "[OK] Only documentation / CI files changed; changelog update not required."
  exit 0
fi

echo "[ERROR] Non-documentation changes detected but CHANGELOG.md was not updated."
echo "Changed files:" >&2
echo "$CHANGED_FILES" >&2
exit 1

