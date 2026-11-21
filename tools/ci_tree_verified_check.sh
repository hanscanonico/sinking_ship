#!/usr/bin/env bash
#
# `make guard-check`: tools/ci_tree_verified.sh against a stand-in gh that answers
# from made-up commits, pull requests and runs. A commit on main is verified only when
# a merged pull request's head holds its tree and has a green verify run, and the
# script then names that run; a head with another tree, a head with no green run, a
# pull request closed unmerged's, a commit from no pull request and a gh that fails
# are each `verified=false` with the reason, exit 0, so the gate runs whole. A second
# pull request is asked when the first does not answer for the tree. A bad call
# exits 2.

set -uo pipefail
tool="$(cd "$(dirname "$0")" && pwd)/ci_tree_verified.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fails=0
fail() {
	echo "ci-tree-verified-check: $1" >&2
	fails=1
}

# The stand-in answers each `gh api PATH --jq …` as gh would once jq has cut the
# answer down: $GH_FAKE/tree/SHA is a commit's tree, $GH_FAKE/pulls/SHA its merged pull
# requests, a line each of number and head, and $GH_FAKE/run/HEAD the head's green
# verify run. A commit with no tree file is one gh cannot read.
mkdir "$WORK/bin"
cat >"$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == api && "$3" == --jq ]] || exit 1
echo "$2" >>"$GH_FAKE/calls"
case "$2" in
repos/owner/name/git/commits/*) cat "$GH_FAKE/tree/${2##*/}" 2>/dev/null || exit 1 ;;
repos/owner/name/commits/*/pulls)
	[[ -e "$GH_FAKE/no_pulls" ]] && exit 1
	sha=${2%/pulls}
	cat "$GH_FAKE/pulls/${sha##*/}" 2>/dev/null
	exit 0
	;;
"repos/owner/name/actions/workflows/verify.yml/runs?head_sha="*"&event=pull_request&status=success&per_page=1")
	head=${2#*head_sha=}
	cat "$GH_FAKE/run/${head%%&*}" 2>/dev/null
	exit 0
	;;
*) exit 1 ;;
esac
EOF
chmod +x "$WORK/bin/gh"
export GH_FAKE="$WORK/gh"

# A whole SHA from one hex digit.
sha_of() {
	printf "%040d" 0 | tr 0 "$1"
}
main=$(sha_of a)
head=$(sha_of b)
other=$(sha_of c)

# Forgets every commit, pull request and run; then each FILE=CONTENT given.
fresh() {
	local fact
	rm -rf "$GH_FAKE"
	mkdir -p "$GH_FAKE/tree" "$GH_FAKE/pulls" "$GH_FAKE/run"
	for fact in "$@"; do
		printf '%s\n' "${fact#*=}" >"$GH_FAKE/${fact%%=*}"
	done
}

run() {
	out=$(PATH="$WORK/bin:$PATH" GITHUB_REPOSITORY=owner/name "$tool" "$@" 2>"$WORK/err")
	rc=$?
	err=$(cat "$WORK/err")
}

# What a run must print, exit 0, and say on stderr.
expect() {
	[[ $rc -eq 0 ]] || fail "$1: exit $rc, not 0"
	[[ "$out" == "$2" ]] || fail "$1: printed '$out', not '$2'"
	grep -qF -- "$3" <<<"$err" || fail "$1: did not say '$3' but: $err"
}

fresh "tree/$main=t1" "tree/$head=t1" "pulls/$main=7 $head" "run/$head=https://example/runs/1"
run "$main"
expect "a green head's tree" verified=true "holds the tree of #7's head bbbbbbbb, green in https://example/runs/1"

fresh "tree/$main=t1" "tree/$head=t2" "pulls/$main=7 $head" "run/$head=https://example/runs/1"
run "$main"
expect "a head merged behind its base" verified=false "#7's head bbbbbbbb holds another tree"
grep -q 'actions/workflows' "$GH_FAKE/calls" && fail "a head with another tree was asked for its runs"

fresh "tree/$main=t1" "tree/$head=t1" "pulls/$main=7 $head"
run "$main"
expect "a head never green" verified=false "#7's head bbbbbbbb holds its tree but has no green verify run"

fresh "tree/$main=t1"
run "$main"
expect "a commit pushed straight to main" verified=false "it comes from no merged pull request"

fresh "tree/$main=t1" "tree/$head=t2" "tree/$other=t1" "pulls/$main=7 $head"$'\n'"8 $other" \
	"run/$other=https://example/runs/2"
run "$main"
expect "a second pull request's tree" verified=true "holds the tree of #8's head cccccccc, green in https://example/runs/2"

fresh
run "$main"
expect "a commit gh cannot read" verified=false "gh could not read the commit"

fresh "tree/$main=t1" "no_pulls="
run "$main"
expect "pull requests gh cannot list" verified=false "gh could not list its pull requests"

fresh "tree/$main=t1" "pulls/$main=7 $head"
run "$main"
expect "a head gh cannot read" verified=false "gh could not read #7's head"

for bad in "" abc1234 "$main $head"; do
	# shellcheck disable=SC2086
	run $bad
	[[ $rc -eq 2 ]] || fail "'$bad' for a SHA: exit $rc, not 2"
	[[ -z "$out" ]] || fail "'$bad' for a SHA: printed '$out'"
done

((fails == 0)) && echo "ci-tree-verified-check: ok"
exit $fails
