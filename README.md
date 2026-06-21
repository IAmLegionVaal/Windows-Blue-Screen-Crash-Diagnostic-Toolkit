# Windows Blue Screen Crash Diagnostic Toolkit

A PowerShell toolkit for collecting Windows crash and stability evidence and repairing selected crash-dump prerequisites.

## Diagnostic script

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Blue_Screen_Crash_Diagnostic_Toolkit.ps1
```

The diagnostic script reports recent bugchecks and restarts, minidumps, drivers and system context without changing the device.

## Repair script

Preview a dump configuration change:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Blue_Screen_Repair_Toolkit.ps1 -DumpType Automatic -EnableAutomaticPageFile -DryRun
```

Examples:

```powershell
.\Windows_Blue_Screen_Repair_Toolkit.ps1 -DumpType Automatic -EnableAutomaticPageFile
.\Windows_Blue_Screen_Repair_Toolkit.ps1 -DumpType Small
.\Windows_Blue_Screen_Repair_Toolkit.ps1 -RepairSystemFiles
.\Windows_Blue_Screen_Repair_Toolkit.ps1 -RestartWerService
.\Windows_Blue_Screen_Repair_Toolkit.ps1 -ArchiveMinidumpsOlderThanDays 30
```

## Repair behaviour

- Configures Automatic, Kernel, Small or Complete crash dumps.
- Restores standard memory-dump and minidump paths and keeps the memory dump after restart.
- Enables Windows automatic page-file management when requested.
- Runs DISM RestoreHealth followed by System File Checker.
- Starts or restarts Windows Error Reporting.
- Moves explicitly aged minidumps into the run backup directory instead of deleting them.
- Exports CrashControl registry and page-file evidence before changes.
- Captures dump, page-file, service, minidump and recent bugcheck state before and after repair.
- Supports `-DryRun`, confirmation prompts or `-Yes`, administrator checks, action logs and verification.

## Safety and exit codes

Dump-setting changes affect future crashes and some page-file changes take effect only after restart. System-file repair can take time. The tool does not delete current dumps, uninstall drivers, change boot configuration or reboot automatically.

Exit codes: `0` success, `2` invalid arguments, `3` unsupported platform, `4` elevation required, `10` cancelled, `20` action failure and `30` verification failure.

## Validation note

The repair script was committed and statically reviewed, but it was not runtime-tested on Windows or against an actual bugcheck.

## Author

Dewald Pretorius — L2 IT Support Engineer
