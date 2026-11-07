# Simple extra safeguard; it does not replace a manual security/IP review.
[CmdletBinding()]
param([string]$Root = (Join-Path $PSScriptRoot '..'))
$ErrorActionPreference = 'Stop'
$files = @(Get-ChildItem -Path $Root -Recurse -File | Where-Object {
    $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.Extension -in @('.ps1','.psm1','.json') -and
    $_.FullName -ne $PSCommandPath
})
$patterns = @(
    'BEGIN (RSA |OPENSSH )?PRIVATE KEY',
    'AKIA[0-9A-Z]{16}',
    '(?i)password\s*[:=]\s*["'']\S{8,}',
    '(?i)senha\s*[:=]\s*["'']\S{8,}'
)
$matches = @()
foreach ($file in $files) {
    $source = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($pattern in $patterns) {
        if ($source -match $pattern) { $matches += "$($file.FullName): potential secret" }
    }
}
if ($matches.Count) { $matches | ForEach-Object { Write-Warning $_ }; throw 'Review flagged files before publishing.' }
Write-Host "Basic secret scan passed ($($files.Count) files). Manual review remains necessary." -ForegroundColor Green
