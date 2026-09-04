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
