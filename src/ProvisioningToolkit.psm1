# Generic public portfolio implementation. No company-specific resources or credentials.
Set-StrictMode -Version Latest

function Assert-ToolkitIdentifier {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Value)
    if ($Value -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$') {
        throw "Invalid resource identifier: '$Value'. Use letters, digits, _, . or -."
    }
    return $Value
}

function ConvertTo-ToolkitSqlIdentifier {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Value)
    $null = Assert-ToolkitIdentifier -Value $Value
    return '[' + $Value.Replace(']', ']]') + ']'
}

function ConvertTo-ToolkitSqlLiteral {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Value)
    return "N'" + $Value.Replace("'", "''") + "'"
}

function Read-ToolkitConfiguration {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Configuration not found: $Path"
    }
    $config = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $config -or [string]::IsNullOrWhiteSpace([string]$config.environment)) {
        throw 'The JSON configuration requires a non-empty environment property.'
    }
    $null = Assert-ToolkitIdentifier -Value ([string]$config.environment)
    if ([string]$config.environment -ne 'LAB') {
        throw 'This public sample only accepts environment = LAB.'
    }
    if ($null -eq $config.sql -or [string]::IsNullOrWhiteSpace([string]$config.sql.instance)) {
        throw 'The configuration requires sql.instance.'
    }
    if ([string]$config.sql.authentication -notin @('Windows', 'Sql')) {
        throw 'sql.authentication must be Windows or Sql.'
    }
    foreach ($db in @($config.sql.databases)) {
        $null = Assert-ToolkitIdentifier -Value ([string]$db.name)
        if ([string]::IsNullOrWhiteSpace([string]$db.backupPattern) -or
            -not ([string]$db.backupPattern).EndsWith('.bak', [StringComparison]::OrdinalIgnoreCase)) {
            throw "Database $($db.name) must have a .bak backupPattern."
        }
        if ([string]$db.backupPattern -match '[\\/]') {
            throw 'backupPattern may only contain a filename pattern, not a path.'
        }
    }
    foreach ($pkg in @($config.installers)) {
        $null = Assert-ToolkitIdentifier -Value ([string]$pkg.name)
        if ([string]$pkg.type -notin @('msi', 'exe')) { throw "Unsupported package type: $($pkg.type)" }
        if ([string]::IsNullOrWhiteSpace([string]$pkg.path)) { throw "Package path missing: $($pkg.name)" }
    }
    if ($null -ne $config.iis -and $null -ne $config.iis.site) {
        $site = $config.iis.site
        $null = Assert-ToolkitIdentifier -Value ([string]$site.name)
        $null = Assert-ToolkitIdentifier -Value ([string]$site.applicationPool)
        $port = [int]$site.port
        if ($port -lt 1024 -or $port -gt 65535) { throw 'For this lab sample, the HTTP port must be 1024-65535.' }
        foreach ($app in @($config.iis.applications)) {
            $null = Assert-ToolkitIdentifier -Value ([string]$app.name)
            $null = Assert-ToolkitIdentifier -Value ([string]$app.applicationPool)
        }
    }
    return $config
}

function Get-ToolkitPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Configuration,
        [ValidateSet('All', 'Restore', 'Install', 'IIS')][string]$Action = 'All'
    )
    $steps = [System.Collections.Generic.List[object]]::new()
    if ($Action -in @('All', 'Restore')) {
        foreach ($db in @($Configuration.sql.databases)) {
            $steps.Add([pscustomobject]@{
                Stage = 'SQL Restore'; Resource = [string]$db.name;
                Operation = "Restore latest matching $($db.backupPattern)";
                Safety = 'Existing database requires explicit -AllowReplace'
            })
        }
    }
    if ($Action -in @('All', 'Install')) {
        foreach ($pkg in @($Configuration.installers)) {
            $steps.Add([pscustomobject]@{
                Stage = 'Installer'; Resource = [string]$pkg.name;
                Operation = "Run configured $($pkg.type) installer";
                Safety = 'Requires -Apply; package must exist'
            })
        }
    }
    if ($Action -in @('All', 'IIS') -and $null -ne $Configuration.iis.site) {
        $steps.Add([pscustomobject]@{
            Stage = 'IIS'; Resource = [string]$Configuration.iis.site.name;
            Operation = "Create site on port $($Configuration.iis.site.port) and application pools";
            Safety = 'Never removes or overwrites an existing site'
        })
        foreach ($app in @($Configuration.iis.applications)) {
            $steps.Add([pscustomobject]@{
                Stage = 'IIS App'; Resource = [string]$app.name;
                Operation = "Create application in $($Configuration.iis.site.name)";
                Safety = 'Create only; no overwrite'
            })
        }
    }
    return $steps.ToArray()
}

