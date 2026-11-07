#Requires -Version 5.1
<#
.SYNOPSIS
    Preview or apply a generic laboratory provisioning plan.
.EXAMPLE
    .\Invoke-Provisioning.ps1 -ConfigPath .\examples\config.sample.json
.EXAMPLE
    .\Invoke-Provisioning.ps1 -ConfigPath .\examples\config.sample.json -Action IIS -Apply -ConfirmEnvironment LAB
.NOTES
    Never run against production infrastructure. Default behavior only previews a plan.
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'examples\config.sample.json'),
    [ValidateSet('All','Restore','Install','IIS')][string]$Action = 'All',
    [switch]$Apply,
    [string]$ConfirmEnvironment,
    [switch]$AllowReplace,
    [pscredential]$SqlCredential
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'src\ProvisioningToolkit.psm1') -Force
$results = Invoke-ToolkitPlan @PSBoundParameters
if (-not $Apply) {
    Write-Host 'PREVIEW ONLY — no changes made.' -ForegroundColor Yellow
    $results | Format-Table -AutoSize -Wrap
    Write-Host 'For an approved lab run, review docs/SAFETY.md first.' -ForegroundColor Yellow
}
