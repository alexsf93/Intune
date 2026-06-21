<#
.SYNOPSIS
    DETECTION SCRIPT: ¿POLÍTICAS QUE BLOQUEAN WINDOWS UPDATE / AUTOPATCH?

.DESCRIPTION
    Este script detecta si existen configuraciones de directiva en el Registro que impidan la correcta
    gestión de actualizaciones por parte de Windows Update / Windows Autopatch en el dispositivo.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Windows Autopatch Fix - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
    Context: System
#>

$ErrorActionPreference = 'SilentlyContinue'

$checks = @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'DoNotConnectToWindowsUpdateInternetLocations' },
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'DisableWindowsUpdateAccess' },
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'NoAutoUpdate' }
)

function Get-PolicyValue {
    param([string]$Path, [string]$Name)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try { (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop).$Name }
    catch { return $null }
}

$nonCompliant = @()

foreach ($c in $checks) {
    $val = Get-PolicyValue -Path $c.Path -Name $c.Name
    if ($null -ne $val) {
        try { $num = [int]$val } catch { $num = 1 }
        if ($num -ne 0) {
            $nonCompliant += [pscustomobject]@{ Path = $c.Path; Name = $c.Name; Value = $val }
        }
    }
}

if ($nonCompliant.Count -gt 0) {
    Write-Output "Configuraciones no conformes detectadas:"
    $nonCompliant | ForEach-Object { Write-Output (" - {0}\{1} = {2}" -f $_.Path, $_.Name, $_.Value) }
    Exit 1
}
else {
    Write-Output "Cumple: no hay políticas bloqueantes."
    Exit 0
}
