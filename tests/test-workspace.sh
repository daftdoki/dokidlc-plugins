#!/bin/sh
# Usage: sh tests/test-workspace.sh
#
# Tests bin/workspace-create and bin/workspace-remove against scratch repos
# in a temporary directory: a bare origin, a shared clone of it, and an
# agent repo whose .claude/workspace-repos lists the clone and one path that
# does not exist. Prints one "ok" line per case and exits 1 at the first
# failure. Needs git and jq.
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
    printf '.deps/\n.cache/\n' >.gitignore
    echo shared >README
    git add -A && git commit -q -m init && git push -q origin main
    git remote set-head origin main
    mkdir -p .deps/one .cache/two
) || fail "setup of the shared clone"
agent=$tmp/agent
git init -q -b main "$agent"
(
    cd "$agent" || exit 1
    mkdir .claude
    printf '.claude/worktrees/\nworkspace/\n' >.gitignore
    printf '# DIR PATH [LINK...]\nshared %s .deps .cache\nghost ~/no/such/clone\n' "$shared" >.claude/workspace-repos
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
ok "a missing path gives a warning, exit 0, and no nested directory"

create w1 >/dev/null 2>&1 || fail "second create exits 0"
[ "$(grep -c -x '/.deps' "$shared/.git/info/exclude")" = 1 ] || fail "one exclude line after two creates"
ok "a second create reuses the workspace"

out=$(create w2 "$ws" 2>/dev/null) || fail "create from inside a workspace exits 0"
[ "$out" = "$agent/.claude/worktrees/w2" ] || fail "workspace made under the main checkout"
remove w2 >/dev/null 2>&1 || fail "remove of the clean w2"
ok "create from inside a workspace uses the main checkout"

create a/b >/dev/null 2>&1 && fail "a name with a slash is refused"
create .hidden >/dev/null 2>&1 && fail "a name with a leading dot is refused"
ok "a bad name exits 1"

for tree in "$ws" "$nested"; do
    echo x >"$tree/untracked"
    remove w1 >/dev/null 2>&1 && fail "remove refuses an untracked file in $tree"
    [ -f "$tree/untracked" ] || fail "the untracked file in $tree is still there"
    rm "$tree/untracked"
done
ok "remove exits 1 with an untracked file in either worktree and keeps it"

git -C "$nested" commit -q --allow-empty -m work
remove w1 >/dev/null 2>&1 && fail "remove refuses an unsaved commit"
[ -d "$nested" ] || fail "the workspace is still there"
ok "remove exits 1 with a commit that no other branch has"

git -C "$nested" push -q origin w1 2>/dev/null
remove w1 >/dev/null 2>&1 || fail "remove exits 0 after the push"
[ ! -e "$ws" ] || fail "the workspace is gone"
git -C "$agent" show-ref --verify --quiet refs/heads/w1 && fail "agent branch deleted"
git -C "$shared" show-ref --verify --quiet refs/heads/w1 && fail "shared branch deleted"
[ -d "$shared/.deps/one" ] || fail "the link target survives the removal"
ok "remove exits 0 after a push and deletes both worktrees and branches"

create w1 >/dev/null 2>&1 || fail "create after removal"
[ "$(git -C "$nested" log -1 --format=%s)" = work ] || fail "nested branch starts at origin/w1"
ok "a later create starts the nested branch at origin/NAME"

echo "all $n cases passed"
