<#
=====================================================================================================
    REMEDIATION SCRIPT: DESINSTALAR DROPBOX
-----------------------------------------------------------------------------------------------------
Este script elimina la aplicación **Dropbox** instalada como AppxPackage en sistemas Windows. 
Está pensado para escenarios de remediación, despliegue con Intune o automatizaciones de limpieza 
en dispositivos gestionados.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- Compatible con PowerShell 5.1 y 7.x.
- Recomendado ejecutarlo con privilegios de administrador o SYSTEM.
- Acceso al cmdlet `Remove-AppxPackage`.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Genera un script temporal en "C:\UninstallDropbox.ps1" que ejecuta la desinstalación de Dropbox.
- Lanza el script temporal con ExecutionPolicy Bypass para evitar bloqueos de ejecución.
- Una vez finalizado, elimina el script temporal para no dejar rastro en el sistema.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0 implícito) → Dropbox desinstalado correctamente o no presente.
- Mensajes en salida estándar → Solo si ocurre algún error durante la desinstalación.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecutar con:
      powershell.exe -ExecutionPolicy Bypass -File .\Remediation-Dropbox.ps1
- Integrar como Remediation Script en Intune/MEM para desinstalar Dropbox de forma automática.
- No requiere interacción manual, funciona de manera silenciosa.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

# Define la ruta del script temporal
$scriptPath = "C:\UninstallDropbox.ps1"

# Crear el contenido del script
$scriptContent = @"
Get-AppxPackage *Dropbox* | Remove-AppxPackage
"@

# Escribir el script en disco
Set-Content -Path $scriptPath -Value $scriptContent

# Ejecutar el script con ExecutionPolicy Bypass
powershell -ExecutionPolicy Bypass -File $scriptPath

# Eliminar el script temporal tras la ejecución
Remove-Item -Path $scriptPath -Force
