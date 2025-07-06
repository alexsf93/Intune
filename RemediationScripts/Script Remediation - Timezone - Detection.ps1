<#
=====================================================================================================
    REMEDIACIÓN: ZONA HORARIA MADRID Y SINCRONIZACIÓN DE HORA (INTUNE)
-----------------------------------------------------------------------------------------------------
Este script detecta si el dispositivo tiene configurada la zona horaria de Madrid ("Romance Standard Time"),
si el servicio de hora de Windows está activo y si la hora ha sido sincronizada recientemente (últimas 24h).

Compatible con Intune Remediations.
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
