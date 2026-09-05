# dokidlc-plugins

The catalog for the `dokidlc` plugin marketplace.

Add it to a machine:

```
/plugin marketplace add daftdoki/dokidlc-plugins
```

Or let a project carry it in `.claude/settings.json` under
`extraKnownMarketplaces` and `enabledPlugins`.

## Plugins

| Plugin | What it does |
| --- | --- |
| [questlog](https://github.com/daftdoki/dokidlc-skill-questlog) | Tracks work as quests and chores with staged review. The agent drafts, the creator decides. |
| [memory](https://github.com/daftdoki/dokidlc-skill-memory) | A per-agent memory of markdown pages in `.memory/`, written and recalled automatically by hooks. Pages never expire; a page that proves wrong gets flagged for review instead. |

## Updating a project

`claude plugin update` takes one plugin at a time. To bring every plugin in a
project current, run the script from that project's directory:

```
~/Code/agents/dokidlc-plugins/bin/update-plugins
```

It refreshes the marketplace clone, then updates each plugin listed in
`marketplace.json` at project scope. Pass `user` or `local` as the first
argument for another scope. Restart the session afterward.
