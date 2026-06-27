<#
.SYNOPSIS
    REMEDIATION SCRIPT: CORREGIR CONFLICTO DE AUOPTIONS CON WINDOWS AUTOPATCH

.DESCRIPTION
    Este script elimina el valor de registro HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\AUOptions
    si el script de detección determina que entra en conflicto con las directivas de Windows Autopatch.
    Esto permite que las directivas de Windows Autopatch aplicadas por Intune tomen el control.
    Tras realizar la eliminación, verifica que el valor ya no exista en el registro.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Windows Autopatch AUOptions Fix - Remediation.ps1
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

try {
    Write-Output "Iniciando remediación para el conflicto de Windows Autopatch con AUOptions..."
    
    if (Test-Path -Path $RegistryPath) {
        $key = Get-Item -Path $RegistryPath -ErrorAction Stop
        if ($key.GetValueNames() -contains $ValueName) {
            Write-Output "Eliminando la propiedad del registro '$ValueName' en '$RegistryPath'..."
            Remove-ItemProperty -Path $RegistryPath -Name $ValueName -ErrorAction Stop
            Write-Output "Propiedad '$ValueName' eliminada correctamente."
        } else {
            Write-Output "El valor '$ValueName' no existe en '$RegistryPath'. Nada que eliminar."
        }
    } else {
        Write-Output "La clave de registro '$RegistryPath' no existe. Nada que eliminar."
    }

    # 2. Verificación posterior a la eliminación
    Write-Output "Verificando el estado del registro tras la remediación..."
    $verificationSuccess = $true

    if (Test-Path -Path $RegistryPath) {
        $keyAfter = Get-Item -Path $RegistryPath -ErrorAction Stop
        if ($keyAfter.GetValueNames() -contains $ValueName) {
            $currentVal = $keyAfter.GetValue($ValueName)
            Write-Output "Error de verificación: El valor de registro '$ValueName' todavía existe con valor '$currentVal'."
            $verificationSuccess = $false
        }
    }

    if ($verificationSuccess) {
        Write-Output "Remediación exitosa: El valor '$ValueName' no existe en el registro."
        exit 0
    } else {
        Write-Output "Error: No se pudo eliminar el valor de registro '$ValueName'."
        exit 1
    }
}
catch {
    Write-Output "ERROR durante la remediación: $($_.Exception.Message)"
    exit 1
}
