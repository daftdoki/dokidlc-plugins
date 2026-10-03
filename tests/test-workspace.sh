#!/bin/sh
# Usage: sh tests/test-workspace.sh
#
# Tests bin/workspace-create and bin/workspace-remove against scratch repos
# in a temporary directory: a bare origin, a shared clone of it, and an
# agent repo whose .claude/workspace-repos lists the clone and one path that
# does not exist. The agent repo's path has a space in it. Prints one "ok"
# line per case and exits 1 at the first failure. Needs git and jq.
set -u

bin=$(cd "$(dirname "$0")/../bin" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
export HOME="$tmp/home"
mkdir -p "$HOME"

n=0
ok() { n=$((n + 1)); echo "ok $n - $1"; }
fail() { echo "FAIL - $1" >&2; exit 1; }

create() { printf '{"name":"%s"}' "$1" | CLAUDE_PROJECT_DIR=${2:-$agent} "$bin/workspace-create"; }
remove() { printf '{"worktree_path":"%s"}' "$agent/.claude/worktrees/$1" | "$bin/workspace-remove"; }

# The scratch repos.
git init -q --bare -b main "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/shared" 2>/dev/null
shared=$tmp/shared
(
    cd "$shared" || exit 1
    printf '.deps/\n.cache/\n*.env\n' >.gitignore
    echo shared >README
    git add -A && git commit -q -m init && git push -q origin main
    git remote set-head origin main
    mkdir -p .deps/one .cache/two
    # No newline at the end, so an appended pattern must start its own line.
    printf '# last line' >.git/info/exclude
) || fail "setup of the shared clone"
agent="$tmp/agent repo"
git init -q -b main "$agent"
(
    cd "$agent" || exit 1
    mkdir .claude
    printf '.claude/worktrees/\nworkspace/\n' >.gitignore
    printf '# DIR PATH [LINK...]\nshared %s .deps .cache\nghost ~/no/such/clone\nsub/dir %s\n' "$shared" "$shared" >.claude/workspace-repos
    git add -A && git commit -q -m init
) || fail "setup of the agent repo"
ws=$agent/.claude/worktrees/w1
nested=$ws/workspace/shared

[ -x "$bin/workspace-create" ] || fail "workspace-create: not found in $bin"
[ -x "$bin/workspace-remove" ] || fail "workspace-remove: not found in $bin"

out=$(create w1 2>"$tmp/err") || fail "create exits 0"
[ "$(printf '%s\n' "$out" | tail -n 1)" = "$ws" ] || fail "create prints the workspace path last"
[ "$(git -C "$ws" branch --show-current)" = w1 ] || fail "agent worktree on branch w1"
[ "$(git -C "$nested" branch --show-current)" = w1 ] || fail "nested worktree on branch w1"
ok "create makes both worktrees on branch NAME and prints the path"

[ "$(readlink "$nested/.deps")" = "$shared/.deps" ] || fail ".deps link"
[ "$(readlink "$nested/.cache")" = "$shared/.cache" ] || fail ".cache link"
[ -z "$(git -C "$nested" status --porcelain)" ] || fail "nested worktree is clean with the links"
ok "links point into the shared clone and the nested worktree is clean"

grep -q 'no/such/clone is not a git clone' "$tmp/err" || fail "warning for the missing path"
[ ! -e "$ws/workspace/ghost" ] || fail "no directory for the missing path"
grep -q "DIR 'sub/dir' is not one path component" "$tmp/err" || fail "warning for a DIR with a slash"
[ ! -e "$ws/workspace/sub" ] || fail "no directory for a DIR with a slash"
ok "a missing path or a DIR with a slash gives a warning, exit 0, and no nested directory"

create w1 >/dev/null 2>&1 || fail "second create exits 0"
[ "$(grep -c -x '/.deps' "$shared/.git/info/exclude")" = 1 ] || fail "one exclude line after two creates"
[ "$(sed -n 1p "$shared/.git/info/exclude")" = "# last line" ] || fail "the exclude file's last line is left whole"
ok "a second create reuses the workspace, and exclude lines are whole and single"

out=$(create w2 "$ws" 2>/dev/null) || fail "create from inside a workspace exits 0"
[ "$out" = "$agent/.claude/worktrees/w2" ] || fail "workspace made under the main checkout"
remove w2 >/dev/null 2>&1 || fail "remove of the clean w2"
ok "create from inside a workspace uses the main checkout"

for bad in a/b .hidden -dash "two words" a..b x.lock HEAD @; do
    create "$bad" >/dev/null 2>&1
    [ $? = 1 ] || fail "the name '$bad' exits 1"
    [ ! -e "$agent/.claude/worktrees/$bad" ] || fail "the name '$bad' leaves nothing behind"
done
ok "a name that git does not accept as a branch exits 1"

git -C "$shared" worktree add -q "$tmp/held" -b held 2>/dev/null
for taken in main held; do
    create "$taken" >/dev/null 2>&1
    [ $? = 1 ] || fail "the name '$taken' exits 1"
    [ ! -e "$agent/.claude/worktrees/$taken" ] || fail "no agent worktree for '$taken'"
done
git -C "$agent" show-ref --verify --quiet refs/heads/held && fail "no agent branch for a refused name"
ok "a name whose branch is checked out elsewhere exits 1 and makes nothing"

printf '{"worktree_path":"%s"}' "$tmp/held" | "$bin/workspace-remove" >/dev/null 2>&1 &&
    fail "remove refuses a worktree outside .claude/worktrees"
[ -d "$tmp/held" ] || fail "the outside worktree is still there"
git -C "$shared" worktree remove "$tmp/held" && git -C "$shared" branch -q -D held
ok "remove refuses a worktree that is not a workspace"

for tree in "$ws" "$nested"; do
    echo x >"$tree/untracked"
    remove w1 >/dev/null 2>&1 && fail "remove refuses an untracked file in $tree"
    [ -f "$tree/untracked" ] || fail "the untracked file in $tree is still there"
    rm "$tree/untracked"
done
ok "remove exits 1 with an untracked file in either worktree and keeps it"

for extra in extra .hidden; do
    git clone -q "$tmp/origin.git" "$ws/workspace/$extra" 2>/dev/null
    git -C "$ws/workspace/$extra" commit -q --allow-empty -m "only here"
    remove w1 >/dev/null 2>&1 && fail "remove refuses a full clone at workspace/$extra"
    [ -d "$ws/workspace/$extra/.git" ] || fail "the full clone at workspace/$extra is still there"
    rm -rf "$ws/workspace/$extra"
done
for loose in loose-file .notes; do
    echo note >"$ws/workspace/$loose"
    remove w1 >/dev/null 2>&1 && fail "remove refuses the file workspace/$loose"
    rm "$ws/workspace/$loose"
done
create peer >/dev/null 2>&1 || fail "create of a second workspace"
ln -s "$agent/.claude/worktrees/peer/workspace/shared" "$ws/workspace/peek"
remove w1 >/dev/null 2>&1 && fail "remove refuses a symlink under workspace/"
[ -d "$agent/.claude/worktrees/peer/workspace/shared" ] || fail "the other workspace is untouched"
rm "$ws/workspace/peek"
remove peer >/dev/null 2>&1 || fail "remove of the peer workspace"
ok "remove exits 1 when workspace/ holds anything that is not a linked worktree"

git -C "$shared" config status.showUntrackedFiles no
echo x >"$nested/quiet"
remove w1 >/dev/null 2>&1 && fail "remove refuses an untracked file that status is set to hide"
rm "$nested/quiet"
git -C "$shared" config --unset status.showUntrackedFiles
ok "remove exits 1 with an untracked file when status.showUntrackedFiles is no"

index=$(git -C "$nested" rev-parse --absolute-git-dir)/index
cp "$index" "$tmp/index.good"
echo changed >>"$nested/README"
echo garbage >"$index"
remove w1 >/dev/null 2>&1 && fail "remove refuses when git status fails"
[ -d "$nested" ] || fail "the workspace is still there after a failed status"
cp "$tmp/index.good" "$index"
git -C "$nested" checkout -q -- README
ok "remove exits 1 when git status fails"

git -C "$nested" commit -q --allow-empty -m work
remove w1 >/dev/null 2>&1 && fail "remove refuses an unsaved commit"
[ -d "$nested" ] || fail "the workspace is still there"
ok "remove exits 1 with a commit that no other branch has"

git -C "$nested" push -q origin w1 2>/dev/null
remove w1 >/dev/null 2>&1 || fail "remove exits 0 after the push"
[ ! -e "$ws" ] || fail "the workspace is gone"
git -C "$agent" show-ref --verify --quiet refs/heads/w1 && fail "agent branch deleted"
git -C "$shared" show-ref --verify --quiet refs/heads/w1 && fail "shared branch deleted"
git -C "$shared" worktree list | grep -q '/w1/' && fail "no worktree record left in the shared clone"
[ -d "$shared/.deps/one" ] || fail "the link target survives the removal"
ok "remove exits 0 after a push and deletes both worktrees and branches"

create w1 >/dev/null 2>&1 || fail "create after removal"
[ "$(git -C "$nested" log -1 --format=%s)" = work ] || fail "nested branch starts at origin/w1"
remove w1 >/dev/null 2>&1 || fail "remove of the rebuilt w1"
ok "a later create starts the nested branch at origin/NAME"

git -C "$shared" branch -q feature main
create feature >/dev/null 2>&1 || fail "create on an existing branch name"
remove feature >/dev/null 2>&1 || fail "remove of the feature workspace"
git -C "$shared" show-ref --verify --quiet refs/heads/feature || fail "a branch the script did not make is kept"
git -C "$agent" show-ref --verify --quiet refs/heads/feature && fail "the branch the script made is deleted"
ok "remove keeps a branch that existed before the workspace"

git -C "$shared" remote set-head origin -d
git -C "$shared" commit -q --allow-empty -m "local only"
create w3 >/dev/null 2>&1 || fail "create with origin/HEAD unset"
[ "$(git -C "$agent/.claude/worktrees/w3/workspace/shared" log -1 --format=%s)" = init ] ||
    fail "the base is origin/main, not the clone's local HEAD"
remove w3 >/dev/null 2>&1 || fail "remove of w3"
ok "with origin/HEAD unset the base is still the remote's main"

round=0
while [ $round -lt 15 ]; do
    round=$((round + 1))
    (create "c$round-a" >/dev/null 2>&1 || echo "c$round-a" >>"$tmp/race") &
    (create "c$round-b" >/dev/null 2>&1 || echo "c$round-b" >>"$tmp/race") &
    wait
done
[ ! -s "$tmp/race" ] || fail "creates that start together all exit 0; failed: $(tr '\n' ' ' <"$tmp/race")"
round=0
while [ $round -lt 15 ]; do
    round=$((round + 1))
    for side in a b; do
        remove "c$round-$side" >/dev/null 2>&1 || fail "remove of c$round-$side"
        git -C "$shared" show-ref --verify --quiet "refs/heads/c$round-$side" && fail "branch c$round-$side deleted"
    done
done
ok "two creates that start together both succeed, 15 rounds"

echo "all $n cases passed"
