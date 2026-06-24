<#
.SYNOPSIS
    DETECTION SCRIPT: Detección para verificar la nomenclatura estándar del equipo.

.DESCRIPTION
    Valida si el nombre actual coincide con 'NOMBRE' + los últimos 8 caracteres del número de serie.
    Si el equipo es VM o no tiene serial válido, usa los últimos 8 caracteres del UUID como fallback.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Rename Nombre+Serialnumber - Detection.ps1
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
        Write-Output "EQUIPO CONFORME: $CurrentName"
        exit 0
    } else {
        Write-Output "EQUIPO NO CONFORME - Actual: $CurrentName | Esperado: $ExpectedName"
        exit 1
    }
}
catch {
    Write-Error "Error de detección: $_"
    exit 1
}
