<#
.SYNOPSIS
    DETECTION SCRIPT: VALIDAR VALOR AUOPTIONS (WINDOWS AUTOPATCH)

.DESCRIPTION
    Este script detecta si el valor de registro HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\AUOptions
    está configurado con un valor (1, 2, 3 o 7) que entra en conflicto con la gestión de Windows Autopatch.
    Si está configurado con un valor distinto de 4 o 5, el script finaliza con código 1 (no conforme).
    Si no existe o está configurado con 4 o 5, finaliza con código 0 (conforme).

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Windows Autopatch AUOptions Fix - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-06-25
    Context: System
#>

# Forzar el uso de codificación UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 1. Asegurar entorno de ejecución de 64 bits para evitar redirecciones de registro (WOW6432Node)
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    Write-Host "Ejecutando en proceso de 32 bits en SO de 64 bits. Relanzando en PowerShell de 64 bits..."
    $powershell64 = Join-Path $env:SystemRoot "Sysnative\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $powershell64) {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Start-Process -FilePath $powershell64 -ArgumentList $arguments -Wait -NoNewWindow
        exit $LASTEXITCODE
    } else {
        Write-Warning "No se pudo encontrar el ejecutable de PowerShell de 64 bits en Sysnative. Continuando en modo actual..."
    }
}

$RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
$ValueName = "AUOptions"

# Comprobar si existe la ruta y el valor
if (Test-Path -Path $RegistryPath) {
    try {
        $key = Get-Item -Path $RegistryPath -ErrorAction Stop
        if ($key.GetValueNames() -contains $ValueName) {
            $val = $key.GetValue($ValueName)
            Write-Output "Detección: Se encontró el valor de registro '$ValueName' con valor '$val' en la ruta '$RegistryPath'."
            
            # Si el valor no es 4 ni 5, hay conflicto (No conforme)
            if ($val -ne 4 -and $val -ne 5) {
                Write-Output "Resultado: No conforme (El valor '$val' genera conflicto con Windows Autopatch. Valores válidos: 4 o 5)."
                exit 1
            } else {
                Write-Output "Resultado: Conforme (El valor '$val' es compatible con Windows Autopatch)."
                exit 0
            }
        } else {
            Write-Output "Resultado: Conforme (El valor '$ValueName' no existe en la ruta '$RegistryPath')."
            exit 0
        }
    }
    catch {
        Write-Warning "Error al leer el registro: $($_.Exception.Message). Se asume conforme por precaución."
        exit 0
    }
} else {
    Write-Output "Resultado: Conforme (La clave de registro '$RegistryPath' no existe)."
    exit 0
}
