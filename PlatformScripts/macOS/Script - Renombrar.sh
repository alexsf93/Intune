#!/bin/bash
# ===============================================================
#      Script: Renombrar equipo en macOS según número de serie
# ---------------------------------------------------------------
#      Autor: Alejandro Suárez (@alexsf93)
# ===============================================================
#
# DESCRIPCIÓN:
#     Obtiene el número de serie del Mac y configura el nombre
#     del equipo con el prefijo "INKOOVA" seguido del número de serie.
#     Actualiza ComputerName, LocalHostName y HostName en macOS.
#
# INSTRUCCIONES DE USO:
#     1. Asigna este script como Shell Script en Intune o MDM.
#     2. El script debe ejecutarse con privilegios de administrador.
#
# NOTAS:
#     - El nombre final seguirá el formato: INKOOVA[NUMERO_SERIE].
#     - Compatible con macOS Ventura y Sonoma (adaptable a versiones similares).
#     - Si ya coincide el nombre, no se realizan cambios.
#
# ===============================================================

# Obtener el número de serie
SERIAL=$(system_profiler SPHardwareDataType | awk '/Serial Number/{print $4}')
EXPECTED_NAME="INKOOVA$SERIAL"

# Obtener el nombre actual del equipo
CURRENT_NAME=$(scutil --get ComputerName)

# Comprobar si ya coincide
if [ "$CURRENT_NAME" != "$EXPECTED_NAME" ]; then
    scutil --set ComputerName "$EXPECTED_NAME"
    scutil --set LocalHostName "$EXPECTED_NAME"
    scutil --set HostName "$EXPECTED_NAME"
fi
