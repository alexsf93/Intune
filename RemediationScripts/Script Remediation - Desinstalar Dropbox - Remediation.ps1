<#
===============================================================================================
                       REMEDIACIÓN: DESINSTALAR DROPBOX - POWERSHELL
-----------------------------------------------------------------------------------------------
Este script elimina la aplicación **Dropbox** instalada como AppxPackage en sistemas Windows.
Pensado para escenarios de remediación, despliegue con Intune, o automatizaciones de limpieza.

-----------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------
- Genera un script temporal en "C:\UninstallDropbox.ps1" que ejecuta la desinstalación.
- Ejecuta el script con privilegios de ejecución elevados (Bypass).
- Al finalizar, elimina el script temporal para no dejar rastro en el sistema.

-----------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------
- Ejecuta el script con:
      powershell.exe -ExecutionPolicy Bypass -File .\Script Remediation - Desinstalar Dropbox - Remediation.ps1

- No se requiere interacción manual.
- Ideal para su uso en políticas de remediación o como acción automatizada en Intune/MEM.

-----------------------------------------------------------------------------------------------
NOTAS
-----------------------------------------------------------------------------------------------
- Compatible con PowerShell 5.1/7.x.
- Se recomienda ejecutar con privilegios de administrador para máxima compatibilidad.
- No afecta a archivos personales en la carpeta de Dropbox, solo elimina la aplicación.
- No genera salida visual, es silencioso por diseño.

-----------------------------------------------------------------------------------------------
AUTOR
-----------------------------------------------------------------------------------------------
- Alejandro Suárez (@alexsf93)
===============================================================================================
#>

# Define the path for the script
$scriptPath = "C:\UninstallDropbox.ps1"

# Create the script content
$scriptContent = @"
Get-AppxPackage *Dropbox* | Remove-AppxPackage
"@

# Write the script content to the file
Set-Content -Path $scriptPath -Value $scriptContent

# Execute the script with Bypass execution policy
powershell -ExecutionPolicy Bypass -File $scriptPath

# Optionally, remove the script after execution
Remove-Item -Path $scriptPath -Force