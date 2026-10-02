# shellcheck shell=bash
# Python workflow, shared by bash and zsh.
#
# uv manages projects, virtualenvs and Python itself; ruff lints and formats.
# Both are installed by mise (shared/mise/config.toml), and mise also provides
# the `python` on PATH, so there is no python3/pip3 juggling to do here. The
# aliases are kept short and keep the names the old pip-based ones had, so the
# habits carry over -- see the "Python" section of the toolchain guide.

alias py='python'

# Virtual environments. uv creates .venv in the current directory; `uv run`
# and `uv sync` use it automatically, so activating is only needed for an
# interactive session in it.
alias cvenv='uv venv'
alias avenv='. .venv/bin/activate'
alias dvenv='deactivate'

# Projects (pyproject.toml + uv.lock)
alias uvi='uv init'          # new project in the current directory
alias uva='uv add'           # add a dependency:      uva requests
alias uvad='uv add --dev'    # add a dev dependency:  uvad pytest
alias uvs='uv sync'          # install exactly what the lockfile says
alias uvr='uv run'           # run in the project env: uvr python app.py
# (uvx needs no alias: `uvx httpie` runs a tool without installing it)

# requirements.txt projects that have not moved to pyproject.toml yet
alias pipi='uv pip install -r requirements.txt'
alias pipf='uv pip freeze > requirements.txt'

# Common commands
alias pr='uv run python manage.py runserver'   # Django runserver
alias pt='uv run pytest'                       # pytest in the project env

# Code quality: ruff replaces pylint, black and isort
alias lint='ruff check'
alias lintf='ruff check --fix'
alias fmt='ruff format'

# IPython/Jupyter, layered on top of the current project's environment with
# --with, so they can import the project's packages without being added to
# its dependencies. Outside a project they run in a throwaway environment.
jn()  { uv run --with jupyter jupyter notebook "$@"; }
jl()  { uv run --with jupyter jupyter lab "$@"; }
ipy() { uv run --with ipython ipython "$@"; }
