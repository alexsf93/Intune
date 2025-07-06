<#
===============================================================================================
                     DETECCIÓN: ARCHIVOS/RESIDUOS DE INSTALACIONES WINDOWS - POWERSHELL
-----------------------------------------------------------------------------------------------
Este script detecta la presencia de carpetas y archivos residuales de instalaciones o upgrades 
anteriores de Windows (como Windows.old, $WINDOWS.~BT, $WINDOWS.~WS, carpetas de migración, etc.).
Ideal para remediación desde Intune.

-----------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------
- Busca estas rutas en el disco del sistema (C:\):
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
     Exit 1  -> Si alguna existe (requiere remediación)
     Exit 0  -> Si no existe ninguna (no requiere acción)

-----------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------
- Ejecuta el script como **Detection Rule** en Intune, o en tareas de comprobación de limpieza.

-----------------------------------------------------------------------------------------------
AUTOR
-----------------------------------------------------------------------------------------------
- Alejandro Suárez (@alexsf93)
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
        Write-Output "Encontrado: $path"
        Exit 1
    }
}

Write-Output "No se detectan residuos de instalaciones previas de Windows."
Exit 0
