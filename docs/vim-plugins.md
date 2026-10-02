# Vim Plugins

There is one `.vimrc` for every platform: [`shared/vim/.vimrc`](../shared/vim/.vimrc), linked to
`~/.vimrc` on Linux and macOS and `~\_vimrc` on Windows. Neovim reads the same file through
[`shared/nvim/init.vim`](../shared/nvim/init.vim), so vim and Neovim behave the same. Platform
differences (the clipboard register, options Neovim removed) are `has()` checks inside the file,
not separate copies — a change made once reaches every machine.

Plugins load through [vim-plug](https://github.com/junegunn/vim-plug). The setup menu's **Editor
plugins** task installs `plug.vim` itself (for vim and Neovim); once it's linked and vim-plug is
present, open vim and run:

```vim
:PlugInstall
```

to fetch the plugins below. `:PlugUpdate` upgrades them later, `:PlugClean` removes anything no
longer listed in `.vimrc`.

The `.vimrc` doesn't remap `<Leader>`, so it's vim's default: `\`.

- **Status line** — vim-airline, vim-airline-themes
- **File navigation** — fzf + fzf.vim, NERDTree
- **Code quality** — ALE, vim-commentary
- **Git integration** — vim-fugitive, vim-gitgutter
- **Distraction-free writing** — goyo.vim, limelight.vim
- **Personal wiki** — vimwiki

**Updating from an older checkout:** run `:PlugClean` and then `:PlugInstall`. ctrlp.vim and
syntastic have been replaced by fzf.vim and ALE (syntastic is archived upstream), and `:PlugClean`
removes the old copies from `~/.vim/plugged`. `<C-p>` still opens the file finder, so the habit
carries over.

## vim-airline — status line

Draws the bottom status line (mode, git branch, filename, filetype, cursor position, and ALE's
error/warning counts) using `vim-airline-themes` for colors. It's informational, not interactive —
there's nothing to press, but the glyphs it draws need a Nerd Font (see the top-level readme's Font
section) or they'll show as boxes.

## fzf.vim — fuzzy finding

fzf.vim drives the `fzf` binary that Base tools installs, so the finder is the same one as the
shell's Ctrl-T and Ctrl-R. File lists come from `fd` when it is installed (respecting
`.gitignore`), and `:Rg` searches file contents with ripgrep.

| Shortcut | Command | Action |
|---|---|---|
| `<C-p>` | `:Files` | Find a file under the current directory |
| `<Leader>b` | `:Buffers` | Switch between open buffers |
| `<Leader>r` | `:Rg` | Search file contents (ripgrep), jump to a match |
| `<Leader>h` | `:History` | Recently opened files |
| `<Leader>g` | `:GFiles?` | Files with uncommitted git changes |

Inside any fzf window:

| Key | Action |
|---|---|
| type to filter | Fuzzy-matches as you type. `'word` matches exactly, `^start`, `end$`, `!not` |
| `<C-j>` / `<C-k>` or `↓` / `↑` | Move the selection |
| `<CR>` | Open the selected file |
| `<C-t>` | Open in a new tab |
| `<C-v>` | Open in a vertical split |
| `<C-x>` | Open in a horizontal split |
| `<Tab>` | Mark several entries (where the command allows it), then `<CR>` |
| `<Esc>` or `<C-c>` | Close |

`:Lines`, `:BLines`, `:Commits`, `:Commands`, `:Maps` and `:Helptags` are also there, unmapped.

## vim-fugitive — git integration

| Command | Action |
|---|---|
| `:Git` (or `:G`) | Open `git status` in a buffer |
| `:Git blame` | Blame the current file, line by line |
| `:Gdiffsplit` | Diff the current file against the index |
| `:Gread` | Revert the current buffer to the index version |
| `:Gwrite` | Stage the current buffer (`git add`) |
| `:Git commit` | Commit |
| `:Git push` / `:Git pull` | Push / pull |

Inside the `:Git` status window:

| Key | Action |
|---|---|
| `s` | Stage the file/hunk under the cursor |
| `u` | Unstage it |
| `=` | Toggle an inline diff for the entry under the cursor |
| `cc` | Commit |
| `dd` | Open a diff split for the entry under the cursor |

## vim-gitgutter — inline diff signs

Shows `+`/`~`/`-` in the sign column for lines added, changed, or removed versus the index.

| Shortcut | Action |
|---|---|
| `]c` | Jump to the next hunk |
| `[c` | Jump to the previous hunk |
| `<Leader>hs` | Stage the hunk under the cursor |
| `<Leader>hu` | Undo the hunk under the cursor |
| `<Leader>hp` | Preview the hunk under the cursor in a popup |

## NERDTree — file explorer

