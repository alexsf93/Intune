#!/bin/bash

# ==============================================================================
# Nombre:       Script - Renombrar.sh
# Descripción:  Obtiene el número de serie del Mac y configura el nombre
#               del equipo con el prefijo "INKOOVA" seguido del número de serie.
#               Actualiza ComputerName, LocalHostName y HostName en macOS.
# Autor:        Alejandro Suárez (@alexsf93)
# Versión:      1.0.0
# Uso:          ./Script - Renombrar.sh
# Notas:        El nombre final será INKOOVA[NUMERO_SERIE]. Requiere privilegios de admin.
# ==============================================================================

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
