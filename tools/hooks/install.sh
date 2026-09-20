#!/usr/bin/env bash
#
# Installs this repo's git hooks and branch-safety config into THIS clone.
# Hooks and config are per-clone, so re-run after a fresh clone or on a new
# machine. Idempotent.
#
#   tools/hooks/install.sh

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
hooks_dir=$(git rev-parse --git-path hooks)

for hook in pre-commit prepare-commit-msg; do
	ln -sf "../../tools/hooks/$hook" "$hooks_dir/$hook"
	echo "hook:    $hooks_dir/$hook -> tools/hooks/$hook"
done

# `git pull` never invents a merge or a rebase: it fast-forwards or stops.
git config pull.ff only
# Merges INTO the shared mains are never fast-forwards. A real merge commit
# shows what happened, and prepare-commit-msg gets to vet the source branch.
git config branch.lod--main.mergeOptions --no-ff
git config branch.master.mergeOptions --no-ff
echo "config:  pull.ff=only; lod--main and master merge with --no-ff"
