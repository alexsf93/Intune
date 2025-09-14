<#
=====================================================================================================
    REMEDIATION SCRIPT: LIMPIEZA DE ARCHIVOS/RESIDUOS DE WINDOWS
-----------------------------------------------------------------------------------------------------
Este script elimina carpetas y archivos residuales de instalaciones o actualizaciones antiguas 
de Windows (por ejemplo: Windows.old, $WINDOWS.~BT, $WINDOWS.~WS, carpetas de migración, etc.) 
del disco del sistema. Está pensado para su uso en Intune Remediations o procesos automatizados 
de limpieza en dispositivos gestionados.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- Compatible con PowerShell 5.1 y 7.x.
- Debe ejecutarse como SYSTEM o con privilegios de administrador.
- Acceso a las utilidades `takeown` e `icacls` para forzar permisos si es necesario.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Revisa las siguientes rutas en C:\:
    * C:\Windows.old
    * C:\$WINDOWS.~BT
    * C:\$WINDOWS.~WS
    * C:\$INPLACE.~TR
    * C:\$GetCurrent
    * C:\ESD
    * C:\$SysReset
    * C:\Windows10Upgrade
    * C:\Recovery
- Si alguna existe:
  * Toma propiedad y ajusta permisos para garantizar acceso.
  * Elimina la carpeta/archivo con `Remove-Item`.
  * Registra en salida estándar el resultado de cada intento.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → Todas las carpetas residuales eliminadas o inexistentes.
- Mensajes en salida estándar → Confirma cada carpeta eliminada, inexistente o no eliminada.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecutar como Remediation Script en Intune.
- Requiere permisos de SYSTEM o administrador local.
- Revisar la salida para verificar qué carpetas fueron eliminadas.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
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
