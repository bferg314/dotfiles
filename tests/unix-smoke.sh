#!/usr/bin/env bash
# End-to-end smoke test for the Linux and macOS setup: run Link dotfiles (and
# optionally install the mise toolchain), then start a real interactive shell
# and check that it loads cleanly and has what it should.
#
#     tests/unix-smoke.sh linux            # links only: fast, no network
#     tests/unix-smoke.sh linux --tools    # also install mise and its tools
#     tests/unix-smoke.sh mac   [--tools]  # the macOS side (zsh)
#
# It changes the real $HOME -- run it in a container or a CI runner, not on a
# machine you care about. CI runs it in Debian, Ubuntu, Fedora and Arch
# containers and on a macOS runner (.github/workflows/ci.yml). Locally:
#
#     docker run --rm -t -v "$PWD:/repo:ro" debian:13 bash -c \
#         'apt-get update -qq && apt-get install -y -qq git curl ca-certificates >/dev/null &&
#          cp -r /repo /dotfiles && /dotfiles/tests/unix-smoke.sh linux --tools'
#
# Exits 0 when everything passed, 1 on any failure.

set -u

PLATFORM="${1:-}"
WITH_TOOLS=0
[ "${2:-}" = "--tools" ] && WITH_TOOLS=1

case "$PLATFORM" in
    linux) SHELL_BIN=bash; RCDIR="$HOME/.bashrc.d" ;;
    mac)   SHELL_BIN=zsh;  RCDIR="$HOME/.zshrc.d" ;;
    *) echo "usage: $0 linux|mac [--tools]" >&2; exit 2 ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$REPO_ROOT/$PLATFORM"
export REPO_ROOT SCRIPT_DIR

# shellcheck source=linux/installs/common.sh
. "$SCRIPT_DIR/installs/common.sh"
# shellcheck source=lib/menu.sh
. "$REPO_ROOT/lib/menu.sh"
# shellcheck source=linux/tasks.sh
. "$SCRIPT_DIR/tasks.sh"

