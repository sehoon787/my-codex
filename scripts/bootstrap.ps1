Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoUrl = if ($env:MY_CODEX_REPO_URL) { $env:MY_CODEX_REPO_URL } else { 'https://github.com/sehoon787/my-codex.git' }
$tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("my-codex-" + [guid]::NewGuid().ToString())
$homeRoot = if ($env:HOME) { $env:HOME } else { $HOME }
$metadataFile = Join-Path $homeRoot '.codex\my-codex-install.env'

function Require-Command {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Read-MetadataValue {
    param([Parameter(Mandatory = $true)][string]$Key)

    if (-not (Test-Path $metadataFile)) {
        return $null
    }

    $line = Get-Content $metadataFile | Where-Object { $_ -like "$Key=*" } | Select-Object -First 1
    if (-not $line) {
        return $null
    }

    return ($line -replace "^{0}=" -f [regex]::Escape($Key))
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

    $installScript = Join-Path $tmpRoot 'scripts/install.ps1'
    if (-not (Test-Path $installScript)) {
        throw "scripts/install.ps1 not found in cloned repository: $tmpRoot"
    }

    $currentCommit = Read-MetadataValue -Key 'MY_CODEX_INSTALL_COMMIT'
    $currentRef = Read-MetadataValue -Key 'MY_CODEX_INSTALL_REF'
    $newCommit = (& git -C $tmpRoot rev-parse HEAD 2>$null)
    $newRef = (& git -C $tmpRoot describe --tags --always 2>$null)

    if ($currentCommit -and $currentCommit -eq $newCommit) {
        Write-Host ("==> my-codex already at {0}; reinstalling managed assets" -f $(if ($newRef) { $newRef } else { $newCommit }))
    }
    elseif ($currentCommit) {
        $fromRef = if ($currentRef) { $currentRef } else { $currentCommit }
        $toRef = if ($newRef) { $newRef } else { $newCommit }
        Write-Host ("==> Updating my-codex from {0} to {1}" -f $fromRef, $toRef)
    }
    else {
        Write-Host ("==> Installing my-codex {0}" -f $(if ($newRef) { $newRef } else { $newCommit }))
    }

    Write-Host "==> Running installer"
    & $installScript
}
finally {
    if (Test-Path $tmpRoot) {
        Remove-Item -Path $tmpRoot -Recurse -Force
    }
}
