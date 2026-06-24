<#
.SYNOPSIS
    REMEDIATION SCRIPT: RESTAURACIÓN DE PLANES DE ENERGÍA HABITUALES EN WINDOWS

.DESCRIPTION
    Este script restaura los planes de energía estándar de Windows si alguno no está presente:
    - Equilibrado (Balanced)
    - Alto rendimiento (High Performance)
    - Economizador (Power Saver)

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: CORREGIR_Script Remediation - Planes de energia - Remediation.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
    Context: System
#>

# Detener en errores no controlados dentro de los try/catch
$ErrorActionPreference = 'Stop'

# Detectar si el sistema utiliza Modern Standby (S0 Low Power Idle)
$states = powercfg /a
$notAvailableIndex = 0
for ($i = 0; $i -lt $states.Count; $i++) {
    if ($states[$i] -match "not available|no disponibles|no están disponibles") {
        $notAvailableIndex = $i
        break
    }
}
$availableStates = if ($notAvailableIndex -gt 0) { $states[0..($notAvailableIndex - 1)] } else { $states }
$isModernStandby = $false
foreach ($line in $availableStates) {
    if ($line -match "S0") {
        $isModernStandby = $true
        break
    }
}

# Lista de planes: GUID y nombre según el tipo de standby
if ($isModernStandby) {
    $powerPlans = @(
        @{ Name = "Balanced"; GUID = "381b4222-f694-41f0-9685-ff5bb260df2e" }
    )
} else {
    $powerPlans = @(
        @{ Name = "Balanced"; GUID = "381b4222-f694-41f0-9685-ff5bb260df2e" }
        @{ Name = "High Performance"; GUID = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" }
        @{ Name = "Power Saver"; GUID = "a1841308-3541-4fab-bc81-f71556f20b4a" }
    )
}

# Regex para extraer GUIDs (independiente del idioma de la salida)
$guidRegex = '[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}'

# Obtener GUIDs de planes existentes
$existingGUIDs = powercfg /list |
Select-String -Pattern $guidRegex -AllMatches |
ForEach-Object { $_.Matches.Value.ToLowerInvariant() } |
Select-Object -Unique

foreach ($plan in $powerPlans) {
    $planGuidLower = $plan.GUID.ToLowerInvariant()
    if ($existingGUIDs -notcontains $planGuidLower) {
        try {
            powercfg -duplicatescheme $plan.GUID $plan.GUID | Out-Null
            Write-Output "Plan restaurado: $($plan.Name)"
        }
        catch {
            Write-Output "Error restaurando $($plan.Name): $($_.Exception.Message)"
        }
    }
    else {
        Write-Output "Plan ya presente: $($plan.Name)"
    }
}

exit 0
