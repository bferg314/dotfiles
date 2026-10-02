# Go tools (`gup.json`)

The Go programs that `Base tools` installs with `go install`, on every platform. It is
[gup](https://github.com/nao1215/gup)'s own export format, so `Base tools` just runs

```sh
gup import --file shared/gup/gup.json
```

which installs each one into `~/go/bin` (`%USERPROFILE%\go\bin` on Windows) at its latest version.
gup reads this file and never writes to it, so it stays clean in the repo.

This is for tools that are **only** distributed as Go source — no release binaries, no package. A
tool with release binaries belongs in `shared/mise/config.toml` (or the Brewfile / `packages.psd1`),
where it is checksum-verified and needs no compiler. gup itself comes from mise.

| Tool | Why it is here |
|---|---|
| [folgit](https://github.com/bferg314/folgit) | No releases yet; `go install` is the only way to get it |

## Adding a tool

Add an entry with the binary's `name` and the package's `import_path` (what you would pass to
`go install`, without the `@version`). Keep `"version": "latest"` and `"channel": "latest"` so
every machine tracks the newest release; `gup pin <name> <version>` pins one on a single machine.
Then re-run `Base tools`, or run the import above.

## Day to day

- `gup update` — update every binary in `~/go/bin`, including ones you installed by hand
- `gup check` — show which have updates, without installing
- `gup list` — what is installed, and from where
