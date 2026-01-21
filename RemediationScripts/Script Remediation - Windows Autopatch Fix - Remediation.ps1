<#
.SYNOPSIS
    REMEDIATION SCRIPT: DESBLOQUEAR WINDOWS UPDATE / AUTOPATCH (INTUNE/POWERSHELL)

.DESCRIPTION
    Este script corrige configuraciones de directiva en el Registro que impiden la gestión de actualizaciones
    por parte de Windows Update / Windows Autopatch, normalizando los valores a `DWORD=0` en las claves
    objetivo.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Windows Autopatch Fix - Remediation.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
#>

$ErrorActionPreference = 'Stop'

$targets = @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'DoNotConnectToWindowsUpdateInternetLocations' },
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'DisableWindowsUpdateAccess' },
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'NoAutoUpdate' }
)

foreach ($t in $targets) {
    if (-not (Test-Path -LiteralPath $t.Path)) {
        New-Item -Path $t.Path -Force | Out-Null
    }
    try {
        New-ItemProperty -LiteralPath $t.Path -Name $t.Name -Value 0 -PropertyType DWord -Force | Out-Null
        Write-Output "Set $($t.Path)\$($t.Name) = 0"
    }
    catch {
        try {
            Remove-ItemProperty -LiteralPath $t.Path -Name $t.Name -ErrorAction Stop
            New-ItemProperty -LiteralPath $t.Path -Name $t.Name -Value 0 -PropertyType DWord -Force | Out-Null
            Write-Output "Recreated $($t.Path)\$($t.Name) = 0"
        }
        catch {
            Write-Output "ERROR setting $($t.Path)\$($t.Name): $($_.Exception.Message)"
        }
    }
}

$remaining = 0
foreach ($t in $targets) {
    try {
        $v = (Get-ItemProperty -LiteralPath $t.Path -Name $t.Name -ErrorAction Stop).$t.Name
        if ([int]$v -ne 0) { $remaining++ }
    }
    catch { }
}

if ($remaining -eq 0) {
    Write-Output "Remediación completada."
    Exit 0
}
else {
    Write-Output "Remediación incompleta: hay valores != 0."
    Exit 1
}
