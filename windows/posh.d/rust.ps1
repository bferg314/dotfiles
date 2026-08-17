# Rust toolchain (rustup)
#
# The counterpart to linux/bashrc.d/rust.bashrc and mac/zshrc.d/rust.zshrc.
# The winget package writes %USERPROFILE%\.cargo\bin into the user PATH, but
# that only reaches shells started afterwards - this makes cargo callable in
# the session where rustup was just installed too.
$cargoBin = "$HOME\.cargo\bin"
if ((Test-Path -LiteralPath $cargoBin) -and ($env:Path -split ';' -notcontains $cargoBin)) {
    $env:Path = "$env:Path;$cargoBin"
}

# Common cargo commands
# Functions rather than Set-Alias values, because a PowerShell alias cannot
# carry arguments.
function Invoke-CargoBuild  { cargo build $args }
function Invoke-CargoRun    { cargo run $args }
function Invoke-CargoTest   { cargo test $args }
function Invoke-CargoCheck  { cargo check $args }
function Invoke-CargoFmt    { cargo fmt $args }
function Invoke-CargoClippy { cargo clippy $args }

Set-Alias -Name cb   -Value Invoke-CargoBuild
Set-Alias -Name cr   -Value Invoke-CargoRun
Set-Alias -Name ct   -Value Invoke-CargoTest
Set-Alias -Name ck   -Value Invoke-CargoCheck
Set-Alias -Name cfmt -Value Invoke-CargoFmt
Set-Alias -Name ccl  -Value Invoke-CargoClippy
