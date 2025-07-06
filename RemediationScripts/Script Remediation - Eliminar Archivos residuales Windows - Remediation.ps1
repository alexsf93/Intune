<#
===============================================================================================
                     REMEDIACIÓN: LIMPIEZA DE ARCHIVOS/RESIDUOS WINDOWS - POWERSHELL
-----------------------------------------------------------------------------------------------
Este script elimina carpetas y archivos residuales de instalaciones o upgrades antiguos de Windows 
(Windows.old, $WINDOWS.~BT, $WINDOWS.~WS, carpetas de migración, etc.) del disco del sistema.

Compatible con Intune Remediations (debe ejecutarse como SYSTEM).
-----------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
===============================================================================================
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
        } catch {
            Write-Output "No se pudo eliminar $path : $($_.Exception.Message)"
        }
    } else {
        Write-Output "No existe: $path"
    }
}

Write-Output "Remediación de residuos de instalaciones Windows completada."
Exit 0
