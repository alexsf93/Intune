# README:
# Antes de ejecutar este script, **asegúrate de que los equipos estén añadidos previamente a un grupo de exclusión en Intune**,
# la consola de administración utilizada para la gestión de políticas de BitLocker.
# Así evitarás que se apliquen las políticas de cifrado de BitLocker a estos dispositivos mientras realizas los cambios.
# Si no haces este paso, existe el riesgo de que BitLocker vuelva a activarse o se apliquen políticas de cifrado automáticamente.

# Instrucciones:
# 1. Añade los equipos a un grupo de exclusión de BitLocker en Intune.
# 2. Verifica que la exclusión se haya aplicado correctamente a todos los dispositivos.
# 3. Ejecuta el siguiente script para desactivar BitLocker:
$BLV = Get-BitLockerVolume
Disable-BitLocker -MountPoint $BLV
