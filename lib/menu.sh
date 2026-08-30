#!/usr/bin/env bash
# Shared setup-menu engine for linux/setup.sh and mac/setup.sh.
#
# Source this file, do not execute it. The caller registers tasks with
# menu_task, then calls menu_main:
#
#     . "$REPO_ROOT/lib/menu.sh"
#     menu_task "links|Link dotfiles|configure|10|task_links|status_links|"
#     menu_main
#
# macOS ships bash 3.2, and mac/setup.sh runs under it, so nothing here may use
# bash 4 features: no `declare -A`, no `readarray`, no `${x^^}`, no `&>>`.

# ─── Task table ───────────────────────────────────────────────────────────────
#
# One pipe-delimited row per task. Every part of the menu -- the listing, the
# run order, the status column, the preflight checks -- is derived from these,
# so adding a task is one line and the numbering can never drift out of sync
# with what the numbers do.
#
#     id|label|group|order|handler|probe|flags
#
# group   presets | configure | install | maintain
# order   canonical *run* order, independent of display position
# handler function to run; "-" for a preset, which only expands
# probe   function printing a short status detail; "-" for none.
#         Exit 0 = done, 1 = not done, anything else = unknown.
# flags   comma-separated: net, sudo, admin, expand:<id>+<id>+...

MENU_ROW_COUNT=0

menu_task() {
    eval "MENU_ROW_$MENU_ROW_COUNT=\$1"
    MENU_ROW_COUNT=$((MENU_ROW_COUNT + 1))
}

menu_row() { eval "printf '%s' \"\$MENU_ROW_$1\""; }

# Field <n> of a row, trimmed. Splitting with IFS='|' rather than cut keeps this
# to one subshell-free call -- it runs 7 times per row on every redraw.
_mfield() {
    local row="$1" n="$2" v=""
    local oldifs="$IFS"
    IFS='|'
    # shellcheck disable=SC2086
    set -- $row
    IFS="$oldifs"
    if [ "$n" -le "$#" ]; then
        while [ "$n" -gt 1 ]; do
            shift
            n=$((n - 1))
        done
        v="$1"
    fi
    v="${v#"${v%%[![:space:]]*}"}"
    v="${v%"${v##*[![:space:]]}"}"
    printf '%s' "$v"
}

menu_field() { _mfield "$(menu_row "$1")" "$2"; }

menu_id()      { menu_field "$1" 1; }
menu_label()   { menu_field "$1" 2; }
menu_group()   { menu_field "$1" 3; }
menu_order()   { menu_field "$1" 4; }
menu_handler() { menu_field "$1" 5; }
menu_probe()   { menu_field "$1" 6; }
menu_flags()   { menu_field "$1" 7; }

menu_index_of() {
    local want="$1" i=0
    while [ "$i" -lt "$MENU_ROW_COUNT" ]; do
        [ "$(menu_id "$i")" = "$want" ] && { printf '%s' "$i"; return 0; }
        i=$((i + 1))
    done
    return 1
}

# Row indices in canonical run order.
menu_run_order() {
    local i=0
    while [ "$i" -lt "$MENU_ROW_COUNT" ]; do
        printf '%s %s\n' "$(menu_order "$i")" "$i"
        i=$((i + 1))
    done | sort -n | while read -r _order idx; do printf '%s\n' "$idx"; done
}

menu_has_flag() {
    case ",$(menu_flags "$1")," in
        *",$2,"*) return 0 ;;
        *) return 1 ;;
    esac
}

# The ids a preset stands for, from its expand:<id>+<id> flag.
menu_expansion() {
    local flags
    flags="$(menu_flags "$1")"
    case "$flags" in
        *expand:*) ;;
        *) return 1 ;;
    esac
    flags="${flags#*expand:}"
    flags="${flags%%,*}"
    printf '%s' "$flags" | tr '+' ' '
}

# ─── Status probing ───────────────────────────────────────────────────────────
#
# Probes are best-effort and never fatal: an erroring probe renders as "?"
# rather than taking the menu down with it.

menu_probe_all() {
    local i=0 probe detail rc
    while [ "$i" -lt "$MENU_ROW_COUNT" ]; do
        probe="$(menu_probe "$i")"
        if [ -z "$probe" ] || [ "$probe" = "-" ]; then
            eval "MENU_STATE_$i=none"
            eval "MENU_DETAIL_$i=''"
        else
            detail="$("$probe" 2>/dev/null)"
            rc=$?
            # The detail column is one cell on one row: keep the first line
            # only, so a chatty probe cannot push the table down the screen.
            detail="${detail%%
*}"
            [ ${#detail} -le 72 ] || detail="${detail:0:69}..."
            case $rc in
                0) eval "MENU_STATE_$i=done" ;;
                1) eval "MENU_STATE_$i=todo" ;;
                *) eval "MENU_STATE_$i=unknown" ;;
            esac
            eval "MENU_DETAIL_$i=\"\$detail\""
        fi
        i=$((i + 1))
    done
}

