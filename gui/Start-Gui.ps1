#Requires -Version 5.1
<#
.SYNOPSIS
    Read-only WinForms demonstration of a PowerShell provisioning plan.
.DESCRIPTION
    Displays the configured steps without modifying SQL Server, IIS, or Windows.
#>
[CmdletBinding()]
param(
    [string]$ConfigPath,
    [switch]$ValidateOnly
)
$ErrorActionPreference = 'Stop'
# Resolve the path after parameter binding: Windows PowerShell 5.1 may leave
# PSScriptRoot empty when evaluating param-block default expressions.
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path -Path $PSScriptRoot -ChildPath '..\examples\config.sample.json'
}
if ($env:OS -ne 'Windows_NT') { throw 'This graphical interface is Windows-only.' }
Import-Module (Join-Path $PSScriptRoot '..\src\ProvisioningToolkit.psm1') -Force

# Headless smoke-test for CI. Does not create a form or change the system.
if ($ValidateOnly) {
    $config = Read-ToolkitConfiguration -Path $ConfigPath
    Get-ToolkitPlan -Configuration $config
    return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Environment Provisioning | Portfolio Demo'
$form.Size = New-Object System.Drawing.Size(1040, 670)
$form.StartPosition = 'CenterScreen'
$form.MinimumSize = New-Object System.Drawing.Size(900, 620)
$form.BackColor = [System.Drawing.Color]::FromArgb(24, 27, 34)
$form.ForeColor = [System.Drawing.Color]::WhiteSmoke
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Environment Provisioning Toolkit'
$title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 18)
$title.ForeColor = [System.Drawing.Color]::WhiteSmoke
$title.Location = New-Object System.Drawing.Point(25, 20)
$title.AutoSize = $true
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = 'SQL Server  |  Windows Installers  |  IIS     •     Demonstracao segura (somente leitura)'
$subtitle.ForeColor = [System.Drawing.Color]::Silver
$subtitle.Location = New-Object System.Drawing.Point(27, 61)
$subtitle.AutoSize = $true
$form.Controls.Add($subtitle)

$configLabel = New-Object System.Windows.Forms.Label
$configLabel.Text = 'Arquivo de configuracao (JSON)'
$configLabel.Location = New-Object System.Drawing.Point(27, 108)
$configLabel.AutoSize = $true
$form.Controls.Add($configLabel)

$configBox = New-Object System.Windows.Forms.TextBox
$configBox.Location = New-Object System.Drawing.Point(27, 135)
$configBox.Size = New-Object System.Drawing.Size(790, 30)
$configBox.Anchor = 'Top,Left,Right'
$configBox.Text = [System.IO.Path]::GetFullPath($ConfigPath)
$configBox.BackColor = [System.Drawing.Color]::FromArgb(42, 47, 56)
$configBox.ForeColor = [System.Drawing.Color]::WhiteSmoke
$configBox.BorderStyle = 'FixedSingle'
$form.Controls.Add($configBox)

$browse = New-Object System.Windows.Forms.Button
$browse.Text = 'Procurar...'
$browse.Location = New-Object System.Drawing.Point(829, 133)
$browse.Size = New-Object System.Drawing.Size(165, 34)
$browse.Anchor = 'Top,Right'
$browse.BackColor = [System.Drawing.Color]::SteelBlue
$browse.ForeColor = [System.Drawing.Color]::White
$browse.FlatStyle = 'Flat'
$form.Controls.Add($browse)

$preview = New-Object System.Windows.Forms.Button
$preview.Text = 'Gerar plano de execucao'
$preview.Location = New-Object System.Drawing.Point(27, 185)
$preview.Size = New-Object System.Drawing.Size(250, 42)
$preview.BackColor = [System.Drawing.Color]::FromArgb(37, 119, 95)
$preview.ForeColor = [System.Drawing.Color]::White
$preview.FlatStyle = 'Flat'
$form.Controls.Add($preview)

$status = New-Object System.Windows.Forms.Label
$status.Text = 'Aguardando visualizacao do plano.'
$status.ForeColor = [System.Drawing.Color]::Silver
$status.Location = New-Object System.Drawing.Point(294, 195)
$status.Size = New-Object System.Drawing.Size(700, 28)
$status.Anchor = 'Top,Left,Right'
$form.Controls.Add($status)

$table = New-Object System.Windows.Forms.DataGridView
$table.Location = New-Object System.Drawing.Point(27, 248)
$table.Size = New-Object System.Drawing.Size(967, 320)
$table.Anchor = 'Top,Bottom,Left,Right'
$table.BackgroundColor = [System.Drawing.Color]::FromArgb(31, 35, 43)
$table.GridColor = [System.Drawing.Color]::FromArgb(70, 75, 83)
$table.ForeColor = [System.Drawing.Color]::Black
$table.ReadOnly = $true
$table.AllowUserToAddRows = $false
$table.AllowUserToDeleteRows = $false
$table.AutoSizeColumnsMode = 'Fill'
$table.RowHeadersVisible = $false
$table.SelectionMode = 'FullRowSelect'
$table.ColumnCount = 4
$table.Columns[0].Name = 'Etapa'
$table.Columns[1].Name = 'Recurso'
$table.Columns[2].Name = 'Operacao planejada'
$table.Columns[3].Name = 'Protecao'
$table.Columns[0].FillWeight = 20
$table.Columns[1].FillWeight = 24
$table.Columns[2].FillWeight = 43
$table.Columns[3].FillWeight = 42
$form.Controls.Add($table)

$footer = New-Object System.Windows.Forms.Label
$footer.Text = 'Modo demonstracao: nenhuma instalacao, restauracao ou alteracao no IIS sera realizada por esta tela.'
$footer.ForeColor = [System.Drawing.Color]::DarkOrange
$footer.Location = New-Object System.Drawing.Point(27, 588)
$footer.Size = New-Object System.Drawing.Size(970, 28)
$footer.Anchor = 'Bottom,Left,Right'
$form.Controls.Add($footer)

$browse.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = 'JSON (*.json)|*.json|Todos os arquivos (*.*)|*.*'
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $configBox.Text = $dialog.FileName }
})
$preview.Add_Click({
    try {
        $table.Rows.Clear()
        $config = Read-ToolkitConfiguration -Path $configBox.Text
        $plan = @(Get-ToolkitPlan -Configuration $config)
        foreach ($step in $plan) {
            $null = $table.Rows.Add($step.Stage, $step.Resource, $step.Operation, $step.Safety)
        }
        $status.ForeColor = [System.Drawing.Color]::LightGreen
        $status.Text = "Ambiente: $($config.environment)  |  $($plan.Count) etapas  |  Nenhuma alteracao realizada"
    }
    catch {
        $status.ForeColor = [System.Drawing.Color]::Tomato
        $status.Text = 'Erro ao ler a configuracao.'
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Falha na pre-visualizacao', 'OK', 'Error') | Out-Null
    }
})
$preview.PerformClick()
[void]$form.ShowDialog()
$form.Dispose()
