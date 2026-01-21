#!/bin/bash

# ==============================================================================
# Nombre:       Script - Firewall.sh
# Descripción:  Verifica si el firewall de macOS está habilitado.
#               Si no lo está, lo activa automáticamente.
# Autor:        Alejandro Suárez (@alexsf93)
# Versión:      1.0.0
# Uso:          ./Script - Firewall.sh
# Notas:        Requiere privilegios de administrador.
# ==============================================================================

# Comprobar el estado del firewall
FIREWALL_STATUS=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate | grep -c "enabled")

# Activar solo si no está habilitado
if [ "$FIREWALL_STATUS" -eq 0 ]; then
    /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
fi