menu_state()  { eval "printf '%s' \"\${MENU_STATE_$1:-none}\""; }
menu_detail() { eval "printf '%s' \"\${MENU_DETAIL_$1:-}\""; }

menu_state_mark() {
    case "$(menu_state "$1")" in
        done)    printf '%b' "${GREEN}✓${NC}" ;;
        todo)    printf '%b' "${YELLOW}·${NC}" ;;
        unknown) printf '%b' "${YELLOW}?${NC}" ;;
        *)       printf ' ' ;;
    esac
}

# ─── Selection state ──────────────────────────────────────────────────────────

MENU_SELECTED=" "

menu_is_selected() {
    case "$MENU_SELECTED" in
        *" $1 "*) return 0 ;;
        *) return 1 ;;
    esac
}

menu_select()   { menu_is_selected "$1" || MENU_SELECTED="$MENU_SELECTED$1 "; }
menu_deselect() { MENU_SELECTED="$(printf '%s' "$MENU_SELECTED" | sed "s/ $1 / /")"; }
menu_toggle()   { if menu_is_selected "$1"; then menu_deselect "$1"; else menu_select "$1"; fi; }
menu_clear_selection() { MENU_SELECTED=" "; }

menu_select_all() {
    local i=0
    while [ "$i" -lt "$MENU_ROW_COUNT" ]; do
        [ "$(menu_group "$i")" = "presets" ] || menu_select "$(menu_id "$i")"
        i=$((i + 1))
    done
}

# Anything the machine still needs, in the groups worth defaulting on. Maintain
# tasks (update, doctor) are never preselected -- they are things you ask for.
menu_select_defaults() {
    local i=0
    menu_clear_selection
    while [ "$i" -lt "$MENU_ROW_COUNT" ]; do
        case "$(menu_group "$i")" in
            configure | install)
                [ "$(menu_state "$i")" = "todo" ] && menu_select "$(menu_id "$i")"
                ;;
        esac
        i=$((i + 1))
    done
}

# Replace presets in the selection with the tasks they stand for.
menu_expand_selection() {
    local i=0 id expanded sub
    while [ "$i" -lt "$MENU_ROW_COUNT" ]; do
        id="$(menu_id "$i")"
        if menu_is_selected "$id"; then
            if expanded="$(menu_expansion "$i")"; then
                menu_deselect "$id"
                for sub in $expanded; do menu_select "$sub"; done
            fi
        fi
        i=$((i + 1))
    done
}

# ─── Rendering ────────────────────────────────────────────────────────────────

MENU_TITLE="${MENU_TITLE:-Dotfiles Setup}"

menu_clear() { clear 2>/dev/null || printf '\033[2J\033[H'; }

# Overridable by the caller to describe the machine (distro, arch, ...).
menu_platform_line() { printf '%s' "$(uname -s) · $(uname -m)"; }

menu_header() {
    local branch=""
    if [ -n "$REPO_ROOT" ]; then
        branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    fi
    printf '\n'
    printf '%b\n' "${BOLD}${CYAN}  $MENU_TITLE${NC}"
    printf '%b\n' "${BLUE}  $(menu_platform_line)${branch:+ · branch $branch}${NC}"
    printf '\n'
}

_menu_group_title() {
    case "$1" in
        presets)   printf 'PRESETS' ;;
        configure) printf 'CONFIGURE' ;;
        install)   printf 'INSTALL' ;;
        maintain)  printf 'MAINTAIN' ;;
        *)         printf '%s' "$1" ;;
    esac
}

