#!/usr/bin/env bash
set -euo pipefail

# Inputs (env): TYPES (newline-delimited allowed types), GH_TOKEN, PR_NUMBER,
# PR_COMMIT_COUNT. GITHUB_REPOSITORY is set by the Actions runner.

# The "list commits on a pull request" endpoint caps out at 250 commits
# regardless of --paginate (see GitHub's REST docs), so a PR past that count
# would silently pass with commits beyond the cap left unchecked. Fail loud
# instead -- rebasing/squashing to under the cap is the fix.
if [[ "$PR_COMMIT_COUNT" -gt 250 ]]; then
  echo "::error::PR has $PR_COMMIT_COUNT commits; the GitHub API only returns the first 250 on this endpoint, so not every commit can be checked. Squash or rebase to bring it under 250, or disable check-commits."
  exit 1
fi

types_alt=$(grep -v '^[[:space:]]*$' <<<"$TYPES" | paste -sd '|')
type_re="^(${types_alt})(\([-a-zA-Z0-9_/. ]+\))?!?: .+"
# GitHub's default revert-PR title/commit and merge commits don't follow the
# type(scope): subject shape -- allow them rather than force a rewrite.
revert_re='^Revert "'
merge_re='^Merge (branch|remote-tracking branch|pull request) '

is_valid_subject() {
  local subject="$1"
  [[ "$subject" =~ $type_re ]] && return 0
  [[ "$subject" =~ $revert_re ]] && return 0
  [[ "$subject" =~ $merge_re ]] && return 0
  return 1
}

fail=0
# Capture into a variable rather than piping into the while loop via process
# substitution: under `set -e`, a failing command inside `<(...)` does not
# abort the script, so a transient gh api failure would silently read as
# zero commits checked, zero failures found -- a false pass on the very
# check meant to fail loud.
commit_subjects=$(gh api "repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/commits" --paginate --jq '.[].commit.message | split("\n")[0]')
while IFS= read -r subject; do
  if ! is_valid_subject "$subject"; then
    echo "::error::Commit does not follow Conventional Commits: \"$subject\""
    fail=1
  fi
done <<<"$commit_subjects"

if [[ "$fail" -eq 1 ]]; then
  echo "Allowed types: $(tr '\n' ',' <<<"$TYPES" | sed 's/,$//')"
  exit 1
fi
