# Python workflow -- the counterpart to shared/shell/python.sh.
#
# uv manages projects, virtualenvs and Python itself; ruff lints and formats.
# Both come from mise (shared/mise/config.toml), which also provides the
# `python` on PATH through its shims (see tools.ps1). Functions rather than
# Set-Alias values wherever arguments are involved: a PowerShell alias cannot
# carry any.

# Virtual environments. uv creates .venv in the current directory; `uv run`
# and `uv sync` use it automatically, so activating is only needed for an
# interactive session in it.
function New-VirtualEnv { uv venv @args }
Set-Alias -Name cvenv -Value New-VirtualEnv

function Enable-Venv { & .\.venv\Scripts\Activate.ps1 }
Set-Alias -Name avenv -Value Enable-Venv

function Disable-Venv { deactivate }
Set-Alias -Name dvenv -Value Disable-Venv

# Projects (pyproject.toml + uv.lock)
function uvi  { uv init @args }          # new project in the current directory
function uva  { uv add @args }           # add a dependency:      uva requests
function uvad { uv add --dev @args }     # add a dev dependency:  uvad pytest
function uvs  { uv sync @args }          # install exactly what the lockfile says
function uvr  { uv run @args }           # run in the project env: uvr python app.py

# requirements.txt projects that have not moved to pyproject.toml yet
function pipi { uv pip install -r requirements.txt @args }
function pipf { uv pip freeze | Set-Content -Path requirements.txt -Encoding utf8 }

# Common commands
function Start-DjangoServer { uv run python manage.py runserver @args }
Set-Alias -Name pr -Value Start-DjangoServer

function Start-PyTest { uv run pytest @args }
Set-Alias -Name pt -Value Start-PyTest

# Code quality: ruff replaces pylint, black and isort
function lint  { ruff check @args }
function lintf { ruff check --fix @args }
function fmt   { ruff format @args }

# IPython/Jupyter, layered on top of the current project's environment with
# --with, so they can import the project's packages without being added to
# its dependencies. Outside a project they run in a throwaway environment.
function jn  { uv run --with jupyter jupyter notebook @args }
function jl  { uv run --with jupyter jupyter lab @args }
function ipy { uv run --with ipython ipython @args }
