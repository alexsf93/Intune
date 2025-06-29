<#
===============================================================================================
                    REMEDIACIÓN: ELIMINAR CARPETA WINDOWS.OLD - POWERSHELL
-----------------------------------------------------------------------------------------------
Este script elimina de forma segura la carpeta **Windows.old** del sistema,  
liberando espacio tras actualizaciones o migraciones de Windows.

-----------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------
- Comprueba si existe la carpeta `C:\Windows.old`
- Si existe, elimina el directorio y todo su contenido usando permisos elevados.

-----------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------
- Ejecuta el script como **Remediation Script** en Intune, o manualmente en PowerShell:
      powershell.exe -ExecutionPolicy Bypass -File .\Remediar-BorrarWindowsOld.ps1

-----------------------------------------------------------------------------------------------
NOTAS
-----------------------------------------------------------------------------------------------
- **IMPORTANTE:** Requiere privilegios de administrador.
- El borrado es **recursivo y forzado**: todos los archivos y subdirectorios serán eliminados.
- Úsalo sólo si estás seguro de que no necesitas recuperar datos de `Windows.old`.

-----------------------------------------------------------------------------------------------
AUTOR
-----------------------------------------------------------------------------------------------
- Alejandro Suárez (@alexsf93)
===============================================================================================
#>

$windowsOld = 'C:\Windows.old'
if (Test-Path $windowsOld) {
    try {
        Remove-Item -Path $windowsOld -Recurse -Force
        Write-Host "Carpeta Windows.old eliminada correctamente."
    } catch {
        Write-Warning "No se pudo eliminar Windows.old: $($_.Exception.Message)"
        Exit 1
    }
} else {
    Write-Host "La carpeta Windows.old no existe. No es necesario remediar."
}
