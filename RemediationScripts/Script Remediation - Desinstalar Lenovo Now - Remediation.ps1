<#
=====================================================================================================
    REMEDIATION SCRIPT: DESINSTALAR LENOVO NOW
-----------------------------------------------------------------------------------------------------
Este script desinstala la aplicación **Lenovo Now** de sistemas Windows de forma silenciosa. 
Está pensado para automatizaciones, remediaciones con Intune o limpieza manual de bloatware 
en dispositivos gestionados.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- Compatible con PowerShell 5.1 y 7.x.
- Recomendado ejecutarlo con privilegios de administrador o SYSTEM.
- Acceso al desinstalador en la ruta predeterminada:
      C:\Program Files (x86)\Lenovo\LenovoNow\unins000.exe

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Comprueba si existe el desinstalador en la ruta predeterminada.
- Si está presente, lo ejecuta en modo silencioso (`/SILENT`).
- Espera a que el proceso de desinstalación finalice antes de salir.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0 implícito) → Lenovo Now desinstalado correctamente o no presente.
- Mensajes en salida estándar → Solo si ocurre un error durante la ejecución.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecutar con:
      powershell.exe -ExecutionPolicy Bypass -File .\Remediation-LenovoNow.ps1
- Integrar como Remediation Script en Intune o usarlo manualmente en escenarios de limpieza.
- El script funciona de manera silenciosa y no requiere interacción del usuario.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

$path = 'C:\Program Files (x86)\Lenovo\LenovoNow\unins000.exe'
$params = "/SILENT"

if (Test-Path -Path $path) {
    Start-Process -FilePath $path -ArgumentList $params -Wait
}
