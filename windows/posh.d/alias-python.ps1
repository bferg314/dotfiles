# Python version aliases
Set-Alias -Name py -Value python
Set-Alias -Name pip -Value pip

# Virtual environment functions
function New-VirtualEnv { python -m venv .venv }
Set-Alias -Name cvenv -Value New-VirtualEnv

function Activate-Venv {
    .\.venv\Scripts\Activate
}
Set-Alias -Name avenv -Value Activate-Venv

function Deactivate-Venv { deactivate }
Set-Alias -Name dvenv -Value Deactivate-Venv

# Common Python commands
function Start-DjangoServer { python manage.py runserver }
Set-Alias -Name pr -Value Start-DjangoServer

function Start-PyTest { python -m pytest $args }
Set-Alias -Name pt -Value Start-PyTest

function Update-PipPackages { 
    pip list --outdated --format=freeze | 
    Where-Object { $_ -notmatch '^\-e' } | 
    ForEach-Object { $_.split('==')[0] } | 
    ForEach-Object { pip install -U $_ }
}
Set-Alias -Name pip-upgrade -Value Update-PipPackages

function Export-Requirements { pip freeze > requirements.txt }
Set-Alias -Name pipf -Value Export-Requirements

function Install-Requirements { pip install -r requirements.txt }
Set-Alias -Name pipi -Value Install-Requirements

# IPython/Jupyter aliases
Set-Alias -Name ipy -Value ipython
Set-Alias -Name jn -Value "jupyter notebook"
Set-Alias -Name jl -Value "jupyter lab"

# Code quality and formatting
Set-Alias -Name lint -Value pylint
function Invoke-Black { python -m black $args }
Set-Alias -Name black -Value Invoke-Black

function Invoke-ISort { python -m isort $args }
Set-Alias -Name isort -Value Invoke-ISort