passed=0
failed=0
pass() { passed=$((passed + 1)); printf '\033[0;32mPASS\033[0m  %s\n' "$1"; }
fail() { failed=$((failed + 1)); printf '\033[0;31mFAIL\033[0m  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; }

# ─── Link dotfiles ────────────────────────────────────────────────────────────

# A real file where a link is about to go must be backed up, not lost.
mkdir -p "$HOME/.config/zellij"
echo 'theme "mine"' > "$HOME/.config/zellij/config.kdl"
# A snippet left behind by an older checkout must be pruned.
mkdir -p "$RCDIR"
ln -sf "$REPO_ROOT/linux/bashrc.d/hist.bashrc" "$RCDIR/hist.bashrc"
touch "$HOME/.${SHELL_BIN}rc"
# A setting already in ~/.gitconfig that the shared file also sets. Yours must
# survive the include being added.
printf '[merge]\n\tconflictStyle = diff3\n' >> "$HOME/.gitconfig"

if task_links >/tmp/links.log 2>&1; then
    pass "Link dotfiles ran"
else
    fail "Link dotfiles failed" "$(tail -5 /tmp/links.log)"
fi

if ls "$HOME"/.config/zellij/config.kdl.bak-* >/dev/null 2>&1; then
    pass "an existing real config was backed up before linking"
else
    fail "an existing real config was overwritten without a backup"
fi

if [ ! -L "$RCDIR/hist.bashrc" ]; then
    pass "a stale link from an older checkout was pruned"
else
    fail "stale link $RCDIR/hist.bashrc survived"
fi

# ─── Toolchain ────────────────────────────────────────────────────────────────

if [ "$WITH_TOOLS" = 1 ]; then
    if [ "$PLATFORM" = linux ]; then
        install_mise >/tmp/tools.log 2>&1 || fail "install_mise failed" "$(tail -5 /tmp/tools.log)"
    else
        brew install mise starship zoxide fzf atuin eza bat git-delta lazygit >/tmp/tools.log 2>&1 ||
            fail "brew install failed" "$(tail -5 /tmp/tools.log)"
    fi
    if mise_install_tools >>/tmp/tools.log 2>&1; then
        pass "mise installed every tool in the config"
    else
        fail "mise_install_tools failed" "$(tail -15 /tmp/tools.log)"
    fi
    # mise_tools_missing returns 1 with no output when mise itself is absent,
    # which an output check alone would read as "nothing missing".
    if missing="$(mise_tools_missing)"; then
        [ -z "$missing" ] && pass "mise reports nothing missing" || fail "mise reports missing: $missing"
    else
        fail "mise is not installed"
    fi
    if go_tools_install >>/tmp/tools.log 2>&1; then
        pass "gup installed the Go tools from shared/gup/gup.json"
    else
        fail "go_tools_install failed" "$(tail -15 /tmp/tools.log)"
    fi
    missing="$(go_tools_missing)"
    [ -z "$missing" ] && pass "every Go tool is in $(go_bin_dir)" || fail "Go tools missing: $missing"
    # delta exists now, so Base tools would add its include; do the same.
    dot_git_delta_include >/dev/null 2>&1
fi

# ─── Status ───────────────────────────────────────────────────────────────────

detail="$(status_links)"
if [ $? -eq 0 ]; then
    pass "Link dotfiles reports done ($detail)"
else
    fail "Link dotfiles still reports not done" "$detail"
fi

# ─── Idempotence ──────────────────────────────────────────────────────────────

task_links >/tmp/links2.log 2>&1
backups="$(find "$HOME" -maxdepth 4 -name '*.bak-*' 2>/dev/null | wc -l | tr -d ' ')"
[ "$backups" = 1 ] && pass "a second run made no new backups" || fail "a second run left $backups backups"
includes="$(git config --global --get-all include.path | grep -c 'shared/git/gitconfig')"
[ "$includes" = 1 ] && pass "the gitconfig include is added exactly once" || fail "gitconfig included $includes times"
rc_blocks="$(grep -c 'Source all files from' "$HOME/.${SHELL_BIN}rc")"
[ "$rc_blocks" = 1 ] && pass "the rc sourcing block is added exactly once" || fail "rc block appears $rc_blocks times"

# ─── git ──────────────────────────────────────────────────────────────────────

[ "$(git config --includes --global pull.rebase)" = true ] && pass "shared git settings are in effect" ||
    fail "pull.rebase is not set; the include is not being read"
style="$(git config --includes --global merge.conflictStyle)"
[ "$style" = diff3 ] && pass "a setting already in ~/.gitconfig beats the shared file" ||
    fail "the shared file overrode ~/.gitconfig (merge.conflictStyle = $style)"
if [ "$WITH_TOOLS" = 1 ]; then
    [ "$(git config --includes --global core.pager)" = delta ] && pass "delta is git's pager" || fail "core.pager is not delta"
fi

# ─── An interactive shell ─────────────────────────────────────────────────────
#
# What a new terminal would do: read the rc file, which sources every linked
# snippet. Any output on stderr is a snippet erroring on start-up.

probe='type mkcd >/dev/null && type extract >/dev/null && type uvr >/dev/null && type lsalias >/dev/null && echo SHELL_OK'
if [ "$WITH_TOOLS" = 1 ]; then
    probe="$probe; for c in mise node python go uv ruff gup starship zoxide fzf eza bat delta lazygit atuin; do command -v \$c >/dev/null || echo MISSING:\$c; done"
    probe="$probe; type z >/dev/null 2>&1 || echo MISSING:z-function"
    probe="$probe; [ -n \"\${STARSHIP_SHELL:-}\" ] || echo MISSING:starship-prompt"
    probe="$probe; alias ll | grep -q eza || echo MISSING:eza-alias"
    # folgit must resolve to the binary, and `folgit` to its cd-on-exit wrapper.
    probe="$probe; [ -x \"$(go_bin_dir)/folgit\" ] && command -v folgit >/dev/null || echo MISSING:folgit"
    probe="$probe; type folgit 2>/dev/null | grep -q function || echo MISSING:folgit-shell-integration"
fi

# Job-control, line-editing and zle notices are what a shell without a terminal
# (a CI runner) says about itself, not errors in the config.
noise='no job control|cannot set terminal process group|can.t set tty pgrp|can.t change option: zle|Inappropriate ioctl|line editing not enabled|cannot access the terminal'
out="$("$SHELL_BIN" -i -c "$probe" 2>/tmp/shell.err)"
errs="$(grep -Ev "$noise" /tmp/shell.err | grep -v '^$')"

case "$out" in
    *SHELL_OK*) pass "an interactive $SHELL_BIN loads the snippets" ;;
    *) fail "an interactive $SHELL_BIN did not get the snippets" "$out" ;;
esac
if [ -z "$errs" ]; then
    pass "an interactive $SHELL_BIN starts without errors"
else
    fail "an interactive $SHELL_BIN printed errors on start-up" "$errs"
fi
if [ "$WITH_TOOLS" = 1 ]; then
    missing="$(printf '%s\n' "$out" | grep '^MISSING:' | cut -d: -f2 | paste -sd' ' -)"
    [ -z "$missing" ] && pass "every tool and integration is live in the shell" || fail "not live in the shell: $missing"
fi

# ─── Done ─────────────────────────────────────────────────────────────────────

echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
