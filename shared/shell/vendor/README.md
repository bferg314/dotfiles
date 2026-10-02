# Vendored files

Third-party files kept in the repo verbatim, so they are pinned and reviewed like everything
else instead of being downloaded at install time. Do not edit them; replace them with a newer
upstream release instead.

| File | Upstream | Version | License |
|---|---|---|---|
| `bash-preexec.sh` | [rcaloras/bash-preexec](https://github.com/rcaloras/bash-preexec) | 0.7.0 | MIT (`bash-preexec.LICENSE.md`) |

`bash-preexec.sh` gives bash the zsh-style `preexec`/`precmd` hooks that atuin needs to record
commands. `shared/shell/tools.sh` sources it, and only in bash and only when atuin is installed.

To update:

```bash
tag=$(gh api repos/rcaloras/bash-preexec/releases/latest --jq .tag_name)
curl -fsSL "https://raw.githubusercontent.com/rcaloras/bash-preexec/$tag/bash-preexec.sh" \
    -o shared/shell/vendor/bash-preexec.sh
```

then update the version in the table above.
