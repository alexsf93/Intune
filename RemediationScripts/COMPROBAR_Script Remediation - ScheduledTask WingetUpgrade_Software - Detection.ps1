<#
.SYNOPSIS
    DETECTION SCRIPT: EXISTENCIA DE TAREA PROGRAMADA + SYSTEM + SCRIPT PRESENTE

.DESCRIPTION
    Este script verifica la presencia y configuración mínima de la tarea programada
    "ScheduledTask-Inkoova-WingetUpgradeSoftware", comprobando que exista, que se
    ejecute bajo la cuenta SYSTEM y que el script objetivo esté presente en la ruta indicada.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: COMPROBAR_Script Remediation - ScheduledTask WingetUpgrade_Software - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Parámetros mínimos ---
$TaskName = 'ScheduledTask-Inkoova-WingetUpgradeSoftware'
$ScriptTarget = 'C:\ProgramData\Inkoova\WingetUpgradeSoftware.ps1'

# 1) La tarea existe
try {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
}
catch {
    Write-Host "No existe la tarea '$TaskName'."
    exit 1
}

# 2) Corre como SYSTEM
$uid = [string]$task.Principal.UserId
if (@('SYSTEM', 'NT AUTHORITY\SYSTEM') -notcontains $uid) {
    Write-Host "Principal no conforme: se esperaba SYSTEM y es '$uid'."
    exit 1
}

# 3) Existe el script en ProgramData
if (-not (Test-Path -LiteralPath $ScriptTarget)) {
    Write-Host "El script objetivo no existe: $ScriptTarget"
    exit 1
}

# Conforme
Write-Host "OK: '$TaskName' existe, corre como SYSTEM y el script está presente."
exit 0
