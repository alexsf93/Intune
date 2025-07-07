#!/bin/bash
# ===============================================================
#      Script: Verificar, instalar y habilitar SSH en Ubuntu Desktop
# ---------------------------------------------------------------
#      Autor: Alejandro Suárez (@alexsf93)
# ===============================================================
#
# DESCRIPCIÓN:
#     Verifica si el servicio SSH está instalado, lo instala si es necesario,
#     y asegura que esté activo y habilitado en Ubuntu Desktop 24.04.
#     Pensado para ejecución automática mediante Microsoft Intune.
#
# INSTRUCCIONES DE USO:
#     1. Asigna este script como Shell Script en Intune a los dispositivos objetivo.
#     2. El script debe ejecutarse como root (Intune ejecuta los scripts con privilegios).
#
# NOTAS:
#     - Guarda el log en /var/log/ssh_deployment.log
#     - Compatible con Ubuntu Desktop 24.04 (adaptable a versiones similares).
#     - No afecta la configuración personalizada de SSH (solo instala y habilita el servicio).
#
# ===============================================================

# Definir archivo de log
LOG_FILE="/var/log/ssh_deployment.log"

# Función para escribir en el log
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_message "Iniciando script de verificación e instalación de SSH"

# Verificar si SSH está instalado
if dpkg -l | grep -q "^ii.*openssh-server"; then
    log_message "El servidor SSH ya está instalado"
else
    log_message "SSH no está instalado. Procediendo con la instalación..."
    
    # Actualizar lista de paquetes
    apt-get update
    if [ $? -ne 0 ]; then
        log_message "ERROR: No se pudo actualizar la lista de paquetes"
        exit 1
    fi
    
    # Instalar SSH
    apt-get install ssh -y
    if [ $? -ne 0 ]; then
        log_message "ERROR: No se pudo instalar el paquete SSH"
        exit 1
    fi
    
    log_message "SSH instalado correctamente"
fi

# Verificar si el servicio SSH está funcionando
if systemctl is-active --quiet ssh; then
    log_message "El servicio SSH está activo y funcionando"
else
    log_message "El servicio SSH no está activo. Iniciándolo..."
    
    # Iniciar el servicio SSH
    systemctl start ssh
    if [ $? -ne 0 ]; then
        log_message "ERROR: No se pudo iniciar el servicio SSH"
        exit 1
    fi
    
    log_message "Servicio SSH iniciado correctamente"
    
    # Habilitar el servicio SSH para que inicie en el arranque
    systemctl enable ssh
    if [ $? -ne 0 ]; then
        log_message "ERROR: No se pudo habilitar el servicio SSH para inicio automático"
        exit 1
    fi
    
    log_message "Servicio SSH habilitado para inicio automático"
fi

# Verificación final
if systemctl is-active --quiet ssh && systemctl is-enabled --quiet ssh; then
    log_message "Verificación final: SSH está instalado, activo y habilitado para inicio automático"
    exit 0
else
    log_message "ERROR: Verificación final falló. SSH no está funcionando correctamente"
    exit 1
fi
