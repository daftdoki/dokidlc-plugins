# Session workspaces

The two hook scripts in `bin/`, `workspace-create` and `workspace-remove`, and how a project opts in, are in the [README](../README.md#session-workspaces). This page has the rules.

- The hooks have to be settings entries. Claude Code makes the startup worktree before it registers a plugin's hooks, so a plugin cannot carry them.
- `workspace-remove` refuses, and the workspace stays, while any repository in it has uncommitted changes, untracked files included, or a commit that no remote branch and no other local branch has. It also refuses when git cannot read a repository's state, and when `workspace/` holds anything that is not one of its linked worktrees: a clone made by hand, a file, a symlink, dot names too. It exits non-zero and prints the reason on stderr, which Claude Code puts in its debug log.
- It removes only a workspace: a linked worktree directly under `.claude/worktrees` of its checkout. Any other path is refused.
- If git fails in the middle of a removal, the script says that the workspace is partly removed and exits 1. Nothing unchecked is deleted, and a second run finishes the job.
- When it does remove a workspace, it deletes the branches that `workspace-create` made and keeps a branch that existed before. It knows its own branches by a ref, `refs/workspace/NAME`, in each repository. Gitignored files in the worktrees go with them.
- A new branch starts from `origin/NAME` when an earlier workspace pushed it, else from the remote's default branch, else from `origin/main` or `origin/master`. In a repository with no remote, or with none of those, it starts from `HEAD`. So a pushed branch comes back with the next `--worktree` of the same name.
- A session name that is already a branch of a listed repository checks that branch out, and removal leaves it in place. If that branch is checked out somewhere else, in the project or in a listed repository, `workspace-create` exits 1 before it makes anything, and the session does not start. Pick another name.
- The name must be a branch name git accepts, with no slash, no space, and no leading dot or dash. Any other name exits 1.
- Sessions that start at the same moment each get their workspace. Git can fail one `worktree add` when several start at once, so the script tries a second time.
- A line whose `DIR` or `PATH` repeats an earlier line is skipped with a warning.
- A `PATH` that is not a clone with at least one commit gets a warning, and the workspace is made without it. So does a `DIR` with a slash; `DIR` is one path component.
- A configured `WorktreeCreate` hook replaces Claude Code's own worktree creation, so `.worktreeinclude` and the `worktree.*` settings do not apply.
- The scripts add each `LINK` to the shared clone's `.git/info/exclude`, because git does not apply a `dir/` ignore pattern to a symlink.
- On a machine whose marketplace clone predates these scripts, `claude --worktree` fails in such a project with "WorktreeCreate hook failed ... not found". Run `update-plugins`, or `claude plugin marketplace update dokidlc`, there first.
- A session started from the Claude apps through `claude remote-control --spawn worktree` gets a workspace too. The server calls `workspace-remove` for each clean workspace when it stops, and `workspace-create` again when the session gets its next message.
- `claude --resume ID` from the main checkout returns a session to its workspace. If the workspace was removed, `claude --worktree NAME --resume ID` makes it again.
- They need `git` and `jq`. `sh tests/test-workspace.sh` runs their tests.
