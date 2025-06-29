<#
===============================================================================================
                         DETECCIÓN: CARPETA WINDOWS.OLD PRESENTE - POWERSHELL
-----------------------------------------------------------------------------------------------
Este script detecta si existe la carpeta **Windows.old** en el disco del sistema.  
Pensado para tareas de Remediation, auditoría o despliegue desde Intune.

-----------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------
- Comprueba si existe la ruta: `C:\Windows.old`
- Devuelve:
     Exit 1  -> Si la carpeta existe (debe remediarse)
     Exit 0  -> Si la carpeta NO existe (no requiere acción)

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

if (Test-Path 'C:\Windows.old') {
    Exit 1   # Windows.old está presente
} else {
    Exit 0   # Windows.old no está presente
}
