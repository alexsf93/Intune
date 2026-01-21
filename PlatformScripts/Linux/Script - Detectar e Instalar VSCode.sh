#!/bin/bash

# ==============================================================================
# Nombre:       Script - Detectar e Instalar VSCode.sh
# Descripción:  Comprueba si Visual Studio Code está instalado (por binario, DEB o Snap).
#               Si no está presente, lo instala desde el repositorio oficial de Microsoft.
# Autor:        Alejandro Suárez (@alexsf93)
# Versión:      1.0.0
# Uso:          ./Script - Detectar e Instalar VSCode.sh
# Notas:        Compatible con Ubuntu Desktop 20.04+. Detecta instalaciones tipo Snap/Flatpak para evitar duplicados.
# ==============================================================================
set -e

# Buscar VS Code binario
is_vscode_bin_installed() {
    command -v code >/dev/null 2>&1
}

# Buscar paquete DEB oficial
is_vscode_deb_installed() {
    dpkg -l | grep -w 'code' | grep -q 'Microsoft'
}

# Buscar como Snap
is_vscode_snap_installed() {
    snap list 2>/dev/null | grep -q '^code\s'
}

if is_vscode_bin_installed || is_vscode_deb_installed || is_vscode_snap_installed; then
    echo "Visual Studio Code parece estar instalado por algún método."
else
    echo "Instalando Visual Studio Code (paquete oficial)..."
    apt-get update
    apt-get install -y wget gpg

    # Importar clave GPG
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
    install -o root -g root -m 644 /tmp/microsoft.gpg /usr/share/keyrings/microsoft.gpg

    # Agregar repositorio oficial si no existe
    if ! grep -q 'packages.microsoft.com/repos/code' /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
    fi

    apt-get update
    apt-get install -y code

    # Confirmar instalación
    if command -v code >/dev/null 2>&1; then
        echo "¡Visual Studio Code se instaló correctamente!"
    else
        echo "Error: No se pudo instalar Visual Studio Code."
        exit 1
    fi
fi
