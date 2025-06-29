<#
===============================================================================================
                         DETECCIÓN: LENOVO NOW INSTALADO - POWERSHELL
-----------------------------------------------------------------------------------------------
Este script detecta si la aplicación **Lenovo Now** está instalada en el sistema mediante PowerShell.
Pensado para escenarios de detección previa a remediaciones, automatizaciones, o despliegues con Intune.

-----------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------
- Busca el paquete "Lenovo Now*" usando Get-Package (compatible con nombre parcial).
- Si está instalado, devuelve el código de salida 1 (detectado).
- Si no está instalado, devuelve el código de salida 0 (no detectado).

-----------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------
- Ejecuta el script con:
      powershell.exe -ExecutionPolicy Bypass -File .\Script Remediation - Desinstalar Lenovo Now - Detection.ps1

- Ideal para políticas de **Detection Rule** en Intune o scripts de control de inventario.

-----------------------------------------------------------------------------------------------
NOTAS
-----------------------------------------------------------------------------------------------
- Compatible con PowerShell 5.1/7.x.
- No requiere privilegios de administrador para detectar la instalación.
- Silencioso: no genera salida visual, solo código de retorno.
- Puede personalizarse para detectar otras aplicaciones modificando el filtro de nombre.

-----------------------------------------------------------------------------------------------
AUTOR
-----------------------------------------------------------------------------------------------
- Alejandro Suárez (@alexsf93)
===============================================================================================
#>
# Detectar si Lenovo Now está instalado en el sistema
$lenovoNOW = Get-Package "Lenovo Now*"

if ($lenovoNOW) {
    Exit 1  # Esta instalado
} else {
    Exit 0  # No esta instalado
}