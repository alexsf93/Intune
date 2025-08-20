#!/bin/bash
# ===============================================================
#      Script: Verificar y habilitar Firewall en macOS
# ---------------------------------------------------------------
#      Autor: Alejandro Suárez (@alexsf93)
# ===============================================================
#
# DESCRIPCIÓN:
#     Verifica si el firewall de macOS está habilitado.
#     Si no lo está, lo activa automáticamente.
#     Compatible con despliegues automatizados (ej. Intune).
#
# INSTRUCCIONES DE USO:
#     1. Asigna este script como Shell Script en Intune o MDM.
#     2. El script debe ejecutarse con privilegios de administrador.
#
# NOTAS:
#     - No modifica reglas personalizadas del firewall,
#       únicamente gestiona el estado global (ON/OFF).
#     - Probado en macOS Ventura y Sonoma (adaptable a versiones similares).
#
# ===============================================================

# Comprobar el estado del firewall
FIREWALL_STATUS=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate | grep -c "enabled")

# Activar solo si no está habilitado
if [ "$FIREWALL_STATUS" -eq 0 ]; then
    /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
fi
