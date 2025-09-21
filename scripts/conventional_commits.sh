#!/usr/bin/env bash
# Central definition of allowed Conventional Commit types for this repository.
# Source this file and call conventional_commit_regex to get the validation pattern.
# Keep this the single source of truth (READMEs reference this file).
set -euo pipefail

# Ordered list (preferred grouping for readability in docs):
CONVENTIONAL_COMMIT_TYPES=(
  feat
  fix
  docs
  style
  refactor
  perf
  test
  build
  ci
  chore
  revert
  security
)

conventional_commit_regex() {
  local IFS='|'
  local types="${CONVENTIONAL_COMMIT_TYPES[*]}"
  # Pattern explanation:
  #  ^(types)            one of the allowed types
  #   (\([a-z0-9_.-]+\))? optional scope (lowercase + allowed symbols)
  #   (!)?                optional breaking change marker
  #   : <space>           colon + exactly one space
  #   [^ ].+$             first char of description not a space, then anything until end
  printf '^(%s)(\([a-z0-9_.-]+\))?(!)?: [^ ].+$' "$types"
}

if [[ "${1:-}" == "--regex" ]]; then
  conventional_commit_regex
fi

