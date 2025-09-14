<#
=====================================================================================================
    DETECTION SCRIPT: ARCHIVOS/RESIDUOS DE INSTALACIONES DE WINDOWS
-----------------------------------------------------------------------------------------------------
Este script detecta la presencia de carpetas y archivos residuales de instalaciones o actualizaciones 
anteriores de Windows (por ejemplo: Windows.old, $WINDOWS.~BT, $WINDOWS.~WS, carpetas de migración, etc.). 
Está pensado para usarse como parte de procesos de remediación en Intune o comprobaciones de limpieza.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- Compatible con PowerShell 5.1 y 7.x.
- No requiere privilegios de administrador para la detección.
- Debe ejecutarse en el disco del sistema (C:\).

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Revisa la existencia de las siguientes rutas en C:\:
    * C:\Windows.old
    * C:\$WINDOWS.~BT
    * C:\$WINDOWS.~WS
    * C:\$INPLACE.~TR
    * C:\$GetCurrent
    * C:\ESD
    * C:\$SysReset
    * C:\Windows10Upgrade
    * C:\Recovery
- Devuelve:
  * Exit code 1 → Alguna de estas carpetas existe (requiere remediación).
  * Exit code 0 → Ninguna de estas carpetas existe (no requiere acción).

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → No se han encontrado residuos de instalaciones previas.
- "NOK" (exit code 1) → Se detectaron archivos/carpetas residuales de instalaciones previas.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecutar como Detection Rule en Intune.
- También puede emplearse en auditorías de limpieza de sistemas.
- Revisar salida estándar y exit code para integración con procesos de remediación.

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
        Write-Output "Encontrado: $path"
        Exit 1
    }
}

Write-Output "No se detectan residuos de instalaciones previas de Windows."
Exit 0
