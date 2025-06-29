<#
===============================================================================================
                         REMEDIACIÓN: DESINSTALAR LENOVO NOW - POWERSHELL
-----------------------------------------------------------------------------------------------
Este script desinstala la aplicación **Lenovo Now** de sistemas Windows de forma silenciosa,  
pensado para automatizaciones, remediación desde Intune o limpieza manual de bloatware.

-----------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------
- Busca el desinstalador en la ruta predeterminada:
      C:\Program Files (x86)\Lenovo\LenovoNow\unins000.exe
- Si existe, lo ejecuta en modo silencioso (/SILENT).
- Espera a que el proceso termine antes de finalizar.

-----------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------
- Ejecuta el script con:
      powershell.exe -ExecutionPolicy Bypass -File .\Script Remediation - Desinstalar Lenovo Now - Remediation.ps1
- Compatible con scripts de **Remediation** en Intune y escenarios de limpieza manual.

-----------------------------------------------------------------------------------------------
NOTAS
-----------------------------------------------------------------------------------------------
- No muestra ventanas ni requiere interacción del usuario.
- Se recomienda ejecutarlo con privilegios de administrador para asegurar la desinstalación.
- No elimina directorios residuales ni otros componentes fuera del desinstalador estándar.

-----------------------------------------------------------------------------------------------
AUTOR
-----------------------------------------------------------------------------------------------
- Alejandro Suárez (@alexsf93)
===============================================================================================
#>

$path = 'C:\Program Files (x86)\Lenovo\LenovoNow\unins000.exe'
$params = "/SILENT"
if (Test-Path -Path $path) {
    Start-Process -FilePath $path -ArgumentList $params -Wait
}