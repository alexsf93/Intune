<#
=====================================================================================================
    REMEDIATION SCRIPT: DESBLOQUEAR WINDOWS UPDATE / AUTOPATCH (INTUNE/POWERSHELL)
-----------------------------------------------------------------------------------------------------
Este script corrige configuraciones de directiva en el Registro que impiden la gestión de actualizaciones
por parte de Windows Update / Windows Autopatch, normalizando los valores a `DWORD=0` en las claves
objetivo.

Claves objetivo:
    • HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\DoNotConnectToWindowsUpdateInternetLocations
    • HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\DisableWindowsUpdateAccess
    • HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\NoAutoUpdate

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- PowerShell 5.1 o 7.x.
- Permisos de administrador/SYSTEM.
- Acceso de escritura al Registro bajo `HKLM:\SOFTWARE\Policies\Microsoft\Windows\`.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Crea las subclaves si faltan.
- Establece cada valor indicado a `0` (tipo `DWORD`), recreándolo si es necesario.
- Verifica al final que todos los valores queden en `0`.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → Remediación completada: todos los valores están en `0`.
- "NOK" (exit code 1) → Remediación incompleta: persisten valores distintos de `0`.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecutar como Remediation Script en Intune u otros sistemas de gestión.
- Revisar la salida estándar para confirmar las claves ajustadas.
- Emparejar con una Detection Rule que compruebe estas mismas claves.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suarez (@alexsf93)
=====================================================================================================
#>

$ErrorActionPreference = 'Stop'

$targets = @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate';    Name = 'DoNotConnectToWindowsUpdateInternetLocations' },
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate';    Name = 'DisableWindowsUpdateAccess' },
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'NoAutoUpdate' }
)

foreach ($t in $targets) {
    if (-not (Test-Path -LiteralPath $t.Path)) {
        New-Item -Path $t.Path -Force | Out-Null
    }
    try {
        New-ItemProperty -LiteralPath $t.Path -Name $t.Name -Value 0 -PropertyType DWord -Force | Out-Null
        Write-Output "Set $($t.Path)\$($t.Name) = 0"
    } catch {
        try {
            Remove-ItemProperty -LiteralPath $t.Path -Name $t.Name -ErrorAction Stop
            New-ItemProperty -LiteralPath $t.Path -Name $t.Name -Value 0 -PropertyType DWord -Force | Out-Null
            Write-Output "Recreated $($t.Path)\$($t.Name) = 0"
        } catch {
            Write-Output "ERROR setting $($t.Path)\$($t.Name): $($_.Exception.Message)"
        }
    }
}

$remaining = 0
foreach ($t in $targets) {
    try {
        $v = (Get-ItemProperty -LiteralPath $t.Path -Name $t.Name -ErrorAction Stop).$t.Name
        if ([int]$v -ne 0) { $remaining++ }
    } catch { }
}

if ($remaining -eq 0) {
    Write-Output "Remediación completada."
    Exit 0
} else {
    Write-Output "Remediación incompleta: hay valores != 0."
    Exit 1
}
