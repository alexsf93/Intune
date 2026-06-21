<#
.SYNOPSIS
    Remediación para aplicar la nomenclatura estándar al equipo.

.DESCRIPTION
    Aplica el renombrado del equipo al patrón 'NOMBRE' + los últimos 8 caracteres del número de serie.
    Si el equipo es VM o no tiene serial válido, usa los últimos 8 caracteres del UUID como fallback.
    Muestra un aviso al usuario y programa un reinicio forzado en 10 minutos.

.PARAMETER
    Ninguno.

.EXAMPLE
    & ".\Script Remediation - Rename NOMBRE+Serialnumber - Remediation.ps1"

.NOTES
    Name: Script Remediation - Rename NOMBRE+Serialnumber - Remediation.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-05-27
    Context: System
#>

$ErrorActionPreference = "Stop"

try {
    # Obtener número de serie del hardware
    $Bios = Get-CimInstance -ClassName Win32_Bios
    $SerialNumber = $Bios.SerialNumber

    # Descartar seriales genéricos o de máquinas virtuales
    $GenericSerials = @(
        "System Serial Number", "To be filled by O.E.M.", "Default string",
        "Not Specified", "None", "System Product Name", "00000000", "123456789"
    )

    $IsGeneric = $false
    if ([string]::IsNullOrWhiteSpace($SerialNumber) -or $SerialNumber -match '^[0]+$') {
        $IsGeneric = $true
    } else {
        foreach ($Pattern in $GenericSerials) {
            if ($SerialNumber.Trim() -ilike "*$Pattern*") {
                $IsGeneric = $true
                break
            }
        }
    }

    # Fallback al UUID de la placa si no hay serial válido
    if ($IsGeneric) {
        Write-Warning "Serial genérico detectado ($SerialNumber). Usando UUID como respaldo."
        $UUID = (Get-CimInstance -ClassName Win32_ComputerSystemProduct).UUID
        if ([string]::IsNullOrWhiteSpace($UUID) -or $UUID -eq "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF") {
            throw "No se ha podido recuperar un ID único del hardware."
        }
        $RawId = $UUID
    } else {
        $RawId = $SerialNumber
    }

    # Limpieza de caracteres no permitidos en nombres de equipo
    $Sanitized = $RawId -replace '[^a-zA-Z0-9]', ''

    # Ajuste de longitud (máx. 15 caracteres: NOMBRE [7] + Serial/UUID [8])
    $MaxChars = 8
    if ($Sanitized.Length -gt $MaxChars) {
        $ShortId = $Sanitized.Substring($Sanitized.Length - $MaxChars)
    } else {
        $ShortId = $Sanitized
    }

    $ExpectedName = "NOMBRE$ShortId".ToUpper()
    $CurrentName = $env:COMPUTERNAME.ToUpper()

    if ($CurrentName -eq $ExpectedName) {
        Write-Output "Nomenclatura ya aplicada: $CurrentName"
        exit 0
    }

    # Aplicar renombrado
    Write-Output "Cambiando nombre de equipo: $CurrentName -> $ExpectedName"
    Rename-Computer -NewName $ExpectedName -Force -ErrorAction Stop

    # Mostrar mensaje en pantalla y programar reinicio en 10 minutos (600 segundos)
    $Msg = "Se ha detectado que el nombre de este equipo no cumple con las politicas de la empresa. Se ha renombrado de forma automatica a '$ExpectedName' y el sistema se reiniciara en 10 minutos. Por favor, guarde su trabajo."
    Write-Output "Programando reinicio en 10 minutos con aviso en pantalla..."
    & shutdown.exe /r /t 600 /f /c $Msg

    Write-Output "Renombrado aplicado con éxito y reinicio programado."
    exit 0
}
catch {
    Write-Error "Error de remediación: $_"
    exit 1
}
