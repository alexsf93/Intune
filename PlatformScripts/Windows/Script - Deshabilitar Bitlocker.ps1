<#
.SYNOPSIS
    Desactivar BitLocker en equipos Windows.

.DESCRIPTION
    Desactiva BitLocker en todas las unidades cifradas del equipo.
    Antes de ejecutar, asegúrate de que el dispositivo está en un grupo de exclusión de BitLocker en Intune
    para evitar que se apliquen políticas de cifrado automáticamente.

.PARAMETER
    Ninguno.

.EXAMPLE
    .\Script - Deshabilitar BitLocker.ps1

.NOTES
    Name: Script - Deshabilitar BitLocker.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
#>

# Obtener todas las unidades con BitLocker habilitado
$volumes = Get-BitLockerVolume | Where-Object {$_.VolumeStatus -eq "FullyEncrypted" -or $_.VolumeStatus -eq "EncryptionInProgress"}

if (-not $volumes) {
    Write-Host "No hay volúmenes con BitLocker activos en este equipo." -ForegroundColor Yellow
    return
}

foreach ($vol in $volumes) {
    Write-Host "Desactivando BitLocker en la unidad $($vol.MountPoint)..." -ForegroundColor Cyan
    try {
        Disable-BitLocker -MountPoint $vol.MountPoint
        Write-Host "BitLocker se está desactivando en $($vol.MountPoint). Este proceso puede tardar varios minutos." -ForegroundColor Green
    } catch {
        Write-Warning "Error al intentar desactivar BitLocker en $($vol.MountPoint): $_"
    }
}

Write-Host "Proceso completado. Comprueba el estado de BitLocker tras finalizar el descifrado." -ForegroundColor Green