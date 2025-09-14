<#
=====================================================================================================
    DETECTION SCRIPT: ¿POLÍTICAS QUE BLOQUEAN WINDOWS UPDATE / AUTOPATCH?
-----------------------------------------------------------------------------------------------------
Este script detecta si existen configuraciones de directiva en el Registro que impidan la correcta
gestión de actualizaciones por parte de Windows Update / Windows Autopatch en el dispositivo.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- PowerShell 5.1 o 7.x.
- Permisos para leer el Registro bajo HKLM.
- Dispositivo Windows con claves de directiva estándar.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Revisa los valores de estas rutas del Registro:
    • HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\DoNotConnectToWindowsUpdateInternetLocations
    • HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\DisableWindowsUpdateAccess
    • HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\NoAutoUpdate
- Si cualquiera de estos valores existe y es distinto de 0 → se considera NO conforme.
- Devuelve:
  * Exit code 1 → Se detecta alguna configuración bloqueante.
  * Exit code 0 → No existen configuraciones bloqueantes.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → No hay políticas que bloqueen Windows Update / Autopatch.
- "NOK" (exit code 1) → Se han encontrado valores de política bloqueantes (se listan en la salida).

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Usar como Detection Rule en Intune u otros sistemas de compliance.
- Interpretar el exit code para decidir si aplicar un script de remediación (eliminar/ajustar claves).
- Revisar la salida estándar para conocer qué valores exactos producen la no conformidad.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
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
    Write-Output "Cumple: no hay políticas bloqueantes."
    Exit 0
}
