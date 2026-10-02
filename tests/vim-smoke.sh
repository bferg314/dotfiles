#!/usr/bin/env bash
# Smoke test for shared/vim/.vimrc and shared/nvim/init.vim: install the
# plugins, then start vim and Neovim and check that both load the config with
# no errors and that the key plugins (fzf.vim, ALE) are live.
#
# Changes the real $HOME; CI runs it in a Debian container. Needs git, curl,
# vim and nvim on PATH. Locally:
#
#     docker run --rm -t -v "$PWD:/repo:ro" debian:13 bash -c \
#         'apt-get update -qq && apt-get install -y -qq git curl ca-certificates vim neovim >/dev/null &&
#          /repo/tests/vim-smoke.sh'

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUG='https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

passed=0
failed=0
pass() { passed=$((passed + 1)); printf 'PASS  %s\n' "$1"; }
fail() { failed=$((failed + 1)); printf 'FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; }

mkdir -p "$HOME/.config/nvim"
ln -sfn "$REPO_ROOT/shared/vim/.vimrc" "$HOME/.vimrc"
ln -sfn "$REPO_ROOT/shared/nvim/init.vim" "$HOME/.config/nvim/init.vim"
curl -fsSLo "$HOME/.vim/autoload/plug.vim" --create-dirs "$PLUG"
curl -fsSLo "$HOME/.local/share/nvim/site/autoload/plug.vim" --create-dirs "$PLUG"

vim -E -s -u "$HOME/.vimrc" +PlugInstall +qa >/dev/null 2>&1
want="ale fzf fzf.vim goyo.vim limelight.vim nerdtree vim-airline vim-airline-themes vim-commentary vim-fugitive vim-gitgutter vimwiki"
have="$(ls "$HOME/.vim/plugged" | tr '\n' ' ')"
missing=""
for p in $want; do
    case " $have " in *" $p "*) ;; *) missing="$missing $p" ;; esac
done
[ -z "$missing" ] && pass "PlugInstall fetched every plugin" || fail "plugins missing:$missing"

# vim: collect everything it said while starting, plus a probe line.
probe='echo "PROBE" exists(":Files") exists(":ALEFix") maparg("<C-p>", "n")'
vim -E -s -N -u "$HOME/.vimrc" \
    -c 'redir! > /tmp/vim.out' -c 'silent messages' -c "$probe" -c 'redir END' -c qa
vim_errors="$(grep -E '^(E[0-9]+|Error)' /tmp/vim.out)"
[ -z "$vim_errors" ] && pass "vim starts without errors" || fail "vim startup errors" "$vim_errors"
grep -q 'PROBE 2 2 :Files<CR>' /tmp/vim.out && pass "vim has :Files, ALE and the Ctrl-P mapping" ||
    fail "vim probe" "$(grep PROBE /tmp/vim.out)"

# Neovim: init.vim sources the same vimrc; anything on stderr is an error.
nvim_out="$(nvim --headless -c "$probe" -c qa 2>&1)"
case "$nvim_out" in
    *'PROBE 2 2 :Files<CR>'*) pass "Neovim reads the shared vimrc (:Files, ALE, Ctrl-P)" ;;
    *) fail "Neovim probe" "$nvim_out" ;;
esac
nvim_errors="$(printf '%s\n' "$nvim_out" | grep -E '^(E[0-9]+|Error)')"
[ -z "$nvim_errors" ] && pass "Neovim starts without errors" || fail "Neovim startup errors" "$nvim_errors"

echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
