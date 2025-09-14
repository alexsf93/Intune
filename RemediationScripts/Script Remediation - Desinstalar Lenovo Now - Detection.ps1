<#
=====================================================================================================
    DETECTION SCRIPT: INSTALACIÓN DE LENOVO NOW
-----------------------------------------------------------------------------------------------------
Este script detecta si la aplicación **Lenovo Now** está instalada en el sistema Windows. 
Está pensado para usarse en escenarios de detección previa a remediaciones, despliegues con Intune 
o procesos de inventario automatizados.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- Compatible con PowerShell 5.1 y 7.x.
- No requiere privilegios de administrador para la detección.
- Acceso al cmdlet `Get-Package`.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Busca el paquete "Lenovo Now*" mediante `Get-Package` (acepta coincidencias parciales).
- Devuelve:
  * Exit code 1 → Lenovo Now está instalado.
  * Exit code 0 → Lenovo Now no está instalado.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → Lenovo Now no está instalado.
- "NOK" (exit code 1) → Lenovo Now está instalado.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecutar con:
      powershell.exe -ExecutionPolicy Bypass -File .\Detection-LenovoNow.ps1
- Usar como Detection Rule en Intune o en scripts de control de inventario.
- Revisar únicamente el código de salida (no genera salida visual).

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

# Detectar si Lenovo Now está instalado en el sistema
$lenovoNOW = Get-Package "Lenovo Now*" -ErrorAction SilentlyContinue

if ($lenovoNOW) {
    Exit 1  # Está instalado
} else {
    Exit 0  # No está instalado
}
