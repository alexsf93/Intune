<#
=====================================================================================================
    DETECTION SCRIPT: INSTALACIÓN DE DROPBOX
-----------------------------------------------------------------------------------------------------
Este script comprueba si la aplicación **Dropbox** está instalada en el sistema Windows. 
Está pensado para usarse en entornos gestionados (Intune, Autopilot, remediaciones, etc.) 
para validar el estado de la instalación de Dropbox de forma silenciosa y automatizable.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- Compatible con PowerShell 5.1 y 7.x.
- No requiere privilegios de administrador.
- Acceso al cmdlet `Get-AppxPackage`.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Revisa los paquetes instalados con `Get-AppxPackage` buscando "Dropbox".
- Devuelve:
  * Exit code 1 → Dropbox está instalado.
  * Exit code 0 → Dropbox no está instalado.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → Dropbox no está instalado.
- "NOK" (exit code 1) → Dropbox está instalado.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecutar con:
      powershell.exe -ExecutionPolicy Bypass -File .\Detection-Dropbox.ps1
- Revisar únicamente el código de salida para integración en Intune u otros sistemas.
- El script no genera mensajes en pantalla, es totalmente silencioso.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

# Detectar si Dropbox está instalado en el sistema
$dropbox = Get-AppxPackage *Dropbox*

if ($dropbox) {
    Exit 1  # Está instalado
} else {
    Exit 0  # No está instalado
}
