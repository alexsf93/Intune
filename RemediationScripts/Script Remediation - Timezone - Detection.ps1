<#
=====================================================================================================
    DETECTION SCRIPT: ZONA HORARIA MADRID Y SINCRONIZACIÓN DE HORA (INTUNE)
-----------------------------------------------------------------------------------------------------
Este script verifica si el dispositivo tiene configurada la zona horaria de Madrid 
("Romance Standard Time"), si el servicio de hora de Windows está activo y si la hora 
se ha sincronizado correctamente en las últimas 24 horas.

Compatible con Intune Remediations.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- PowerShell 5.1 o 7.x.
- Permisos para consultar servicios y configuración de zona horaria.
- Herramienta `w32tm` disponible (Windows).

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Lee la zona horaria actual del equipo y la compara con "Romance Standard Time".
- Comprueba que el servicio `W32Time` esté en estado `Running`.
- Consulta `w32tm /query /status` y evalúa la fecha/hora de la última sincronización.
- Devuelve:
  * Exit code 0 → Todo conforme (zona horaria correcta, servicio activo y sincronización reciente).
  * Exit code 1 → Alguna de las comprobaciones no se cumple.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → Configuración y sincronización horaria correctas.
- "NOK" (exit code 1) → Falta de conformidad en zona horaria, servicio o sincronización.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Usar como Detection Rule en Intune u otros sistemas que interpreten exit codes.
- Ejecutar con permisos suficientes para consultar servicios y configuración de tiempo.
- Aplicar una remediación complementaria si devuelve "NOK".

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

# Detection Script: Verifica zona horaria y servicio de hora

$timezone = (Get-TimeZone).Id
$timeService = Get-Service -Name W32Time
$expectedTimeZone = "Romance Standard Time"
$serviceOK = $timeService.Status -eq "Running"
$tzOK = $timezone -eq $expectedTimeZone

# Comprobar si la última sincronización fue en las últimas 24 horas
$lastSyncLine = w32tm /query /status | Select-String "Last Successful Sync Time"
$syncRecent = $false

if ($lastSyncLine) {
    $syncDateString = $lastSyncLine.ToString() -replace '.*:\s*', ''
    try {
        $syncDate = [datetime]::Parse($syncDateString)
        $syncRecent = ($syncDate -gt (Get-Date).AddHours(-24))
    } catch {
        $syncRecent = $false
    }
} else {
    # No se pudo encontrar la fecha de última sincronización
    $syncRecent = $false
}

if ($tzOK -and $serviceOK -and $syncRecent) {
    Write-Output "OK"
    exit 0
} else {
    Write-Output "NOK"
    exit 1
}
