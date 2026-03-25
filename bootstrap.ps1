Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $repoRoot 'scripts/bootstrap.ps1'
& $script @args
exit $LASTEXITCODE
