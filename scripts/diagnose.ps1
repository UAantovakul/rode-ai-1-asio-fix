<#
    diagnose.ps1 — read-only check for the RODE AI-1 ASIO path-mismatch bug.
    No admin rights needed. Prints each InProcServer32 path and whether it resolves.
#>
$asio = 'HKLM:\SOFTWARE\ASIO\RODE AI-1 ASIO Driver'
if (-not (Test-Path $asio)) {
    Write-Host "RODE AI-1 ASIO driver is NOT registered. Install the official driver first." -ForegroundColor Yellow
    return
}
$clsid = (Get-ItemProperty $asio).CLSID
Write-Host "RODE AI-1 ASIO CLSID: $clsid`n"

$bad = $false
foreach ($h in @(
        "HKLM:\SOFTWARE\Classes\CLSID\$clsid\InProcServer32",
        "HKLM:\SOFTWARE\Classes\WOW6432Node\CLSID\$clsid\InProcServer32")) {
    if (-not (Test-Path $h)) { continue }
    $p  = (Get-ItemProperty -LiteralPath $h).'(default)'
    $ok = Test-Path -LiteralPath $p
    if (-not $ok) { $bad = $true }
    Write-Host $h
    Write-Host ("  -> {0}" -f $p) -ForegroundColor ($(if ($ok) { 'Green' } else { 'Red' }))
    Write-Host ("     resolves: {0}" -f $ok) -ForegroundColor ($(if ($ok) { 'Green' } else { 'Red' }))
}

Write-Host ""
if ($bad) {
    Write-Host "DIAGNOSIS: broken path detected — run scripts\fix-registry.ps1" -ForegroundColor Red
} else {
    Write-Host "DIAGNOSIS: registry paths are OK." -ForegroundColor Green
}
