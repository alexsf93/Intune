<#
=====================================================================================================
    DETECTION SCRIPT: EXISTENCIA DE LA TAREA PROGRAMADA DEFENDER + SCRIPT ASOCIADO
-----------------------------------------------------------------------------------------------------
Este script verifica que la tarea programada de Microsoft Defender para escaneo simple exista,
que esté configurada para ejecutarse como SYSTEM y que el script asociado esté presente en la ruta
indicada:
- Tarea: ScheduledTask-Inkoova-MSDefender-Simple
- Script: C:\ProgramData\Inkoova\MSDefenderSimple.ps1

Pensado para uso en Intune (ejecución como SYSTEM) y activar remediación si falta algún requisito.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- PowerShell 5.1 o 7.x.
- Permisos para consultar tareas programadas y el sistema de archivos.
- Contexto de ejecución SYSTEM recomendado (Intune Remediations).

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Comprueba la existencia de la tarea programada especificada.
- Verifica que el principal de la tarea sea SYSTEM.
- Comprueba la existencia del script en `C:\ProgramData\Inkoova\`.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → La tarea existe, corre como SYSTEM y el script está presente.
- "NOK" (exit code 1) → Falta la tarea, el principal no es SYSTEM o el script no existe.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Usar como Detection Rule en Intune u otros sistemas que interpreten exit codes.
- Interpretar el código de salida para decidir si aplicar la remediación correspondiente.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Parámetros mínimos ---
$TaskName     = 'ScheduledTask-Inkoova-MSDefender-Simple'
$ScriptTarget = 'C:\ProgramData\Inkoova\MSDefenderSimple.ps1'

# 1) La tarea existe
try {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
} catch {
    Write-Host "NOK: No existe la tarea '$TaskName'."
    exit 1
}

# 2) Corre como SYSTEM
$uid = [string]$task.Principal.UserId
if (@('SYSTEM','NT AUTHORITY\SYSTEM') -notcontains $uid) {
    Write-Host "NOK: Principal no conforme: se esperaba SYSTEM y es '$uid'."
    exit 1
}

# 3) Existe el script en ProgramData
if (-not (Test-Path -LiteralPath $ScriptTarget)) {
    Write-Host "NOK: El script objetivo no existe: $ScriptTarget"
    exit 1
}

# Conforme
Write-Host "OK: '$TaskName' existe, corre como SYSTEM y el script está presente."
exit 0
