# Session workspaces

The two hook scripts in `bin/`, `workspace-create` and `workspace-remove`, and how a project opts in, are in the [README](../README.md#session-workspaces). This page has the rules.

- The hooks have to be settings entries. Claude Code makes the startup worktree before it registers a plugin's hooks, so a plugin cannot carry them.
- `workspace-remove` refuses, and the workspace stays, while any repository in it has uncommitted changes or a commit that no remote branch and no other local branch has. It also refuses when git cannot read a repository's state, and when `workspace/` holds anything that is not one of its linked worktrees, such as a clone made by hand. It prints the reason on stderr, which Claude Code puts in its debug log.
- When it does remove a workspace, it deletes the branches that `workspace-create` made and keeps a branch that existed before. Gitignored files in the worktrees go with them.
- A new branch starts from `origin/NAME` when an earlier workspace pushed it, else from the remote's default branch, else from `HEAD` in a repository with no remote. So a pushed branch comes back with the next `--worktree` of the same name.
- A session name that is already a branch of a listed repository checks that branch out, and removal leaves it in place.
- A name with a slash, a space, or a leading dot or dash is refused, and the session does not start.
- A `PATH` that does not exist gets a warning, and the workspace is made without it.
- A configured `WorktreeCreate` hook replaces Claude Code's own worktree creation, so `.worktreeinclude` and the `worktree.*` settings do not apply.
- The scripts add each `LINK` to the shared clone's `.git/info/exclude`, because git does not apply a `dir/` ignore pattern to a symlink.
- On a machine whose marketplace clone predates these scripts, `claude --worktree` fails in such a project with "WorktreeCreate hook failed ... not found". Run `update-plugins`, or `claude plugin marketplace update dokidlc`, there first.
- A session started from the Claude apps through `claude remote-control --spawn worktree` gets a workspace too. The server calls `workspace-remove` for each clean workspace when it stops, and `workspace-create` again when the session gets its next message.
- `claude --resume ID` from the main checkout returns a session to its workspace. If the workspace was removed, `claude --worktree NAME --resume ID` makes it again.
- They need `git` and `jq`. `sh tests/test-workspace.sh` runs their tests.
