<#
.SYNOPSIS
    REMEDIATION SCRIPT: LIMPIEZA DE ARCHIVOS/RESIDUOS DE WINDOWS

.DESCRIPTION
    Este script elimina carpetas y archivos residuales de instalaciones o actualizaciones antiguas 
    de Windows (por ejemplo: Windows.old, $WINDOWS.~BT, $WINDOWS.~WS, carpetas de migración, etc.) 
    del disco del sistema.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Eliminar Archivos residuales Windows - Remediation.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
#>

$paths = @(
    "C:\Windows.old",
    "C:\$WINDOWS.~BT",
    "C:\$WINDOWS.~WS",
    "C:\$INPLACE.~TR",
    "C:\$GetCurrent",
    "C:\ESD",
    "C:\$SysReset",
    "C:\Windows10Upgrade",
    "C:\Recovery"
)

foreach ($path in $paths) {
    if (Test-Path $path) {
        try {
            # Tomar propiedad por si hay bloqueo de permisos
            takeown /F $path /A /R /D Y | Out-Null
            icacls $path /grant Administrators:F /T /C | Out-Null

            # Intentar borrar
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop

            Write-Output "Eliminado correctamente: $path"
        }
        catch {
            Write-Output "No se pudo eliminar $path : $($_.Exception.Message)"
        }
    }
    else {
        Write-Output "No existe: $path"
    }
}

Write-Output "Remediación de residuos de instalaciones Windows completada."
Exit 0
