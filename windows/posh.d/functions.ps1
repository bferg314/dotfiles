# Directory management
function mkcd($path) {
    New-Item -Path $path -ItemType Directory -ErrorAction SilentlyContinue
    Set-Location -Path $path
}

# Backup file
function bak($file) {
    Copy-Item $file "$file.bak"
}

# Extract archives
function extract($file) {
    if (!(Test-Path $file)) {
        Write-Error "'$file' is not a valid file"
        return
    }

    $extension = [System.IO.Path]::GetExtension($file)
    switch ($extension) {
        ".zip" { Expand-Archive $file -DestinationPath . }
        ".7z"  { & 7z x $file }
        ".rar" { & rar x $file }
        default { Write-Error "Unsupported archive type: $extension" }
    }
}

# Find files
function ff($pattern) {
    Get-ChildItem -Recurse -Filter "*$pattern*" | Select-Object FullName
}

# Quick directory stack commands
function d { Get-Location -Stack }
function pd { Pop-Location }
