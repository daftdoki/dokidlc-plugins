# Session workspaces

The two hook scripts in `bin/`, `workspace-create` and `workspace-remove`, and how a project opts in, are in the [README](../README.md#session-workspaces). This page has the rules.

- The hooks have to be settings entries. Claude Code makes the startup worktree before it registers a plugin's hooks, so a plugin cannot carry them.
- `workspace-remove` refuses, and the workspace stays, while any repository in it has uncommitted changes or a commit that no remote branch and no other local branch has. When it does remove a workspace it deletes the local branches too. A pushed branch comes back: the next `--worktree` with the same name starts from `origin/NAME`.
- A `PATH` that does not exist gets a warning, and the workspace is made without it.
- A configured `WorktreeCreate` hook replaces Claude Code's own worktree creation, so `.worktreeinclude` and the `worktree.*` settings do not apply.
- The scripts add each `LINK` to the shared clone's `.git/info/exclude`, because git does not apply a `dir/` ignore pattern to a symlink.
- On a machine whose marketplace clone predates these scripts, `claude --worktree` fails in such a project with "WorktreeCreate hook failed ... not found". Run `update-plugins`, or `claude plugin marketplace update dokidlc`, there first.
- A session started from the Claude apps through `claude remote-control --spawn worktree` gets a workspace too. The server calls `workspace-remove` for each clean workspace when it stops, and `workspace-create` again when the session gets its next message.
- `claude --resume ID` from the main checkout returns a session to its workspace. If the workspace was removed, `claude --worktree NAME --resume ID` makes it again.
- They need `git` and `jq`. `sh tests/test-workspace.sh` runs their tests.
