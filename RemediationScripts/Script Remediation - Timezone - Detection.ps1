<#
.SYNOPSIS
    DETECTION SCRIPT: ZONA HORARIA MADRID Y SINCRONIZACIÓN DE HORA (INTUNE)

.DESCRIPTION
    Este script verifica si el dispositivo tiene configurada la zona horaria de Madrid 
    ("Romance Standard Time"), si el servicio de hora de Windows está activo y si la hora 
    se ha sincronizado correctamente en las últimas 24 horas.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Timezone - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
    Context: System
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
    }
    catch {
        $syncRecent = $false
    }
}
else {
    # No se pudo encontrar la fecha de última sincronización
    $syncRecent = $false
}

if ($tzOK -and $serviceOK -and $syncRecent) {
    Write-Output "OK"
    exit 0
}
else {
    Write-Output "NOK"
    exit 1
}
