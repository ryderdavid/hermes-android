#!/usr/bin/env bash
# Rebase the Material You fork onto rusty4444/hermes-android.
#
#   scripts/sync-upstream.sh [--branch NAME] [--push] [--skip-checks]
#
# 1. fetches `upstream` (added if missing) and fast-forwards local `main`
#    to upstream/main,
# 2. rebases the work branch (default: the current branch) onto it,
# 3. runs `flutter analyze` and `flutter test`.
#
# Nothing is pushed unless --push is given; then `main` is pushed and the work
# branch is force-pushed with lease. See docs/FORK.md.
set -euo pipefail

UPSTREAM_URL="https://github.com/rusty4444/hermes-android.git"
branch=""
push=false
checks=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch) branch="$2"; shift 2 ;;
    --push) push=true; shift ;;
    --skip-checks) checks=false; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

cd "$(git rev-parse --show-toplevel)"

if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  echo "Working tree has uncommitted changes; commit or stash first." >&2
  exit 1
fi

branch="${branch:-$(git rev-parse --abbrev-ref HEAD)}"
if [[ "$branch" == "main" || "$branch" == "HEAD" ]]; then
  echo "Check out the fork's work branch (or pass --branch) first." >&2
  exit 1
fi

if ! git remote get-url upstream >/dev/null 2>&1; then
  git remote add upstream "$UPSTREAM_URL"
fi

echo "==> Fetching upstream"
git fetch upstream main

echo "==> Fast-forwarding main to upstream/main"
if git show-ref --verify --quiet refs/heads/main; then
  # main mirrors upstream; refuse rather than drop commits made on it.
  if ! git merge-base --is-ancestor main upstream/main; then
    echo "Local main has commits that are not upstream; resolve by hand." >&2
    exit 1
  fi
  git branch -f main upstream/main
else
  git branch main upstream/main
fi

echo "==> Rebasing $branch onto upstream/main"
git checkout "$branch"
behind=$(git rev-list --count "$branch..upstream/main")
echo "    $branch is $behind commit(s) behind upstream/main"
git rebase upstream/main

if $checks; then
  echo "==> flutter pub get / analyze / test"
  flutter pub get
  flutter analyze
  flutter test
fi

if $push; then
  echo "==> Pushing main and $branch to origin"
  git push origin main
  git push --force-with-lease origin "$branch"
fi

echo "==> Done. $branch now sits on $(git rev-parse --short upstream/main)."
