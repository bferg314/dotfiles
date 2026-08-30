#!/usr/bin/env bash
# Dotfiles setup menu for Linux.
#
# Tick everything this machine needs, confirm once, and the tasks run in a
# canonical order with their current state shown alongside. The menu engine is
# shared with mac/setup.sh; the tasks themselves live in tasks.sh.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export SCRIPT_DIR REPO_ROOT

# Colors and the step/ok/warn/info/die helpers, shared with the installers
# rather than redeclared here.
# shellcheck source=linux/installs/common.sh
. "$SCRIPT_DIR/installs/common.sh"
# shellcheck source=lib/menu.sh
. "$REPO_ROOT/lib/menu.sh"

detect_distro_quiet || true

# shellcheck source=linux/tasks.sh
. "$SCRIPT_DIR/tasks.sh"

MENU_TITLE="Dotfiles Setup"
menu_main
