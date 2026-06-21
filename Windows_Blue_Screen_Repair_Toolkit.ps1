[CmdletBinding()]
param(
    [ValidateSet('Automatic','Kernel','Small','Complete')]
    [string]$DumpType,
    [switch]$EnableAutomaticPageFile,
    [switch]$RepairSystemFiles,
    [switch]$RestartWerService,
    [Nullable[int]]$ArchiveMinidumpsOlderThanDays,
    [switch]$DryRun,
    [switch]$Yes,
    [string]$OutputPath = (Join-Path $env:ProgramData 'BlueScreenRepair')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Failures = 0
$script:VerificationFailures = 0
$script:Actions = 0

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if ($env:OS -ne 'Windows_NT') { Write-Error 'This tool requires Windows.'; exit 3 }
if (-not ($DumpType -or $EnableAutomaticPageFile -or $RepairSystemFiles -or $RestartWerService -or $null -ne $ArchiveMinidumpsOlderThanDays)) { Write-Error 'Choose at least one repair action.'; exit 2 }
if ($null -ne $ArchiveMinidumpsOlderThanDays -and $ArchiveMinidumpsOlderThanDays -lt 0) { Write-Error 'Archive age must be zero or greater.'; exit 2 }
if (-not $DryRun -and -not (Test-Administrator)) { Write-Error 'Run from an elevated PowerShell session.'; exit 4 }

$crashControlPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl'
$minidumpPath = Join-Path $env:SystemRoot 'Minidump'
$runPath = Join-Path $OutputPath (Get-Date -Format 'yyyyMMdd_HHmmss')
$backupPath = Join-Path $runPath 'backup'
$dumpArchivePath = Join-Path $backupPath 'minidumps'
New-Item -ItemType Directory -Path $dumpArchivePath -Force | Out-Null
$logPath = Join-Path $runPath 'repair.log'
$beforePath = Join-Path $runPath 'before.json'
$afterPath = Join-Path $runPath 'after.json'

function Write-Log([string]$Message) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message" | Tee-Object -FilePath $logPath -Append }
function Invoke-RepairAction([string]$Description,[scriptblock]$Script) {
    $script:Actions++
    Write-Log "ACTION: $Description"
    if ($DryRun) { Write-Log "DRY-RUN: $Description"; return }
    try {
        $result = & $Script 2>&1
        if ($null -ne $result) { $result | Out-String | Add-Content $logPath }
        Write-Log "SUCCESS: $Description"
    } catch {
        $script:Failures++
        Write-Log "FAILED: $Description - $($_.Exception.Message)"
    }
}
function Get-RepairState {
    $crash = Get-ItemProperty $crashControlPath
    $computer = Get-CimInstance Win32_ComputerSystem
    [pscustomobject]@{
        Collected = Get-Date
        CrashControl = [pscustomobject]@{
            CrashDumpEnabled = $crash.CrashDumpEnabled
            DumpFile = $crash.DumpFile
            MinidumpDir = $crash.MinidumpDir
            AlwaysKeepMemoryDump = $crash.AlwaysKeepMemoryDump
        }
        AutomaticManagedPagefile = $computer.AutomaticManagedPagefile
        PageFiles = @(Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue | Select-Object Name,InitialSize,MaximumSize)
        WerService = Get-Service WerSvc -ErrorAction SilentlyContinue | Select-Object Name,Status,StartType
        Minidumps = @(Get-ChildItem $minidumpPath -Filter '*.dmp' -ErrorAction SilentlyContinue | Select-Object Name,Length,CreationTime,LastWriteTime)
        RecentBugChecks = @(Get-WinEvent -FilterHashtable @{LogName='System';Id=1001;StartTime=(Get-Date).AddDays(-30)} -ErrorAction SilentlyContinue | Select-Object -First 20 TimeCreated,Id,ProviderName,Message)
    }
}

Get-RepairState | ConvertTo-Json -Depth 8 | Set-Content $beforePath -Encoding UTF8
& reg.exe export 'HKLM\SYSTEM\CurrentControlSet\Control\CrashControl' (Join-Path $backupPath 'CrashControl.reg') /y | Out-Null
Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue | Export-Clixml (Join-Path $backupPath 'pagefile-settings.xml')

if (-not $DryRun -and -not $Yes) {
    if ((Read-Host 'Apply the selected crash-diagnostics repairs? Type YES') -cne 'YES') { Write-Log 'Repair cancelled.'; exit 10 }
}

if ($DumpType) {
    $dumpValues = @{ Automatic=7; Kernel=2; Small=3; Complete=1 }
    Invoke-RepairAction "Configuring $DumpType crash dumps" {
        New-ItemProperty -Path $crashControlPath -Name CrashDumpEnabled -PropertyType DWord -Value $dumpValues[$DumpType] -Force | Out-Null
        New-ItemProperty -Path $crashControlPath -Name DumpFile -PropertyType ExpandString -Value '%SystemRoot%\MEMORY.DMP' -Force | Out-Null
        New-ItemProperty -Path $crashControlPath -Name MinidumpDir -PropertyType ExpandString -Value '%SystemRoot%\Minidump' -Force | Out-Null
        New-ItemProperty -Path $crashControlPath -Name AlwaysKeepMemoryDump -PropertyType DWord -Value 1 -Force | Out-Null
    }
}
if ($EnableAutomaticPageFile) {
    Invoke-RepairAction 'Enabling automatic page-file management' { Get-CimInstance Win32_ComputerSystem | Set-CimInstance -Property @{AutomaticManagedPagefile=$true} | Out-Null }
}
if ($RepairSystemFiles) {
    Invoke-RepairAction 'Running DISM RestoreHealth' {
        $process = Start-Process dism.exe -ArgumentList '/Online','/Cleanup-Image','/RestoreHealth' -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -ne 0) { throw "DISM exited with code $($process.ExitCode)." }
    }
    Invoke-RepairAction 'Running System File Checker' {
        $process = Start-Process sfc.exe -ArgumentList '/scannow' -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -notin 0,1) { throw "SFC exited with code $($process.ExitCode)." }
    }
}
if ($RestartWerService) {
    Invoke-RepairAction 'Starting or restarting Windows Error Reporting service' {
        $service = Get-Service WerSvc -ErrorAction Stop
        if ($service.Status -eq 'Running') { Restart-Service WerSvc -Force } else { Start-Service WerSvc }
    }
}
if ($null -ne $ArchiveMinidumpsOlderThanDays) {
    Invoke-RepairAction "Archiving minidumps older than $ArchiveMinidumpsOlderThanDays day(s)" {
        if (-not (Test-Path $minidumpPath)) { return }
        $cutoff = (Get-Date).AddDays(-$ArchiveMinidumpsOlderThanDays.Value)
        $files = @(Get-ChildItem $minidumpPath -Filter '*.dmp' -File -ErrorAction SilentlyContinue | Where-Object LastWriteTime -lt $cutoff)
        foreach ($file in $files) { Move-Item -LiteralPath $file.FullName -Destination $dumpArchivePath -Force }
        Write-Log "Archived minidumps: $($files.Count)"
    }
}

