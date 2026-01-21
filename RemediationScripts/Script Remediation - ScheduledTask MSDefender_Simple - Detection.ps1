<#
.SYNOPSIS
    DETECTION SCRIPT: EXISTENCIA DE LA TAREA PROGRAMADA DEFENDER + SCRIPT ASOCIADO

.DESCRIPTION
    Este script verifica que la tarea programada de Microsoft Defender para escaneo simple exista,
    que esté configurada para ejecutarse como SYSTEM y que el script asociado esté presente en la ruta
    indicada.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - ScheduledTask MSDefender_Simple - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Parámetros mínimos ---
$TaskName = 'ScheduledTask-Inkoova-MSDefender-Simple'
$ScriptTarget = 'C:\ProgramData\Inkoova\MSDefenderSimple.ps1'

# 1) La tarea existe
try {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
}
catch {
    Write-Host "NOK: No existe la tarea '$TaskName'."
    exit 1
}

# 2) Corre como SYSTEM
$uid = [string]$task.Principal.UserId
if (@('SYSTEM', 'NT AUTHORITY\SYSTEM') -notcontains $uid) {
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