_menu_label_width() {
    local i=0 len max=0 label
    while [ "$i" -lt "$MENU_ROW_COUNT" ]; do
        label="$(menu_label "$i")"
        len=${#label}
        [ "$len" -gt "$max" ] && max=$len
        i=$((i + 1))
    done
    printf '%s' "$max"
}

# The list, grouped, with a checkbox on the left and current state on the right.
# Numbers are display-only -- they are assigned here and used only by the
# fallback picker, so nothing downstream depends on them.
menu_list() {
    local numbered="$1"
    local width group last_group="" i n=0 idx

    width="$(_menu_label_width)"

    for group in presets configure install maintain; do
        i=0
        while [ "$i" -lt "$MENU_ROW_COUNT" ]; do
            idx=$i
            i=$((i + 1))
            [ "$(menu_group "$idx")" = "$group" ] || continue

            if [ "$last_group" != "$group" ]; then
                [ -n "$last_group" ] && printf '\n'
                printf '%b\n' "${BOLD}  $(_menu_group_title "$group")${NC}"
                last_group="$group"
            fi

            n=$((n + 1))
            eval "MENU_DISPLAY_$n=\"\$(menu_id \"\$idx\")\""

            printf '    '
            [ "$numbered" = "numbered" ] && printf '%2d ' "$n"
            if menu_is_selected "$(menu_id "$idx")"; then
                printf '%b' "${GREEN}[x]${NC} "
            else
                printf '[ ] '
            fi
            printf '%-*s' "$width" "$(menu_label "$idx")"

            if [ "$(menu_state "$idx")" != "none" ]; then
                printf '  %b %b' "$(menu_state_mark "$idx")" "${BLUE}$(menu_detail "$idx")${NC}"
            fi
            printf '\n'
        done
    done
    MENU_DISPLAY_COUNT=$n
    printf '\n'
}

menu_display_id() { eval "printf '%s' \"\${MENU_DISPLAY_$1:-}\""; }

# ─── Pickers ──────────────────────────────────────────────────────────────────

menu_have_gum() {
    [ -t 0 ] && [ -t 1 ] && command -v gum >/dev/null 2>&1
}

# gum choose gives arrow keys, space to toggle and / to filter from a single
# prebuilt binary, on all three platforms. We deliberately do not hand-roll a
# raw-mode equivalent: maintaining a bash escape-sequence reader *and* a
# PowerShell ReadKey one is the duplication this rewrite exists to remove.
_menu_pick_gum() {
    local i=0 selected="" label chosen
    local labels

    # Options are passed as arguments rather than piped in. gum accepts either,
    # but reading them from stdin leaves it taking options from the pipe and
    # keystrokes from /dev/tty, which breaks anywhere stdin is not a terminal.
    labels=()
    while [ "$i" -lt "$MENU_ROW_COUNT" ]; do
        label="$(menu_label "$i")"
        labels[i]="$label"
        menu_is_selected "$(menu_id "$i")" && selected="${selected:+$selected,}$label"
        i=$((i + 1))
    done

    if [ -n "$selected" ]; then
        chosen="$(gum choose --no-limit \
            --header "space toggles · / filters · enter confirms · esc quits" \
            --selected "$selected" "${labels[@]}")" || return 1
    else
        chosen="$(gum choose --no-limit \
            --header "space toggles · / filters · enter confirms · esc quits" \
            "${labels[@]}")" || return 1
    fi

    menu_clear_selection
    while IFS= read -r label; do
        [ -n "$label" ] || continue
        i=0
        while [ "$i" -lt "$MENU_ROW_COUNT" ]; do
            [ "$(menu_label "$i")" = "$label" ] && menu_select "$(menu_id "$i")"
            i=$((i + 1))
        done
    done <<EOF
$chosen
EOF
    return 0
}

# No gum, or no TTY: the same table with numbers, toggled by typing them.
# Accepts "1 3 5", ranges like "2-4", and the w/s/a/n shortcuts.
_menu_pick_fallback() {
    local reply token start end n

    while true; do
        menu_clear
        menu_header
        menu_list numbered
        printf '%b\n' "${BLUE}  type numbers to toggle (e.g. 1 3 5, 2-4) · a all · n none · enter runs · q quit${NC}"
        printf '\n'
        menu_read reply "$(printf '%b' "${BOLD}${BLUE}  > ${NC}")" || return 1

        case "$reply" in
            "") return 0 ;;
            q | Q | quit) return 1 ;;
            a | A) menu_select_all; continue ;;
            n | N) menu_clear_selection; continue ;;
        esac

        for token in $reply; do
            case "$token" in
                *[!0-9-]* | -* | *-) warn "Ignoring '$token'"; continue ;;
                *-*)
                    start="${token%%-*}"
                    end="${token##*-}"
                    n="$start"
                    while [ "$n" -le "$end" ]; do
                        [ "$n" -ge 1 ] && [ "$n" -le "$MENU_DISPLAY_COUNT" ] &&
                            menu_toggle "$(menu_display_id "$n")"
                        n=$((n + 1))
                    done
                    ;;
                *)
                    if [ "$token" -ge 1 ] && [ "$token" -le "$MENU_DISPLAY_COUNT" ]; then
                        menu_toggle "$(menu_display_id "$token")"
                    else
                        warn "No task numbered $token"
                    fi
                    ;;
            esac
        done
    done
}

