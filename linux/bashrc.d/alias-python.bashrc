# Python version aliases
alias py='python3'
alias python='python3'
alias pip='pip3'

# Virtual environment aliases
alias cvenv='python3 -m venv .venv'
alias avenv='source ./.venv/bin/activate'
alias dvenv='deactivate'

# Common Python commands
alias pr='python3 manage.py runserver'                    # Django runserver
alias pt='python3 -m pytest'                             # Run pytest
alias pip-upgrade='pip list --outdated --format=freeze | grep -v "^\-e" | cut -d = -f 1 | xargs -n1 pip install -U'
alias pipf='pip freeze > requirements.txt'               # Generate requirements.txt
alias pipi='pip install -r requirements.txt'             # Install from requirements.txt

# IPython/Jupyter aliases
alias ipy='ipython'
alias jn='jupyter notebook'
alias jl='jupyter lab'

# Code quality and formatting
alias lint='pylint'
alias black='python3 -m black'
alias isort='python3 -m isort'