# Vim Plugins

The `.vimrc` on each platform (`linux/vim/.vimrc`, `mac/vim/.vimrc`, `windows/vim/.vimrc`) loads
its plugins through [vim-plug](https://github.com/junegunn/vim-plug). The setup menu's **Editor
plugins** task installs `plug.vim` itself; once it's linked and vim-plug is present, open vim and
run:

```vim
:PlugInstall
```

to fetch the plugins below. `:PlugUpdate` upgrades them later, `:PlugClean` removes anything no
longer listed in `.vimrc`.

None of the three `.vimrc` files remap `<Leader>`, so it's vim's default: `\`.

The three configs install the same ten plugins, grouped and ordered identically, so a shortcut
below works the same way on any machine:

- **Status line** — vim-airline, vim-airline-themes
- **File navigation** — ctrlp.vim, NERDTree
- **Code quality** — syntastic, vim-commentary
- **Git integration** — vim-fugitive, vim-gitgutter
- **Distraction-free writing** — goyo.vim, limelight.vim
- **Personal wiki** — vimwiki

If you're updating from an older checkout, run `:PlugClean` before `:PlugInstall` — NERDTree moved
from the archived `scrooloose/nerdtree` to the maintained `preservim/nerdtree` fork, and the old
one otherwise lingers in `~/.vim/plugged`.

## vim-airline — status line

Draws the bottom status line (mode, git branch, filename, filetype, cursor position) using
`vim-airline-themes` for colors. It's informational, not interactive — there's nothing to press,
but the glyphs it draws need a Nerd Font (see the top-level readme's Font section) or they'll show
as boxes.

## ctrlp.vim — fuzzy file finder

| Shortcut | Action |
|---|---|
| `<C-p>` | Open the finder (files, by default) |
| type to filter | Fuzzy-matches as you type |
| `<C-j>` / `<C-k>` or `↓` / `↑` | Move the selection |
| `<CR>` | Open selected file |
| `<C-t>` | Open in a new tab |
| `<C-v>` | Open in a vertical split |
| `<C-x>` | Open in a horizontal split |
| `<C-f>` / `<C-b>` | Cycle finder mode: files → buffers → most-recently-used |
| `<C-r>` | Toggle regex matching |
| `<Esc>` or `<C-c>` | Close |

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
| `<C-n>` | Open/focus NERDTree (custom mapping, all three platforms) |
| `o` | Open the file/directory under the cursor |
| `t` | Open in a new tab |
| `i` / `s` | Open in a horizontal / vertical split |
| `m` | Menu: add, delete, rename, copy |
| `R` | Refresh the tree |
| `q` | Close NERDTree |
| `?` | Toggle the quick-help panel |

## syntastic — syntax checking

Runs each file's syntax checker on save and populates the location list with the results.

| Command | Action |
|---|---|
| `:SyntasticCheck` | Check the current file on demand |
| `:Errors` | Open the location list of errors |
| `:lnext` / `:lprev` | Jump to the next/previous error (standard vim location-list commands) |
| `:SyntasticToggleMode` | Switch between active (on save) and passive (on demand) checking |

Syntastic only checks with whatever linter is already on `PATH` for a filetype — install the
linter itself (e.g. `shellcheck`, `pylint`) separately; syntastic won't do that for you.

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

Not plugins, but set alongside them in `.vimrc`, identically on all three platforms:

| Shortcut | Action |
|---|---|
| `<C-h>` / `<C-j>` / `<C-k>` / `<C-l>` | Move focus between window splits |
| `<F2>` | Save a session to `~/vim_session` |
| `<F3>` | Load the session saved with `<F2>` |
| `<F4>` | Toggle `'paste'` mode (`pastetoggle`) |
| `:C` | Clear the current search highlight |

`<F3>` used to double-book session-load and paste-toggle on macOS, where `pastetoggle` silently
won and the session mapping never fired. Paste-toggle now lives on `<F4>` everywhere so both work.

Search is `hlsearch` + `ignorecase` everywhere, indentation is 4 spaces (`expandtab`,
`tabstop=4`, and `shiftwidth=4` on macOS), and the system clipboard is wired to the unnamed
register (`unnamedplus` on Linux, `unnamed` on macOS/Windows) — `y`/`p` read and write it directly,
no `"+`/`"*` prefix needed.