menu_pick() {
    if menu_have_gum; then
        menu_clear
        menu_header
        menu_list
        _menu_pick_gum
    else
        _menu_pick_fallback
    fi
}

# ─── Input ────────────────────────────────────────────────────────────────────

# Every prompt goes through this. A closed stdin (piped input that ran out, a
# terminal that went away) must end the menu, not spin it -- so this returns
# non-zero at EOF and every caller propagates that up to the main loop, which
# would otherwise re-prompt forever against a `read` that can never succeed.
menu_read() {
    local __var="$1" __prompt="$2" __value
    if [ -n "$__prompt" ]; then
        printf '%b' "$__prompt"
    fi
    if IFS= read -r __value; then
        eval "$__var=\$__value"
        return 0
    fi
    return 1
}

menu_pause() {
    menu_read _menu_discard "$(printf '%b' "${BLUE}  ${1:-Press Enter to continue...}${NC}")"
}

# ─── Preflight ────────────────────────────────────────────────────────────────
#
# Every requirement of the whole batch is checked once, up front. Discovering
# that sudo is unavailable five minutes into a run of base + desktop is the
# failure mode this exists to prevent.

menu_preflight() {
    local ids="$1" idx need_sudo=0 need_net=0 ok=1

    for idx in $(menu_run_order); do
        menu_is_selected_id "$ids" "$(menu_id "$idx")" || continue
        menu_has_flag "$idx" sudo && need_sudo=1
        menu_has_flag "$idx" net && need_net=1
    done

    if [ "$need_sudo" = "1" ]; then
        step "Checking sudo access..."
        if [ "$(id -u)" = "0" ]; then
            ok "running as root"
        elif sudo -v; then
            ok "sudo available"
        else
            warn "sudo is required by the selected tasks and is not available"
            warn "Nothing was run. Re-select without the tasks that install packages."
            ok=0
        fi
    fi

    # Advisory rather than blocking: a proxy or captive portal can fail this
    # probe on a machine where the actual downloads would have worked, and a
    # false refusal is worse than a slow failure.
    if [ "$need_net" = "1" ]; then
        step "Checking network..."
        if curl -fsS --max-time 8 -o /dev/null https://github.com 2>/dev/null; then
            ok "github.com reachable"
        else
            warn "Could not reach github.com - downloads may fail"
            local reply=""
            menu_read reply "$(printf '%b' "${BLUE}  Continue anyway? (y/N) ${NC}")" || return 1
            case "$reply" in
                y | Y | yes | YES) ;;
                *) return 1 ;;
            esac
        fi
    fi

    [ "$ok" = "1" ]
}

menu_is_selected_id() {
    case " $1 " in
        *" $2 "*) return 0 ;;
        *) return 1 ;;
    esac
}

# ─── Runner ───────────────────────────────────────────────────────────────────

menu_confirm_plan() {
    local ids="$1" idx count=0

    printf '\n'
    printf '%b\n' "${BOLD}  Will run, in order:${NC}"
    for idx in $(menu_run_order); do
        menu_is_selected_id "$ids" "$(menu_id "$idx")" || continue
        count=$((count + 1))
        printf '    %d. %s\n' "$count" "$(menu_label "$idx")"
    done
    printf '\n'

    local reply=""
    menu_read reply "$(printf '%b' "${BOLD}${BLUE}  Proceed? (y/N) ${NC}")" || return 1
    case "$reply" in
        y | Y | yes | YES) return 0 ;;
        *) info "Nothing run."; return 1 ;;
    esac
}

# One failing task does not abort the rest: the installers are long, and a
# missing package in `desktop` should not cost you the `links` you also asked
# for. Results are tallied and reported at the end instead.
menu_run() {
    local ids="$1" idx handler label results="" rc

    for idx in $(menu_run_order); do
        menu_is_selected_id "$ids" "$(menu_id "$idx")" || continue
        handler="$(menu_handler "$idx")"
        label="$(menu_label "$idx")"
        if [ -z "$handler" ] || [ "$handler" = "-" ]; then continue; fi

        printf '\n'
        printf '%b\n' "${BOLD}${CYAN}━━━ $label ━━━${NC}"
        printf '\n'

        # Handlers that shell out to installs/*.sh run them as subprocesses, as
        # before -- those scripts use `set -e`, which would kill this menu if
        # they were sourced.
        if "$handler"; then rc=0; else rc=$?; fi
        results="$results$rc|$label
"
    done

    printf '\n'
    printf '%b\n' "${BOLD}${CYAN}━━━ Summary ━━━${NC}"
    local failures=0
    while IFS='|' read -r rc label; do
        [ -n "$label" ] || continue
        if [ "$rc" = "0" ]; then
            ok "$label"
        else
            printf '%b\n' "${RED}✗ $label (exit $rc)${NC}"
            failures=$((failures + 1))
        fi
    done <<EOF
$results
EOF

    [ "$failures" = "0" ] || warn "$failures task(s) failed"
    printf '\n'
}

