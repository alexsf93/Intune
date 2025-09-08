<#
===============================================================================================
     DETECCION: HAY POLITICAS QUE BLOQUEAN WINDOWS UPDATE / AUTOPATCH? (INTUNE/POWERSHELL)
-----------------------------------------------------------------------------------------------
Este script detecta si existen configuraciones de directiva en el registro que impidan
la correcta gestion de actualizaciones por parte de Windows Autopatch.

Pensado para Intune Remediations o tareas de compliance en dispositivos gestionados.

-----------------------------------------------------------------------------------------------
COMO FUNCIONA?
-----------------------------------------------------------------------------------------------
- Revisa las siguientes claves de registro:
    • HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\DoNotConnectToWindowsUpdateInternetLocations
    • HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\DisableWindowsUpdateAccess
    • HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\NoAutoUpdate
- Si alguno de estos valores existe y es distinto de 0 -> se considera no conforme.
- Devuelve Exit 1 si se detecta alguna configuracion bloqueante.
- Devuelve Exit 0 si no existen configuraciones que bloqueen Windows Autopatch.

-----------------------------------------------------------------------------------------------
AUTOR
-----------------------------------------------------------------------------------------------
- Alejandro Suarez (@alexsf93)
===============================================================================================
#>

$ErrorActionPreference = 'SilentlyContinue'

$checks = @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate';    Name = 'DoNotConnectToWindowsUpdateInternetLocations' },
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate';    Name = 'DisableWindowsUpdateAccess' },
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'NoAutoUpdate' }
)

function Get-PolicyValue {
    param([string]$Path,[string]$Name)
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
    Write-Output "Cumple: no hay politicas bloqueantes."
    Exit 0
}