if (-not $DryRun) { Start-Sleep -Seconds 2 }
Get-RepairState | ConvertTo-Json -Depth 8 | Set-Content $afterPath -Encoding UTF8
if ($DumpType) {
    $expected = @{ Automatic=7; Kernel=2; Small=3; Complete=1 }[$DumpType]
    if ((Get-ItemProperty $crashControlPath).CrashDumpEnabled -ne $expected) { $script:VerificationFailures++; Write-Log 'VERIFY FAILED: crash dump type was not applied.' }
}
if ($EnableAutomaticPageFile -and -not (Get-CimInstance Win32_ComputerSystem).AutomaticManagedPagefile) { $script:VerificationFailures++; Write-Log 'VERIFY FAILED: automatic page-file management is not enabled.' }
if ($RestartWerService -and (Get-Service WerSvc).Status -ne 'Running') { $script:VerificationFailures++; Write-Log 'VERIFY FAILED: WerSvc is not running.' }
if ($null -ne $ArchiveMinidumpsOlderThanDays -and (Test-Path $minidumpPath)) {
    $cutoff = (Get-Date).AddDays(-$ArchiveMinidumpsOlderThanDays.Value)
    if (@(Get-ChildItem $minidumpPath -Filter '*.dmp' -File -ErrorAction SilentlyContinue | Where-Object LastWriteTime -lt $cutoff).Count -gt 0) { $script:VerificationFailures++; Write-Log 'VERIFY FAILED: eligible minidumps remain in the active directory.' }
}

if ($script:Failures -gt 0) { exit 20 }
if ($script:VerificationFailures -gt 0) { exit 30 }
Write-Log "Repair completed. Actions: $script:Actions"
exit 0
