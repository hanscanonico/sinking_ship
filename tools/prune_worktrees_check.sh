#!/usr/bin/env bash
#
# `make guard-check`: tools/prune_worktrees.sh against a throwaway repo and a stand-in
# gh. It names done the worktree whose PR is merged and that holds nothing of its own,
# line-ending churn included, and keeps every other with its reason — changes, staged
# changes, an untracked file, files under captures/, a commit past its PR, an open PR,
# no PR, a merge inside the grace period, a detached HEAD; --remove removes the done
# ones and deletes their branches, and leaves the rest.

set -uo pipefail
tool="$(cd "$(dirname "$0")" && pwd)/prune_worktrees.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fails=0
fail() {
	echo "prune-worktrees-check: $1" >&2
	fails=1
}

repo="$WORK/main"
git init -q --bare "$WORK/origin.git"
git init -q "$repo"
git -C "$repo" config user.name check
git -C "$repo" config user.email check@example.com
git -C "$repo" config core.autocrlf false
printf 'one\ntwo\n' >"$repo/tracked.txt"
printf 'captures/\n' >"$repo/.gitignore"
git -C "$repo" add tracked.txt .gitignore
git -C "$repo" commit -qm base
git -C "$repo" branch -M main
git -C "$repo" remote add origin "$WORK/origin.git"
git -C "$repo" push -q origin main

# A worktree on branch $1 with a commit of its own, its PR merged $2 minutes ago as
# number $3 (none when $3 is empty).
: >"$WORK/merged.tsv"
number=0
for branch in clean churn changed staged untracked captures ahead open nopr fresh; do
	tree="$WORK/wt/$branch"
	git -C "$repo" worktree add -q "$tree" -b "$branch" main
	echo "$branch" >"$tree/$branch.txt"
	git -C "$tree" add "$branch.txt"
	git -C "$tree" commit -qm "$branch"
	number=$((number + 1))
	case "$branch" in
	nopr | open) ;;
	fresh) printf '%s\t%s\t%s\t%s\n' "$branch" "$(git -C "$tree" rev-parse HEAD)" "$number" 5 >>"$WORK/merged.tsv" ;;
	*) printf '%s\t%s\t%s\t%s\n' "$branch" "$(git -C "$tree" rev-parse HEAD)" "$number" 500 >>"$WORK/merged.tsv" ;;
	esac
done
printf 'open\n' >"$WORK/open.txt"
git -C "$repo" worktree add -q --detach "$WORK/wt/detached" main

printf 'one\r\ntwo\r\n' >"$WORK/wt/churn/tracked.txt"
echo more >>"$WORK/wt/changed/tracked.txt"
echo more >>"$WORK/wt/staged/tracked.txt"
git -C "$WORK/wt/staged" add tracked.txt
echo new >"$WORK/wt/untracked/new.txt"
mkdir "$WORK/wt/captures/captures"
echo shot >"$WORK/wt/captures/captures/shot.png"
echo later >"$WORK/wt/ahead/later.txt"
git -C "$WORK/wt/ahead" add later.txt
git -C "$WORK/wt/ahead" commit -qm later

mkdir "$WORK/bin"
cat >"$WORK/bin/gh" <<EOF
#!/usr/bin/env bash
case "\$*" in
*"--state merged"*) cat '$WORK/merged.tsv' ;;
*"--state open"*) cat '$WORK/open.txt' ;;
*) exit 1 ;;
esac
EOF
chmod +x "$WORK/bin/gh"

said=$(cd "$repo" && PATH="$WORK/bin:$PATH" "$tool" 2>&1)
expect() { # verdict, branch, reason
	grep -qE "^$1 +.*/wt/$2 \($3\)$" <<<"$said" || fail "$2 is not '$1 ($3)': $(grep "/wt/$2 " <<<"$said")"
}
expect done clean 'PR #1 merged'
expect done churn 'PR #2 merged'
expect stays changed 'changes'
expect stays staged 'staged changes'
expect stays untracked 'untracked files'
expect stays captures 'files under captures/'
expect stays ahead 'commits PR #7 did not carry'
expect stays open 'PR open'
expect stays nopr 'no merged PR'
expect stays fresh 'PR #10 merged 5 min ago'
expect stays detached 'detached'
grep -q "/main " <<<"$said" && fail "the main checkout was judged: $said"
for branch in clean churn changed; do
	[[ -d "$WORK/wt/$branch" ]] || fail "a dry run removed $branch"
done

removed=$(cd "$repo" && PATH="$WORK/bin:$PATH" "$tool" --remove 2>&1)
for branch in clean churn; do
	[[ -d "$WORK/wt/$branch" ]] && fail "--remove left the done worktree $branch: $removed"
	git -C "$repo" rev-parse -q --verify "refs/heads/$branch" >/dev/null &&
		fail "--remove left the done worktree's branch $branch"
done
for branch in changed staged untracked captures ahead open nopr fresh detached; do
	[[ -d "$WORK/wt/$branch" ]] || fail "--remove removed $branch, which holds work or is not done"
done

((fails == 0)) && echo "prune-worktrees-check: ok"
exit "$fails"
