#!/usr/bin/env bash
# Dotfiles setup menu for macOS.
#
# Tick everything this machine needs, confirm once, and the tasks run in a
# canonical order with their current state shown alongside. The menu engine is
# shared with linux/setup.sh; the tasks themselves live in tasks.sh.
#
# Runs under the bash 3.2 that macOS ships, so nothing here or in what it
# sources may use bash 4 features.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export SCRIPT_DIR REPO_ROOT

# Colors and the step/ok/warn/info/die helpers, shared with the installers
# rather than redeclared here.
# shellcheck source=mac/installs/common.sh
. "$SCRIPT_DIR/installs/common.sh"
# shellcheck source=lib/menu.sh
. "$REPO_ROOT/lib/menu.sh"
# shellcheck source=mac/tasks.sh
. "$SCRIPT_DIR/tasks.sh"

MENU_TITLE="Dotfiles Setup"
menu_main
