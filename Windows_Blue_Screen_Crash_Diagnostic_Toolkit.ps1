#requires -Version 5.1
<#
.SYNOPSIS
    Windows Blue Screen Crash Diagnostic Toolkit.
.DESCRIPTION
    Read-only crash and stability evidence collector for Windows support.
#>
[CmdletBinding()]
param([int]$Hours=168,[string]$OutputPath)
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
if([string]::IsNullOrWhiteSpace($OutputPath)){$OutputPath=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Crash_Diagnostic_Reports'}
New-Item -Path $OutputPath -ItemType Directory -Force|Out-Null
$start=(Get-Date).AddHours(-1*$Hours)
$events=Get-WinEvent -FilterHashtable @{LogName='System';StartTime=$start;Id=41,1001,6008} -ErrorAction SilentlyContinue|Select-Object TimeCreated,Id,ProviderName,LevelDisplayName,Message
$dumps=Get-ChildItem "$env:SystemRoot\Minidump" -Filter '*.dmp' -ErrorAction SilentlyContinue|Select-Object Name,Length,CreationTime,LastWriteTime,FullName
$os=Get-CimInstance Win32_OperatingSystem|Select-Object Caption,Version,BuildNumber,LastBootUpTime
$drivers=Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue|Where-Object{$_.DeviceName}|Select-Object DeviceName,DriverVersion,DriverDate,Manufacturer,IsSigned
$events|Export-Csv (Join-Path $OutputPath "crash_events_$stamp.csv") -NoTypeInformation -Encoding UTF8
$dumps|Export-Csv (Join-Path $OutputPath "minidumps_$stamp.csv") -NoTypeInformation -Encoding UTF8
$drivers|Export-Csv (Join-Path $OutputPath "drivers_$stamp.csv") -NoTypeInformation -Encoding UTF8
$summary=[PSCustomObject]@{Computer=$env:COMPUTERNAME;OS=$os.Caption;Build=$os.BuildNumber;CrashEventCount=@($events).Count;DumpCount=@($dumps).Count;Generated=Get-Date}
$summary|ConvertTo-Json|Set-Content (Join-Path $OutputPath "summary_$stamp.json") -Encoding UTF8
$html="<h1>Crash Diagnostic - $env:COMPUTERNAME</h1><p>Generated $(Get-Date)</p><h2>Summary</h2>$(@($summary)|ConvertTo-Html -Fragment)<h2>Crash Events</h2>$($events|ConvertTo-Html -Fragment)<h2>Dump Files</h2>$($dumps|ConvertTo-Html -Fragment)"
$html|ConvertTo-Html -Title 'Crash Diagnostic'|Set-Content (Join-Path $OutputPath "crash_diagnostic_$stamp.html") -Encoding UTF8
$summary|Format-List
Write-Host "Reports saved to: $OutputPath" -ForegroundColor Green
