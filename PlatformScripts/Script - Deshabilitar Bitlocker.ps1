<#
===============================================================
      Script: Desactivar BitLocker en equipos Windows
---------------------------------------------------------------
Autor: Alejandro Suárez (@alexsf93)
===============================================================

.DESCRIPCIÓN
    Desactiva BitLocker en todas las unidades cifradas del equipo.
    Antes de ejecutar, **asegúrate de que el dispositivo está en un grupo de exclusión de BitLocker en Intune**
    para evitar que se apliquen políticas de cifrado automáticamente.

.INSTRUCCIONES DE USO
    1. Añade el equipo al grupo de exclusión en Intune y espera la aplicación de la política.
    2. Ejecuta este script como Administrador en el dispositivo objetivo.

.NOTAS
    - Solo desactivará BitLocker en volúmenes donde esté habilitado.
    - Se mostrará el progreso de cada unidad.
    - Puedes ejecutar este script de manera local o como Platform Script en Intune.
===============================================================
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