function Get-ToolkitRestoreStatement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DatabaseName,
        [Parameter(Mandatory)][string]$BackupPath,
        [Parameter(Mandatory)][string]$DataDirectory,
        [Parameter(Mandatory)][object[]]$FileList,
        [switch]$AllowReplace
    )
    $db = ConvertTo-ToolkitSqlIdentifier -Value $DatabaseName
    $safeBackup = ConvertTo-ToolkitSqlLiteral -Value $BackupPath
    $moves = [System.Collections.Generic.List[string]]::new()
    $dataIndex = 0
    $logIndex = 0
    foreach ($file in $FileList) {
        $logical = ConvertTo-ToolkitSqlLiteral -Value ([string]$file.LogicalName)
        $type = [string]$file.Type
        if ($type -eq 'D') {
            $extension = if ($dataIndex -eq 0) { 'mdf' } else { 'ndf' }
            $suffix = if ($dataIndex -eq 0) { '' } else { "_$dataIndex" }
            $dataIndex++
        }
        elseif ($type -eq 'L') {
            $extension = 'ldf'
            $suffix = if ($logIndex -eq 0) { '_log' } else { "_log$logIndex" }
            $logIndex++
        }
        else { continue }
        $target = Join-Path -Path $DataDirectory -ChildPath "$DatabaseName$suffix.$extension"
        $safeTarget = ConvertTo-ToolkitSqlLiteral -Value $target
        $moves.Add("    MOVE $logical TO $safeTarget")
    }
    if ($dataIndex -eq 0 -or $logIndex -eq 0) {
        throw 'Expected at least one data file and one log file in RESTORE FILELISTONLY.'
    }
    $clauses = @($moves.ToArray()) + @('    RECOVERY', '    STATS = 10')
    if ($AllowReplace) { $clauses = @('    REPLACE') + $clauses }
    $withClause = $clauses -join ",`r`n"
    return "RESTORE DATABASE $db`r`nFROM DISK = $safeBackup`r`nWITH`r`n$withClause;"
}

function Invoke-ToolkitSql {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Configuration,
        [Parameter(Mandatory)][string]$Query,
        [pscredential]$SqlCredential,
        [int]$Timeout = 0
    )
    Import-Module SqlServer -ErrorAction Stop
    $params = @{
        ServerInstance = [string]$Configuration.sql.instance
        Database = 'master'
        Query = $Query
        QueryTimeout = $Timeout
        ErrorAction = 'Stop'
    }
    if ([string]$Configuration.sql.authentication -eq 'Sql') {
        if ($null -eq $SqlCredential) {
            throw 'SQL authentication requires -SqlCredential (Get-Credential).'
        }
        $params.Username = $SqlCredential.UserName
        $params.Password = $SqlCredential.GetNetworkCredential().Password
    }
    $cmd = Get-Command Invoke-Sqlcmd -ErrorAction Stop
    if ($Configuration.sql.trustServerCertificate -eq $true -and
        $cmd.Parameters.ContainsKey('TrustServerCertificate')) {
        $params.TrustServerCertificate = $true
    }
    return Invoke-Sqlcmd @params
}

function Invoke-ToolkitRestore {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Configuration, [pscredential]$SqlCredential, [switch]$AllowReplace)
    $sql = $Configuration.sql
    if (-not (Test-Path -LiteralPath ([string]$sql.backupDirectory) -PathType Container)) {
        throw 'Backup directory not found on this workstation.'
    }
    foreach ($db in @($sql.databases)) {
        $dbName = [string]$db.name
        $backup = Get-ChildItem -LiteralPath ([string]$sql.backupDirectory) -File -Filter ([string]$db.backupPattern) |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($null -eq $backup) { throw "No .bak file matches the pattern for $dbName." }
        # SQL Server accesses the backup itself. UNC permissions must belong to its service account.
        $dbLiteral = ConvertTo-ToolkitSqlLiteral -Value $dbName
        $found = @(Invoke-ToolkitSql -Configuration $Configuration -SqlCredential $SqlCredential -Query "SELECT name FROM sys.databases WHERE name = $dbLiteral;")
        if ($found.Count -gt 0 -and -not $AllowReplace) {
            throw "Database '$dbName' already exists. Refusing to replace without -AllowReplace."
        }
        $fileSql = 'RESTORE FILELISTONLY FROM DISK = ' + (ConvertTo-ToolkitSqlLiteral -Value $backup.FullName) + ';'
        $fileList = @(Invoke-ToolkitSql -Configuration $Configuration -SqlCredential $SqlCredential -Query $fileSql)
        $statement = Get-ToolkitRestoreStatement -DatabaseName $dbName -BackupPath $backup.FullName `
            -DataDirectory ([string]$sql.dataDirectory) -FileList $fileList -AllowReplace:$AllowReplace
        Write-Host "[$dbName] Restoring backup $($backup.Name)..." -ForegroundColor Cyan
        $dbIdentifier = ConvertTo-ToolkitSqlIdentifier -Value $dbName
        try {
            if ($found.Count -gt 0) {
                $null = Invoke-ToolkitSql -Configuration $Configuration -SqlCredential $SqlCredential `
                    -Query "ALTER DATABASE $dbIdentifier SET SINGLE_USER WITH ROLLBACK IMMEDIATE;"
            }
            $null = Invoke-ToolkitSql -Configuration $Configuration -SqlCredential $SqlCredential -Query $statement -Timeout 0
            Write-Host "[$dbName] Restore completed." -ForegroundColor Green
        }
        finally {
            if ($found.Count -gt 0) {
                try {
                    $null = Invoke-ToolkitSql -Configuration $Configuration -SqlCredential $SqlCredential `
                        -Query "ALTER DATABASE $dbIdentifier SET MULTI_USER;"
                }
                catch { Write-Warning "Could not return $dbName to MULTI_USER: $($_.Exception.Message)" }
            }
        }
    }
}

function Invoke-ToolkitInstall {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Configuration)
    foreach ($pkg in @($Configuration.installers)) {
        $path = [string]$pkg.path
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Installer not found: $path"
        }
        $type = [string]$pkg.type
        if ($type -eq 'msi' -and [System.IO.Path]::GetExtension($path) -ine '.msi') {
            throw "MSI package has a mismatched extension: $path"
        }
        if ($type -eq 'exe' -and [System.IO.Path]::GetExtension($path) -ine '.exe') {
            throw "EXE package has a mismatched extension: $path"
        }
        $arguments = [string]$pkg.arguments
        Write-Host "Installing $($pkg.name)..." -ForegroundColor Cyan
        if ($type -eq 'msi') {
            $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$path`" $arguments" -PassThru -Wait
        }
        else {
            $process = Start-Process -FilePath $path -ArgumentList $arguments -PassThru -Wait
        }
        if ($process.ExitCode -notin @(0, 3010)) {
            throw "Installer $($pkg.name) failed with exit code $($process.ExitCode)."
        }
        if ($process.ExitCode -eq 3010) { Write-Warning "Installer $($pkg.name) requests a reboot." }
    }
}

