Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoUrl = if ($env:MY_CODEX_REPO_URL) { $env:MY_CODEX_REPO_URL } else { 'https://github.com/sehoon787/my-codex.git' }
$tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("my-codex-" + [guid]::NewGuid().ToString())

function Require-Command {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

try {
    Write-Host "==> my-codex bootstrap"
    Require-Command -Name git
    Require-Command -Name node
    Require-Command -Name npm

    Write-Host "==> Cloning repository"
    git clone --depth 1 $repoUrl $tmpRoot
    if ($LASTEXITCODE -ne 0) {
        throw "git clone failed with exit code $LASTEXITCODE"
    }

    $installScript = Join-Path $tmpRoot 'install.ps1'
    if (-not (Test-Path $installScript)) {
        throw "install.ps1 not found in cloned repository: $tmpRoot"
    }

    Write-Host "==> Running installer"
    & $installScript
}
finally {
    if (Test-Path $tmpRoot) {
        Remove-Item -Path $tmpRoot -Recurse -Force
    }
}
