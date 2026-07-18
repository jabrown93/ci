#!/usr/bin/env bash
set -euo pipefail

# Inputs (env): TYPES (newline-delimited allowed types), GH_TOKEN, PR_NUMBER.
# GITHUB_REPOSITORY is set by the Actions runner.

types_alt=$(grep -v '^[[:space:]]*$' <<<"$TYPES" | paste -sd '|')
type_re="^(${types_alt})(\([-a-zA-Z0-9_/. ]+\))?!?: .+"
# GitHub's default revert-PR title/commit and merge commits don't follow the
# type(scope): subject shape -- allow them rather than force a rewrite.
revert_re='^Revert "'
merge_re='^Merge (branch|pull request) '

is_valid_subject() {
  local subject="$1"
  [[ "$subject" =~ $type_re ]] && return 0
  [[ "$subject" =~ $revert_re ]] && return 0
  [[ "$subject" =~ $merge_re ]] && return 0
  return 1
}

fail=0
while IFS= read -r subject; do
  [[ -z "$subject" ]] && continue
  if ! is_valid_subject "$subject"; then
    echo "::error::Commit does not follow Conventional Commits: \"$subject\""
    fail=1
  fi
done < <(gh api "repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/commits" --paginate --jq '.[].commit.message | split("\n")[0]')

if [[ "$fail" -eq 1 ]]; then
  echo "Allowed types: $(tr '\n' ',' <<<"$TYPES" | sed 's/,$//')"
  exit 1
fi