`.vimrc` maps `<C-n>` to `:NERDTreeFocus` (focus the tree, opening it first if it's closed) rather
than a plain toggle, and sets `NERDTreeShowHidden=1` so dotfiles are visible from the start.

| Shortcut | Action |
|---|---|
| `<C-n>` | Open/focus NERDTree |
| `o` | Open the file/directory under the cursor |
| `t` | Open in a new tab |
| `i` / `s` | Open in a horizontal / vertical split |
| `m` | Menu: add, delete, rename, copy |
| `R` | Refresh the tree |
| `q` | Close NERDTree |
| `?` | Toggle the quick-help panel |

## ALE — linting and fixing

ALE runs linters in the background as you type and when you save, and marks problems in the sign
column (`✗` errors, `!` warnings) with the message shown when the cursor is on the line. It replaces
syntastic, which only checked on save and blocked the editor while it did.

It uses whatever linters are on PATH. The `.vimrc` pins two:

| Filetype | Linter | Fixers (`<Leader>f`) |
|---|---|---|
| Python | `ruff check` | `ruff --fix`, then `ruff format` |
| Shell | `shellcheck` | — |
| everything | — | strip trailing whitespace and trailing blank lines |

ruff comes from mise and shellcheck from Base tools, so both are already installed. Other
filetypes use ALE's defaults: whatever linter for that language is on PATH.

| Shortcut | Action |
|---|---|
| `]g` / `[g` | Jump to the next / previous problem (wraps around) |
| `<Leader>d` | Show the full message for the problem under the cursor |
| `<Leader>f` | Run the fixers on this file |
| `:ALEInfo` | What ALE is running for this file, and why (start here when nothing shows up) |
| `:ALEToggle` | Turn linting off and on |

**Fixing is never automatic** (`g:ale_fix_on_save = 0`): a file only changes when you press
`<Leader>f`. Set `let g:ale_fix_on_save = 1` in your own vimrc if you would rather it ran on save.

## vim-commentary — comment toggling

| Shortcut | Action |
|---|---|
| `gcc` | Comment/uncomment the current line |
| `gc{motion}` | Comment/uncomment over a motion, e.g. `gcap` for a paragraph |
| `gc` (visual mode) | Comment/uncomment the selection |
| `gcu` | Uncomment a contiguous block of commented lines around the cursor |

## goyo.vim + limelight.vim — distraction-free writing

`.vimrc` wires the two together: entering Goyo automatically turns on Limelight and spell-check,
leaving Goyo turns them back off.

| Command | Action |
|---|---|
| `:Goyo` | Toggle distraction-free mode (centered column, no status/command line) |
| `:Goyo!` | Force it closed if it gets stuck |
| `:Limelight` | Highlight the current paragraph, dim everything else (auto-run by Goyo here) |
| `:Limelight!` | Turn dimming off |

## vimwiki — personal wiki

Uses the default `<Leader>w` prefix — `.vimrc` doesn't remap it.

| Shortcut | Action |
|---|---|
| `<Leader>ww` | Open (or create) the default wiki's index page |
| `<Leader>wt` | Open the index page in a new tab |
| `<CR>` on a link | Follow it, creating the page if it doesn't exist yet |
| `<Backspace>` | Go back to the previous page |
| `<Tab>` / `<S-Tab>` | Move to the next/previous link on the page |
| `<Leader>wd` | Delete the current wiki page |
| `<Leader>wr` | Rename the current wiki page |

## Other custom mappings

Not plugins, but set alongside them in `.vimrc`:

| Shortcut | Action |
|---|---|
| `<C-h>` / `<C-j>` / `<C-k>` / `<C-l>` | Move focus between window splits |
| `<F2>` | Save a session to `~/vim_session` |
| `<F3>` | Load the session saved with `<F2>` |
| `<F4>` | Toggle `'paste'` mode (vim only — Neovim removed the option; bracketed paste makes it unnecessary) |
| `:C` | Clear the current search highlight |

The F2/F3 mappings used to carry trailing `" comments` on the same line. Vim has no comments after
`:map`, so those characters were part of the mapping and ran after it; they are gone now.

Settings, the same everywhere:

- **Search:** `hlsearch`, `incsearch`, `ignorecase` + `smartcase` (a capital letter in the pattern
  makes it case-sensitive).
- **Indentation:** 4 spaces — `expandtab`, `tabstop`, `shiftwidth` and `softtabstop` all 4.
- **Clipboard:** wired to the unnamed register — `unnamedplus` on Linux, `unnamed` on macOS and
  Windows — so `y`/`p` read and write the system clipboard directly, no `"+`/`"*` prefix needed.
- **No bell:** `visualbell` with an empty visual bell.

## Checks

CI installs every plugin into vim and Neovim and fails if either prints an error on start-up, or if
`:Files`, ALE or the `<C-p>` mapping are missing — see `tests/vim-smoke.sh`.
