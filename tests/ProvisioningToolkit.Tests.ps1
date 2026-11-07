BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\src\ProvisioningToolkit.psm1') -Force
    $script:samplePath = Join-Path $PSScriptRoot '..\examples\config.sample.json'
}

Describe 'Configuration and read-only plans' {
    It 'loads the sanitized sample configuration' {
        $config = Read-ToolkitConfiguration -Path $script:samplePath
        $config.environment | Should -Be 'LAB'
        $config.sql.authentication | Should -Be 'Windows'
    }

    It 'produces a plan containing all three operational areas' {
        $config = Read-ToolkitConfiguration -Path $script:samplePath
        $plan = @(Get-ToolkitPlan -Configuration $config)
        $plan.Stage | Should -Contain 'SQL Restore'
        $plan.Stage | Should -Contain 'Installer'
        $plan.Stage | Should -Contain 'IIS'
    }

    It 'filters the plan to IIS only' {
        $config = Read-ToolkitConfiguration -Path $script:samplePath
        $plan = @(Get-ToolkitPlan -Configuration $config -Action IIS)
        @($plan | Where-Object { $_.Stage -eq 'SQL Restore' }).Count | Should -Be 0
        @($plan | Where-Object { $_.Stage -eq 'IIS' }).Count | Should -Be 1
    }

    It 'rejects resource names with unsafe characters' {
        { Assert-ToolkitIdentifier -Value 'db]; DROP DATABASE master;--' } | Should -Throw
    }

    It 'rejects non-laboratory targets' {
        $content = Get-Content -LiteralPath $script:samplePath -Raw
        $path = Join-Path $TestDrive 'production.json'
        [System.IO.File]::WriteAllText($path, ($content -replace '"LAB"','"PRODUCTION"'))
        { Read-ToolkitConfiguration -Path $path } | Should -Throw
    }

    It 'blocks applying changes without explicit environment confirmation' {
        { Invoke-ToolkitPlan -ConfigPath $script:samplePath -Action IIS -Apply } | Should -Throw
    }
}

Describe 'SQL restore statement generation' {
    It 'generates safe file moves for multiple data files' {
        $files = @(
            [pscustomobject]@{ LogicalName = 'Demo_Data'; Type = 'D' },
            [pscustomobject]@{ LogicalName = 'Demo_Extra'; Type = 'D' },
            [pscustomobject]@{ LogicalName = 'Demo_Log'; Type = 'L' }
        )
        $query = Get-ToolkitRestoreStatement -DatabaseName 'DemoCatalog' `
            -BackupPath "C:\Backups\demo's.bak" -DataDirectory 'C:\Lab\Data' -FileList $files
        $query | Should -Match 'RESTORE DATABASE \[DemoCatalog\]'
        $query | Should -Match 'DemoCatalog_1.ndf'
        $query | Should -Match "demo''s.bak"
        $query | Should -Not -Match 'REPLACE'
    }

    It 'only adds REPLACE when explicitly requested' {
        $files = @(
            [pscustomobject]@{ LogicalName = 'Db'; Type = 'D' },
            [pscustomobject]@{ LogicalName = 'DbLog'; Type = 'L' }
        )
        $query = Get-ToolkitRestoreStatement -DatabaseName 'DemoCatalog' `
            -BackupPath 'C:\Backups\demo.bak' -DataDirectory 'C:\Lab\Data' -FileList $files -AllowReplace
        $query | Should -Match 'REPLACE'
    }

    It 'rejects backup metadata without a log file' {
        $files = @([pscustomobject]@{ LogicalName = 'Db'; Type = 'D' })
        { Get-ToolkitRestoreStatement -DatabaseName 'Db' -BackupPath 'C:\b.bak' -DataDirectory 'C:\Data' -FileList $files } | Should -Throw
    }
}
