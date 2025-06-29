<#
===============================================================================================
                   DETECTOR DE INSTALACIÓN DE DROPBOX - POWERSHELL
-----------------------------------------------------------------------------------------------
Este script comprueba si la aplicación **Dropbox** está instalada en el sistema Windows.
Puede ser utilizado en entornos gestionados (Intune, autopilot, remediaciones, etc.)
para validar el estado de la instalación de Dropbox de forma silenciosa y automatizable.

-----------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------
- El script revisa los paquetes instalados con Get-AppxPackage buscando "Dropbox".
- Código de salida:
      Exit 1  → Dropbox instalado
      Exit 0  → Dropbox NO instalado

-----------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------
- Ejecuta el script con:
      powershell.exe -ExecutionPolicy Bypass -File .\Script Remediation - Desinstalar Dropbox - Detection.ps1

- El script no genera mensajes en pantalla. Revisa el código de salida
  para integración en Intune, procesos de remediación o automatizaciones.

-----------------------------------------------------------------------------------------------
NOTAS
-----------------------------------------------------------------------------------------------
- Compatible con PowerShell 5.1/7.x.
- No requiere privilegios de administrador.
- No elimina ni instala nada: solo comprueba.
- Puedes integrarlo como script de detección en Intune.

-----------------------------------------------------------------------------------------------
AUTOR
-----------------------------------------------------------------------------------------------
- Alejandro Suárez (@alexsf93)
===============================================================================================
#>
# Detectar si Dropbox está instalado en el sistema
$dropbox = Get-AppxPackage *Dropbox*

if ($dropbox) {
    Exit 1  # Esta instalado
} else {
    Exit 0  # No esta instalado
}