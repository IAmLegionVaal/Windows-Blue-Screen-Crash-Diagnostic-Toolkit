# Windows Blue Screen Crash Diagnostic Toolkit

A read-only PowerShell toolkit for collecting Windows crash and stability evidence.

## Features

- Recent bugcheck and restart event summary
- Minidump folder inventory
- System and driver context
- CSV, JSON, TXT, and HTML reports

## How to run

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Blue_Screen_Crash_Diagnostic_Toolkit.ps1
```

## Safety

Diagnostic-only. It does not alter dump settings or system configuration.