# ─── Main loop ────────────────────────────────────────────────────────────────

# Guards against a typo'd handler or probe name silently doing nothing, and
# against two tasks sharing an id or a run-order slot.
menu_selftest() {
    local i=0 j id order fn problems=0
    while [ "$i" -lt "$MENU_ROW_COUNT" ]; do
        id="$(menu_id "$i")"
        order="$(menu_order "$i")"
        [ -n "$id" ] || { warn "row $i has no id"; problems=$((problems + 1)); }

        j=$((i + 1))
        while [ "$j" -lt "$MENU_ROW_COUNT" ]; do
            [ "$(menu_id "$j")" = "$id" ] && { warn "duplicate task id: $id"; problems=$((problems + 1)); }
            [ "$(menu_order "$j")" = "$order" ] && { warn "duplicate order $order on $id"; problems=$((problems + 1)); }
            j=$((j + 1))
        done

        for fn in "$(menu_handler "$i")" "$(menu_probe "$i")"; do
            if [ -z "$fn" ] || [ "$fn" = "-" ]; then continue; fi
            command -v "$fn" >/dev/null 2>&1 ||
                { warn "$id refers to undefined function: $fn"; problems=$((problems + 1)); }
        done
        i=$((i + 1))
    done
    [ "$problems" = "0" ]
}

menu_main() {
    menu_selftest || die "Task table is inconsistent (see above)"

    while true; do
        menu_probe_all
        [ "$MENU_SELECTED" = " " ] && menu_select_defaults

        menu_pick || break

        menu_expand_selection
        local ids="$MENU_SELECTED"

        if [ "$(printf '%s' "$ids" | tr -d ' ')" = "" ]; then
            info "Nothing selected."
            printf '\n'
            menu_pause || break
            continue
        fi

        if menu_confirm_plan "$ids" && menu_preflight "$ids"; then
            menu_run "$ids"
        fi

        menu_clear_selection
        menu_pause "Press Enter to return to the menu..." || break
    done

    printf '\n'
    printf '%b\n' "${CYAN}Goodbye!${NC}"
    printf '\n'
}

# ─── Update (single implementation, shared by both platforms) ─────────────────

# Fast-forward first. A hard reset is only reached by explicitly typing "yes",
# because `reset --hard` plus `clean -ffd` silently discards local edits and
# untracked files.
menu_update_repo() {
    local branch
    branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)" ||
        { warn "$REPO_ROOT is not a git repository"; return 1; }

    git -C "$REPO_ROOT" fetch origin || warn "fetch failed; working from what is already local"

    if git -C "$REPO_ROOT" pull --ff-only origin "$branch"; then
        ok "Updated to latest origin/$branch"
        return 0
    fi

    printf '\n'
    printf '%b\n' "${YELLOW}Fast-forward failed - you have local commits or changes.${NC}"
    git -C "$REPO_ROOT" status --short
    printf '\n'
    printf '%b\n' "${RED}A hard reset will PERMANENTLY DISCARD everything listed above.${NC}"

    local confirm=""
    menu_read confirm "Discard all local changes and match origin/$branch? (type 'yes' to confirm) " ||
        { info "Aborted. Repository left untouched."; return 1; }
    if [ "$confirm" = "yes" ]; then
        git -C "$REPO_ROOT" reset --hard "origin/$branch" &&
            git -C "$REPO_ROOT" clean -ffd &&
            ok "Reset to origin/$branch"
    else
        info "Aborted. Repository left untouched."
    fi
}

# Behind/ahead counts for the status column.
menu_update_status() {
    local branch behind
    branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)" ||
        { printf 'not a git repository'; return 2; }
    behind="$(git -C "$REPO_ROOT" rev-list --count "HEAD..origin/$branch" 2>/dev/null)" ||
        { printf 'no origin/%s to compare against' "$branch"; return 2; }
    if [ "$behind" = "0" ]; then
        printf 'up to date with origin/%s' "$branch"
        return 0
    fi
    printf '%s commit(s) behind origin/%s' "$behind" "$branch"
    return 1
}
