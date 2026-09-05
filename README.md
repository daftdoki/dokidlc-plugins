# dokidlc-plugins

The catalog for the `dokidlc` plugin marketplace. One file matters:
`.claude-plugin/marketplace.json`, which lists each plugin and pins it to a
commit. Bumping a pin is a release.

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
