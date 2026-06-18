#!/bin/zsh

# ==============================================================================
# Nombre:        Script - MantenimientoLimpieza.sh
# Descripción:   Fuerza los scripts periódicos, limpia caches globales, logs de
#                usuarios, purga snapshots de APFS y optimiza la RAM en macOS.
# Autor:         Alejandro Suárez (@alexsf93)
# Versión:       1.2.0
# Uso:           ./Script - MantenimientoLimpieza.sh
# Notas:         Optimiza el espacio y rendimiento de forma silenciosa.
# ==============================================================================

# Definicion del archivo de log local
LOG_FILE="/Library/Logs/Inkoova_Mantenimiento.log"

# Funcion para formatear y registrar los eventos
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_message "Iniciando tareas de mantenimiento del sistema"

# 1. Ejecucion de scripts periodicos nativos de macOS
log_message "[1/6] Ejecutando scripts periodicos del sistema..."
if periodic daily weekly monthly; then
    log_message "Mantenimiento periodico completado."
else
    log_message "ERROR: Fallo al ejecutar los mantenimientos periodicos."
fi

# 2. Limpieza de cache global del sistema
log_message "[2/6] Limpiando caches globales del sistema..."
CACHE_DIR="/Library/Caches"
if [ -d "$CACHE_DIR" ]; then
    rm -rf /Library/Caches/*
    log_message "Caches del sistema (/Library/Caches) eliminadas."
else
    log_message "AVISO: No se encontro el directorio de cache global."
fi

# 3. Limpieza de logs acumulados en los perfiles de usuario
log_message "[3/6] Limpiando archivos de log en perfiles de usuario..."
for user_dir in /Users/*; do
    if [ -d "${user_dir}/Library/Logs" ]; then
        rm -rf "${user_dir}/Library/Logs"/* 2>/dev/null
    fi
done
log_message "Logs de usuario purgados."

# 4. Eliminacion de archivos temporales del sistema
log_message "[4/6] Eliminando archivos temporales del sistema..."
rm -rf /private/var/folders/*/*/*/com.apple.developertools* 2>/dev/null
rm -rf /private/var/spool/cups/tmp/* 2>/dev/null
log_message "Archivos temporales eliminados."

# 5. Purga de Instantáneas Locales de APFS (Local Snapshots)
log_message "[5/6] Purgando snapshots locales de APFS antiguos..."
if command -v tmutil &> /dev/null; then
    # Solicita adelgazar los snapshots locales para liberar espacio inmediato
    tmutil thinlocalsnapshots / 10000000000 1 &> /dev/null
    log_message "Snapshots locales de APFS optimizados."
else
    log_message "AVISO: tmutil no disponible."
fi

# 6. Liberacion de memoria inactiva
log_message "[6/6] Optimizando la memoria RAM asignada..."
purge
log_message "Memoria inactiva liberada correctamente."

log_message "Tareas de mantenimiento finalizadas"
exit 0