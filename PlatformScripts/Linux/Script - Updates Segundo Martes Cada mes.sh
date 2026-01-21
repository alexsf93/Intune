#!/bin/bash

# ==============================================================================
# Nombre:       Script - Updates Segundo Martes Cada mes.sh
# Descripción:  Ejecuta la actualización del sistema (apt update/upgrade/autoremove) solo
#               si es el segundo martes del mes, registrando todo en /var/log/intune.log.
#               Pensado para su uso en despliegues automatizados con Microsoft Intune.
# Autor:        Alejandro Suárez (@alexsf93)
# Versión:      1.0.0
# Uso:          ./Script - Updates Segundo Martes Cada mes.sh
# Notas:        Log: /var/log/intune.log. Compatible con Ubuntu Desktop.
# ==============================================================================

# Script profesional para la actualización mensual alineada al segundo martes, con registro detallado en /var/log/intune.log

LOGFILE="/var/log/intune.log"

log() {
    # Escribe un mensaje con timestamp en el log
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOGFILE"
}

# Comienza el registro
log "-------------------------------------------"
log "Ejecución del script de actualización iniciada."

DIA=$(date +%d)
DIA_SEMANA=$(date +%u)

if [ "$DIA_SEMANA" -eq 2 ]; then
    if [ "$DIA" -ge 8 ] && [ "$DIA" -le 14 ]; then
        log "Segundo martes del mes detectado. Iniciando actualización del sistema."
        # Actualiza la lista de paquetes
        if apt update >> "$LOGFILE" 2>&1; then
            log "apt update completado correctamente."
        else
            log "ERROR durante apt update."
        fi

        # Actualiza los paquetes instalados
        if apt upgrade -y >> "$LOGFILE" 2>&1; then
            log "apt upgrade completado correctamente."
        else
            log "ERROR durante apt upgrade."
        fi

        # Elimina paquetes innecesarios
        if apt autoremove -y >> "$LOGFILE" 2>&1; then
            log "apt autoremove completado correctamente."
        else
            log "ERROR durante apt autoremove."
        fi

        log "Actualización finalizada."
    else
        log "Hoy es martes, pero no corresponde al segundo martes del mes. No se ejecuta actualización."
    fi
else
    log "Hoy no es martes. No se ejecuta actualización."
fi

log "Ejecución del script finalizada."
log "-------------------------------------------"
