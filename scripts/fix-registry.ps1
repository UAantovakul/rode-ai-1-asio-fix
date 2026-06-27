<#
    fix-registry.ps1 — repair the RODE AI-1 ASIO InProcServer32 path mismatch.
    Self-elevates (UAC). Backs up the affected CLSID keys to %TEMP% before changing
    anything, locates the real DLLs dynamically, and rewrites both InProcServer32
    default values. Only the (default) value is changed; ThreadingModel is preserved.
#>
#Requires -Version 5.1

# --- self-elevate ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Start-Process -FilePath 'powershell.exe' -Verb RunAs `
        -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`""
    return
}

$ErrorActionPreference = 'Stop'
try {
    $asio = 'HKLM:\SOFTWARE\ASIO\RODE AI-1 ASIO Driver'
    if (-not (Test-Path $asio)) { throw 'RODE AI-1 ASIO is not installed (no registry entry).' }
    $clsid = (Get-ItemProperty $asio).CLSID
    Write-Host "CLSID: $clsid"

    # locate the real install folder (any "*DE Microphones\AI-1-ASIO" that actually exists)
    $pf86 = ${env:ProgramFiles(x86)}
    $dir = Get-ChildItem -LiteralPath $pf86 -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'DE Microphones$' } |
        ForEach-Object { Join-Path $_.FullName 'AI-1-ASIO' } |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $dir) { throw "AI-1-ASIO folder not found under '$pf86'. Reinstall the driver." }

    $x64 = Join-Path $dir 'RODE-AI-1-ASIO-x64.dll'
    $x86 = Join-Path $dir 'RODE-AI-1-ASIO.dll'
    if (-not (Test-Path -LiteralPath $x64)) { throw "Missing file: $x64" }
    if (-not (Test-Path -LiteralPath $x86)) { throw "Missing file: $x86" }

    $k64 = "HKLM:\SOFTWARE\Classes\CLSID\$clsid\InProcServer32"
    $k32 = "HKLM:\SOFTWARE\Classes\WOW6432Node\CLSID\$clsid\InProcServer32"

    # backup
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bdir  = Join-Path $env:TEMP "rode-ai1-asio-backup-$stamp"
    New-Item -ItemType Directory -Path $bdir -Force | Out-Null
    & reg.exe export "HKLM\SOFTWARE\Classes\CLSID\$clsid" (Join-Path $bdir 'clsid_64.reg') /y | Out-Null
    & reg.exe export "HKLM\SOFTWARE\Classes\WOW6432Node\CLSID\$clsid" (Join-Path $bdir 'clsid_32.reg') /y | Out-Null
    Write-Host "Backup saved to: $bdir" -ForegroundColor Cyan

    # fix
    Set-ItemProperty -LiteralPath $k64 -Name '(default)' -Value $x64
    Set-ItemProperty -LiteralPath $k32 -Name '(default)' -Value $x86

    Write-Host "`nFixed:" -ForegroundColor Green
    Write-Host ("  64-bit -> {0}  (resolves: {1})" -f $x64, (Test-Path -LiteralPath $x64))
    Write-Host ("  32-bit -> {0}  (resolves: {1})" -f $x86, (Test-Path -LiteralPath $x86))
    Write-Host "`nDone. Fully restart your DAW and select 'RODE AI-1 ASIO' again." -ForegroundColor Green
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Read-Host "`nPress Enter to close"
}