function Invoke-ToolkitIis {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Configuration)
    if ($env:OS -ne 'Windows_NT') { throw 'IIS configuration requires Windows.' }
    Import-Module WebAdministration -ErrorAction Stop
    $site = $Configuration.iis.site
    if ($null -eq $site) { return }
    $siteName = [string]$site.name
    if (Test-Path -LiteralPath "IIS:\Sites\$siteName") {
        throw "IIS site $siteName already exists. This sample never replaces it."
    }
    $port = [int]$site.port
    $portInUse = @(Get-WebBinding -Protocol 'http' -ErrorAction SilentlyContinue | Where-Object {
        ($_.bindingInformation -split ':')[1] -eq [string]$port
    })
    if ($portInUse.Count -gt 0) {
        throw "IIS HTTP port $port already has a binding. Refusing to create a conflicting site."
    }
    $pools = @([string]$site.applicationPool) + @($Configuration.iis.applications | ForEach-Object { [string]$_.applicationPool }) |
        Select-Object -Unique
    foreach ($pool in $pools) {
        if (Test-Path -LiteralPath "IIS:\AppPools\$pool") {
            throw "Application pool $pool already exists. Refusing to modify it."
        }
    }
    foreach ($pool in $pools) {
        $null = New-WebAppPool -Name $pool
    }
    $null = New-Item -ItemType Directory -Path ([string]$site.physicalPath) -Force
    $null = New-Website -Name $siteName -PhysicalPath ([string]$site.physicalPath) -Port ([int]$site.port)
    Set-ItemProperty -Path "IIS:\Sites\$siteName" -Name applicationPool -Value ([string]$site.applicationPool)
    foreach ($app in @($Configuration.iis.applications)) {
        $null = New-Item -ItemType Directory -Path ([string]$app.physicalPath) -Force
        $null = New-WebApplication -Site $siteName -Name ([string]$app.name) `
            -PhysicalPath ([string]$app.physicalPath) -ApplicationPool ([string]$app.applicationPool)
    }
    Write-Host "IIS site '$siteName' was created." -ForegroundColor Green
}

function Invoke-ToolkitPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ConfigPath,
        [ValidateSet('All','Restore','Install','IIS')][string]$Action = 'All',
        [switch]$Apply,
        [string]$ConfirmEnvironment,
        [switch]$AllowReplace,
        [pscredential]$SqlCredential
    )
    $config = Read-ToolkitConfiguration -Path $ConfigPath
    $plan = @(Get-ToolkitPlan -Configuration $config -Action $Action)
    if (-not $Apply) { return $plan }
    if ([string]::IsNullOrWhiteSpace($ConfirmEnvironment) -or
        $ConfirmEnvironment -cne [string]$config.environment) {
        throw 'Apply blocked. Provide -ConfirmEnvironment LAB to confirm the lab target.'
    }
    if ($Action -in @('All','Restore')) {
        Invoke-ToolkitRestore -Configuration $config -SqlCredential $SqlCredential -AllowReplace:$AllowReplace
    }
    if ($Action -in @('All','Install')) {
        Invoke-ToolkitInstall -Configuration $config
    }
    if ($Action -in @('All','IIS')) {
        Invoke-ToolkitIis -Configuration $config
    }
}

Export-ModuleMember -Function Assert-ToolkitIdentifier, ConvertTo-ToolkitSqlIdentifier, `
    ConvertTo-ToolkitSqlLiteral, Read-ToolkitConfiguration, Get-ToolkitPlan, `
    Get-ToolkitRestoreStatement, Invoke-ToolkitPlan
