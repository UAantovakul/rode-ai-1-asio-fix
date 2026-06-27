<#
    make-junction.ps1 — permanent immunity against driver reinstalls.
    Creates a directory junction so the ASCII path the installer/registry use
    ("RODE Microphones") resolves to the real Unicode folder ("RØDE Microphones").
    Self-elevates (UAC).
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
    $pf86 = ${env:ProgramFiles(x86)}
    $link = Join-Path $pf86 'RODE Microphones'   # ASCII name (what registry/installer use)

    # real folder = the "*DE Microphones" that is NOT the plain-ASCII one
    $real = Get-ChildItem -LiteralPath $pf86 -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'DE Microphones$' -and $_.FullName -ne $link } |
        Select-Object -First 1
    if (-not $real) { throw "Real 'RODE Microphones' folder (with special character) not found." }

    $existing = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
    if ($existing) {
        if ($existing.LinkType -eq 'Junction') {
            Write-Host "Junction already exists -> $($existing.Target)" -ForegroundColor Yellow
        } else {
            throw "A real folder already exists at '$link' — refusing to replace it."
        }
    } else {
        New-Item -ItemType Junction -Path $link -Target $real.FullName | Out-Null
        Write-Host "Created junction:" -ForegroundColor Green
        Write-Host "  $link  ->  $($real.FullName)"
    }

    $probe = Join-Path $link 'AI-1-ASIO\RODE-AI-1-ASIO-x64.dll'
    Write-Host ("ASCII path resolves now: {0}" -f (Test-Path -LiteralPath $probe)) -ForegroundColor Green
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Read-Host "`nPress Enter to close"
}
