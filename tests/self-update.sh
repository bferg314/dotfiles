#!/usr/bin/env bash
# Tests for the setup menu's self-update (menu_self_update and menu_restart in
# lib/menu.sh): fetch on start, fast-forward, restart on the new code, and
# leave the checkout alone whenever that is not safe.
#
# Builds a throwaway origin and checkout under a temp dir, so it touches
# nothing else, but CI runs it in containers like the other tests. Needs git.
# Runs under bash 3.2 because mac/setup.sh does:
#
#     docker run --rm -v "$PWD:/repo:ro" bash:3.2 sh -c \
#         'apk add -q git >/dev/null && bash /repo/tests/self-update.sh'

set -u

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/menu.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

passed=0
failed=0
pass() { passed=$((passed + 1)); printf 'PASS  %s\n' "$1"; }
fail() { failed=$((failed + 1)); printf 'FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; }

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
git() { command git -c init.defaultBranch=main -c advice.detachedHead=false "$@"; }

# The script menu_restart execs: it reports how it was started.
cat > "$WORK/restarted.sh" <<'EOF'
printf 'RESTARTED from=%s args=%s\n' "${DOTFILES_UPDATED:-}" "$*"
EOF

# A fresh origin with one commit, a checkout of it, and a second commit pushed
# from elsewhere, so the checkout is one behind once it fetches.
setup_repos() {
    rm -rf "$WORK/origin.git" "$WORK/checkout" "$WORK/other"
    git init -q --bare "$WORK/origin.git"
    git clone -q "$WORK/origin.git" "$WORK/checkout" 2>/dev/null
    echo one > "$WORK/checkout/file"
    git -C "$WORK/checkout" add file
    git -C "$WORK/checkout" commit -qm one
    git -C "$WORK/checkout" push -q origin main
    git clone -q "$WORK/origin.git" "$WORK/other"
    echo two > "$WORK/other/file"
    git -C "$WORK/other" commit -qam two
    git -C "$WORK/other" push -q origin main
    START="$(git -C "$WORK/checkout" rev-parse HEAD)"
    LATEST="$(git -C "$WORK/other" rev-parse HEAD)"
}

# Run menu_self_update in a child shell, the way menu_main does, then print
# MENU_NOTICE if it came back instead of restarting.
run_update() {
    REPO_ROOT="$WORK/checkout" MENU_SCRIPT="$WORK/restarted.sh" bash -c '
        . "$1"; shift
        menu_self_update "$@"
        printf "NOTICE=%s\n" "$MENU_NOTICE"
    ' _ "$LIB" "$@" 2>&1
}

head_of() { git -C "$WORK/checkout" rev-parse HEAD; }

# ─── Cases ────────────────────────────────────────────────────────────────────

setup_repos
out="$(run_update --flag)"
case "$out" in
    *"RESTARTED from=$START args=--flag"*) pass "behind: fast-forwards and restarts with the same args" ;;
    *) fail "behind: fast-forwards and restarts with the same args" "$out" ;;
esac
[ "$(head_of)" = "$LATEST" ] && pass "behind: checkout is on the latest commit" ||
    fail "behind: checkout is on the latest commit" "HEAD $(head_of), want $LATEST"

# The restarted process: reports what arrived and does not check again.
git -C "$WORK/checkout" remote set-url origin "$WORK/missing.git"
out="$(DOTFILES_UPDATED="$START" run_update)"
case "$out" in
    *RESTARTED*) fail "after restart: does not update again" "$out" ;;
    *"NOTICE=updated from ${START%"${START#???????}"} · 1 new commit(s)"*) pass "after restart: does not update again, reports what arrived" ;;
    *) fail "after restart: does not update again, reports what arrived" "$out" ;;
esac

setup_repos
git -C "$WORK/checkout" fetch -q origin
git -C "$WORK/checkout" merge -q --ff-only origin/main
out="$(run_update)"
case "$out" in
    *RESTARTED*) fail "up to date: no restart" "$out" ;;
    *"NOTICE=") pass "up to date: no restart, no notice" ;;
    *) fail "up to date: no restart, no notice" "$out" ;;
esac

# A modified file the update would overwrite: git refuses the fast-forward and
# the edit must survive.
setup_repos
echo mine > "$WORK/checkout/file"
out="$(run_update)"
case "$out" in
    *RESTARTED*) fail "dirty file in the way: no restart" "$out" ;;
    *"NOTICE=1 update(s) not applied"*) pass "dirty file in the way: no restart, says why" ;;
    *) fail "dirty file in the way: no restart, says why" "$out" ;;
esac
[ "$(head_of)" = "$START" ] && [ "$(cat "$WORK/checkout/file")" = "mine" ] &&
    pass "dirty file in the way: HEAD and the edit are untouched" ||
    fail "dirty file in the way: HEAD and the edit are untouched"

# Local commits: a fast-forward is impossible, and nothing is reset.
setup_repos
echo extra > "$WORK/checkout/extra"
git -C "$WORK/checkout" add extra
git -C "$WORK/checkout" commit -qm local
mine="$(head_of)"
out="$(run_update)"
case "$out" in
    *RESTARTED*) fail "diverged: no restart" "$out" ;;
    *"not applied"*) [ "$(head_of)" = "$mine" ] && pass "diverged: no restart, local commit kept" ||
        fail "diverged: local commit kept" "HEAD $(head_of)" ;;
    *) fail "diverged: no restart, says why" "$out" ;;
esac

setup_repos
git -C "$WORK/checkout" remote set-url origin "$WORK/missing.git"
out="$(run_update)"
case "$out" in
    *"NOTICE=could not reach origin"*) pass "unreachable origin: runs the local version" ;;
    *) fail "unreachable origin: runs the local version" "$out" ;;
esac

setup_repos
out="$(run_update --no-update)"
case "$out" in
    *RESTARTED*) fail "--no-update: skips the check" "$out" ;;
    *) [ "$(head_of)" = "$START" ] && pass "--no-update: skips the check" || fail "--no-update: skips the check" ;;
esac
setup_repos
out="$(DOTFILES_NO_UPDATE=1 run_update)"
case "$out" in
    *RESTARTED*) fail "DOTFILES_NO_UPDATE: skips the check" "$out" ;;
    *) [ "$(head_of)" = "$START" ] && pass "DOTFILES_NO_UPDATE: skips the check" || fail "DOTFILES_NO_UPDATE: skips the check" ;;
esac

setup_repos
git -C "$WORK/checkout" switch -q -c local-only
out="$(run_update)"
case "$out" in
    *"NOTICE=no origin/local-only"*) pass "branch not on origin: says so, no restart" ;;
    *) fail "branch not on origin: says so, no restart" "$out" ;;
esac

setup_repos
git -C "$WORK/checkout" switch -q --detach
out="$(run_update)"
case "$out" in
    *"NOTICE=detached HEAD"*) pass "detached HEAD: skips the check" ;;
    *) fail "detached HEAD: skips the check" "$out" ;;
esac

printf '\n%s passed, %s failed\n' "$passed" "$failed"
[ "$failed" = "0" ]
