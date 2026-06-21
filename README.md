# Windows Blue Screen Crash Diagnostic Toolkit

A PowerShell toolkit for collecting Windows crash and stability evidence and repairing selected crash-dump prerequisites.

## Scripts

- `Windows_Blue_Screen_Crash_Diagnostic_Toolkit.ps1` — read-only bugcheck, restart, minidump, driver, and system reporting.
- `Windows_Blue_Screen_Repair_Toolkit.ps1` — guarded crash-dump, page-file, system-file, service, and minidump archival actions.

## Repair actions

The repair script supports:

- `-DumpType Automatic|Kernel|Small|Complete` to configure future crash dumps and standard dump paths;
- `-EnableAutomaticPageFile` to enable Windows-managed page-file sizing;
- `-RepairSystemFiles` to run DISM RestoreHealth followed by System File Checker;
- `-RestartWerService` to set Windows Error Reporting to Manual when disabled and then start or restart it;
- `-ArchiveMinidumpsOlderThanDays <n>` to move explicitly aged minidumps into the run backup rather than delete them.

It does not uninstall drivers, edit boot configuration, delete active dumps, deliberately trigger a bugcheck, or reboot the device. Some dump and page-file changes may require a restart before they fully affect future crashes.

## Examples

Preview dump and page-file changes:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Blue_Screen_Repair_Toolkit.ps1 `
  -DumpType Automatic -EnableAutomaticPageFile -DryRun
```

Apply selected recovery actions:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Blue_Screen_Repair_Toolkit.ps1 `
  -DumpType Kernel -EnableAutomaticPageFile `
  -RepairSystemFiles -RestartWerService `
  -ArchiveMinidumpsOlderThanDays 30 -Yes
```

Omit `-Yes` to require typing `YES`. Actual changes require an elevated PowerShell session.

## Evidence, backup, and verification

Each run creates a timestamped directory under `%ProgramData%\BlueScreenRepair` unless `-OutputPath` is supplied. It contains:

- `before.json` and `after.json` with crash-control, page-file, WER service, minidump, and recent bugcheck state;
- `repair.log` with planned actions, results, and verification failures;
- for non-dry runs, `backup\CrashControl.reg` and `backup\pagefile-settings.xml`;
- archived dump files under `backup\minidumps` when the archival action is selected.

Verification checks the requested dump type, automatic page-file setting, WER service state, and whether eligible old minidumps remain. DISM and SFC are validated from their process exit codes. `-DryRun` logs planned actions without changing the device, exporting configuration backups, moving dumps, or performing post-change verification.

## Exit codes

| Code | Meaning |
|---:|---|
| 0 | Completed successfully, including a successful dry run |
| 2 | Invalid arguments |
| 3 | Unsupported platform |
| 4 | Elevation required |
| 10 | User cancelled |
| 20 | One or more repair actions or required backups failed |
| 30 | Post-repair verification failed |

## Safety

System-file repair can be lengthy and resource-intensive. Review storage capacity before selecting Complete or Kernel dumps, preserve collected evidence needed for investigations, and schedule disruptive work in an approved maintenance window.

## Validation status

The scripts were source-reviewed during this update. They were not runtime-tested on Windows or against an actual bugcheck.

## Author

Dewald Pretorius — L2 IT Support Engineer
