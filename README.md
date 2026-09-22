# dokidlc-plugins

The catalog for the `dokidlc` plugin marketplace.

Five Claude Code plugins live here, one per repository, each pinned to a commit. Adding the marketplace makes all five available to install; you install the ones a project needs and leave the rest. The plugins are independent, so a repository can take memory alone, or questlog and writing-for-agents together, and nothing breaks.

| Plugin | What it does |
| --- | --- |
| [questlog](https://github.com/daftdoki/dokidlc-skill-questlog) | Tracks work as quests and chores with staged review. The agent drafts, you decide. |
| [memory](https://github.com/daftdoki/dokidlc-skill-memory) | A per-agent memory of markdown pages in `.memory/`, written and recalled by hooks. Pages never expire; a page that proves wrong gets flagged for review instead. |
| [unslop](https://github.com/daftdoki/dokidlc-skill-unslop) | Rules for cutting AI tells from writing and keeping a human voice. Lauren Tan's pstack skill with the soul section kept. The plugin puts the rules in context at every session and subagent start. |
| [writing-for-agents](https://github.com/daftdoki/dokidlc-skill-writing-for-agents) | The reference for writing skills, `CLAUDE.md`, and any document an agent reads. Matt Pocock's skill, vendored unchanged. |
| [readme](https://github.com/daftdoki/dokidlc-skill-readme) | Writes, grades, and keeps a `README.md` for the person deciding whether to use the software. Three verbs and `readme-check`, a checker that gates on why and status. |

## Why this marketplace

This is my standard set of plugins, in one place so a new machine or a new project is two commands away from the setup I work with. Three I wrote; two are other people's skills rehosted as plugins, pinned so an upstream change is something I pull rather than something that arrives mid-session. The set is opinionated by definition, since the only thing the five have in common is that I use them.

It is not a general catalog. Nothing is accepted from outside, and a pin moves when I have reviewed the work behind it. Install any of the five if it suits you; if you want to build on the set, fork the repositories rather than wait on this catalog.

Status: maintained, and the pins move most weeks. Claude Code 2.1.195 or later.

## Install

Add the marketplace once per machine, then install the plugins you want:

```
/plugin marketplace add daftdoki/dokidlc-plugins
claude plugin install memory@dokidlc
```

A repository can declare the marketplace for everyone who clones it, in `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": { "dokidlc": { "source": { "source": "github", "repo": "daftdoki/dokidlc-plugins" } } },
  "enabledPlugins": { "memory@dokidlc": true }
}
```

Settings enable a plugin; they do not install it. Each machine still runs the `claude plugin install` line once.

## Run an update

`claude plugin update` takes one plugin at a time. To bring every plugin in a project current, run the script from that project's directory:

```
~/.claude/plugins/marketplaces/dokidlc/bin/update-plugins
```

```
✔ Successfully updated marketplace: dokidlc
Checking for updates for plugin "questlog@dokidlc" at project scope…
✔ questlog is already at the latest version (e328b6ffc3de).
Checking for updates for plugin "memory@dokidlc" at project scope…
✔ memory is already at the latest version (0e262c25022a).
```

It refreshes the marketplace clone first, because `claude plugin update` reads the clone and not GitHub, then updates each plugin the catalog lists. Pass `user` or `local` as the first argument for another scope.

## Caveats

- Restart your session after an update. Claude Code loads plugins at session start.
- The script updates every plugin in the catalog, so a pin another machine moved comes along with the one you wanted. Run `claude plugin update NAME@dokidlc` for a single plugin.
- Two plugins cannot share a `name` in their manifests. Claude Code registers hooks by that name and skips the second as a duplicate, which drops its hooks with no message outside the debug log.

## Other docs

Each plugin's README covers its own install, usage, and caveats; the table above links them. Questions and bugs go to the [issue tracker](https://github.com/daftdoki/dokidlc-plugins/issues).

## License

MIT, DaftDoki. See [LICENSE](LICENSE). Each plugin carries its own license, and unslop and writing-for-agents credit their upstream authors.
